{% set using_purchasing_document_item = var('sap_using_ekpo', True) %}
{% set using_purchasing_document_header = var('sap_using_ekko', True) %}
{% set using_company = var('sap_using_t001', True) %}
{% set using_purchasing_document_overview = var('sap_using_ekbe', True) %}
{% set using_purchasing_document_schedule_total = var('sap_using_eket', True) %}

{{ config(enabled=using_purchasing_document_item) }}

with purchasing_document_item as (
    select *
    from {{ ref('int_sap__purchasing_document_item') }}
    where
        -- Excluded: identified as bad/test data during analytics review, not real purchase
        -- activity. Before this filter these lines accounted for 97.6% of total
        -- purchase_order_amount ($629.99B of $645.36B), making purchase_to_sales_value_ratio
        -- meaningless. Remove or narrow this filter once confirmed with the purchasing team.
        --
        -- 1) Unit price of exactly $20,121,212.00 on placeholder material '000000000000000897'
        --    (30 lines, all sharing this exact price) -- the digits match 2012-12-12, strongly
        --    suggesting a date was fat-fingered into the unit price field. Condition-based so it
        --    catches every instance of this fingerprint, not just the ones found so far.
        coalesce(net_order_price_val, 0) != 20121212

        -- 2) Specific documents with quantities 1,000-1,000,000x larger than any other order of
        --    the same material at the same unit price -- consistent with a quantity fat-finger
        --    or stray test entry rather than real purchase volume:
        --      - 4500017422/4500017423/4500017425 (materials GTS-N2-010/012/013/014, which are
        --        otherwise used normally in dozens of $1K-$50K orders)
        --      - 4500017321 (material HT1-S100546, 100,000,000 units -- appears nowhere else)
        --      - 4500019247 (material HT-1000, 1,000,000 units -- 12x the largest legitimate
        --        order of the same material, which tops out around 81,446 units)
        and purchasing_document_id not in (
            '4500017422', '4500017423', '4500017425',
            '4500017321', '4500019247'
        )



{% if using_purchasing_document_header %}
), purchasing_document_header as (
    select *

    from {{ ref('int_sap__purchasing_document_header') }}
{% endif %}

{% if using_company %}
), company as (
    select *
    from {{ ref('int_sap__company') }}
{% endif %}

{% if using_purchasing_document_overview %}
), purchasing_document_overview as (
    select *
    from {{ ref('int_sap__purchasing_document_overview') }}
{% endif %}

{% if using_purchasing_document_schedule_total %}
), purchasing_document_schedule_total as (
    select *
    from {{ ref('int_sap__purchasing_document_schedule_total') }}
{% endif %}

), final as (
    select
        purchasing_document_item.client_id,
        purchasing_document_item.purchasing_document_id,
        purchasing_document_item.purchasing_document_item_id,

        purchasing_document_item.material_id,
        purchasing_document_item.plant_id,
        purchasing_document_item.order_uom_id,
        purchasing_document_item.returns_item,
        purchasing_document_item.rejection_indicator,
        purchasing_document_item.net_order_po_currency_val as purchasing_document_currency_amount,
        case 
            when purchasing_document_item.returns_item = ''
                then purchasing_document_item.purchase_order_quantity
            else -1 * purchasing_document_item.purchase_order_quantity
        end as purchase_order_quantity,
        case
            when lower(purchasing_document_item.rejection_indicator) = 'x'
                then purchasing_document_item.purchase_order_quantity
            else cast(0 as {{ dbt.type_numeric() }})
        end as cancel_purchase_quantity

        {% if using_purchasing_document_header %}
        , purchasing_document_header.company_code_id
        , purchasing_document_header.purchasing_group_id
        , purchasing_document_header.purchasing_organization_id
        , purchasing_document_header.vendor_id
        , purchasing_document_header.purchasing_document_date
        , purchasing_document_header.exchange_rate
        , purchasing_document_header.currency_id as document_currency_id
        , cast(
            purchasing_document_item.net_order_po_currency_val *
            case
                when purchasing_document_header.exchange_rate < 0
                    then -1 / purchasing_document_header.exchange_rate
                else purchasing_document_header.exchange_rate
            end as {{ dbt.type_numeric() }}
        ) as purchase_order_amount
        , case
            when lower(purchasing_document_item.rejection_indicator) = 'x'
                then cast(purchasing_document_item.net_order_po_currency_val * case
                    when purchasing_document_header.exchange_rate < 0
                        then - 1 / purchasing_document_header.exchange_rate
                    else purchasing_document_header.exchange_rate
                    end as {{ dbt.type_numeric() }}
                    )
            else cast(0 as {{ dbt.type_numeric() }})
		end as cancel_purchase_amount
        {% endif %}

        {% if using_company %}
        , company.currency_id
        {% endif %}

        {% if using_purchasing_document_schedule_total %}
        , purchasing_document_schedule_total.lastest_scheduled_delivery_date as scheduled_delivery_date
        {% endif %}

        {% if using_purchasing_document_overview %}
        , purchasing_document_overview.latest_goods_receive_date
        , purchasing_document_overview.received_quantity as purchasing_delivered_quantity
        , purchasing_document_overview.received_value_in_local_curr as purchase_delivered_amount
        , purchasing_document_overview.invoice_value_local_curr as purchase_invoiced_amount
        , purchasing_document_overview.delivery_completed
        , case
            when purchasing_document_item.delivery_completed <> ''
                then cast(0 as {{ dbt.type_numeric() }})
            else (purchasing_document_item.purchase_order_quantity - coalesce(purchasing_document_overview.received_quantity, 0))
        end as purchase_open_quantity
        , case
            when coalesce(purchasing_document_overview.delivery_completed, 'n') <> ' '
                and coalesce(purchasing_document_overview.received_quantity, 0) < purchasing_document_item.purchase_order_quantity
                then cast(1 as {{ dbt.type_numeric() }})
            else cast(0 as {{ dbt.type_numeric() }})
        end as purchase_item_open_count
        , case
            when coalesce(purchasing_document_overview.delivery_completed, 'n') <> ' '
                or purchasing_document_overview.received_quantity >= purchasing_document_item.purchase_order_quantity
                then cast(1 as {{ dbt.type_numeric() }})
            else cast(0 as {{ dbt.type_numeric() }})
        end as purchase_item_closed_count
        {% endif %}

        {% if using_purchasing_document_header and using_purchasing_document_overview %}
        , {{ dbt.datediff("purchasing_document_header.purchasing_document_date", "purchasing_document_overview.latest_goods_receive_date", "day") }} as purchase_deliver_late_days
        , case
            when purchasing_document_overview.delivery_completed is not null
                then cast(0 as {{ dbt.type_numeric() }})
            else (
                purchasing_document_item.net_order_po_currency_val *
                (
                    case
                        when purchasing_document_header.exchange_rate < 0
                            then -1 / purchasing_document_header.exchange_rate
                        else purchasing_document_header.exchange_rate
                    end
                )
            ) - purchasing_document_overview.received_value_in_local_curr
        end as purchase_open_amount
        {% endif %}

        {% if using_purchasing_document_overview and using_purchasing_document_schedule_total %}
        , {{ dbt.datediff("purchasing_document_schedule_total.lastest_scheduled_delivery_date", "purchasing_document_overview.latest_goods_receive_date", "day") }} as purchase_late_lead_days
        , case
            when purchasing_document_overview.latest_goods_receive_date > purchasing_document_schedule_total.lastest_scheduled_delivery_date
                then purchasing_document_overview.received_quantity
            else cast(0 as {{ dbt.type_numeric() }})
        end as purchase_late_quantity
        , case
            when purchasing_document_overview.latest_goods_receive_date > purchasing_document_schedule_total.lastest_scheduled_delivery_date
                then purchasing_document_overview.received_value_in_local_curr
            else cast(0 as {{ dbt.type_numeric() }})
        end as purchase_late_amount
        , case
            when purchasing_document_overview.latest_goods_receive_date > purchasing_document_schedule_total.lastest_scheduled_delivery_date
                then cast(1 as {{ dbt.type_numeric() }})
            else cast(0 as {{ dbt.type_numeric() }})
        end as purchase_item_late_count
        {% endif %}

        , cast(1 as {{ dbt.type_numeric() }}) as purchase_order_item_count

    from purchasing_document_item

    {% if using_purchasing_document_header %}
    left join purchasing_document_header
        on purchasing_document_header.purchasing_document_id = purchasing_document_item.purchasing_document_id
        and purchasing_document_header.client_id = purchasing_document_item.client_id
    {% endif %}

    {% if using_company %}
    left join company
        on company.company_code_id = purchasing_document_header.company_code_id
        and company.client_id = purchasing_document_header.client_id
    {% endif %}

    {% if using_purchasing_document_overview %}
    left join purchasing_document_overview
        on purchasing_document_overview.purchasing_document_id = purchasing_document_item.purchasing_document_id
        and purchasing_document_overview.purchasing_document_item_id = purchasing_document_item.purchasing_document_item_id
        and purchasing_document_overview.client_id = purchasing_document_item.client_id
    {% endif %}

    {% if using_purchasing_document_schedule_total %}
    left join purchasing_document_schedule_total
        on purchasing_document_schedule_total.purchasing_document_id = purchasing_document_item.purchasing_document_id
        and purchasing_document_schedule_total.purchasing_document_item_id = purchasing_document_item.purchasing_document_item_id
        and purchasing_document_schedule_total.client_id = purchasing_document_item.client_id
    {% endif %}
)

select *
from final
