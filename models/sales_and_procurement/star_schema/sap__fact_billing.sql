{% set using_billing_document_header = var('sap_using_vbrk', True) %}
{% set using_billing_document_item = var('sap_using_vbrp', True) %}

{{ config(enabled=using_billing_document_header) }}

with billing_document_header as (
    select *
    from {{ ref('int_sap__billing_document_header') }}

{% if using_billing_document_item %}
), billing_document_item as (
    select *
    from {{ ref('int_sap__billing_document_item') }}
{% endif %}

), final as (
    select
        billing_document_header.client_id,
        ltrim(billing_document_header.billing_document_id, '0') as billing_document_number,

        billing_document_header.billing_type_id,
        billing_document_header.sd_document_category,
        billing_document_header.sold_to_party_id as sold_to_customer_id,
        billing_document_header.payer_party_id,
        billing_document_header.sales_organization_id,
        billing_document_header.distribution_channel_id,
        billing_document_header.division_id,
        billing_document_header.billing_date,
        billing_document_header.created_date,
        billing_document_header.sd_document_currency_id,
        billing_document_header.payment_terms_id,
        billing_document_header.cancellation_indicator,
        billing_document_header.billing_document_id

        {% if using_billing_document_item %}
        , ltrim(billing_document_item.billing_document_item_id, '0') as billing_document_item
        , billing_document_item.material_id
        , billing_document_item.plant_id
        -- rebuilt in the same raw/ltrimmed shape as sap__fact_sales_order's
        -- sales_order_line entity key, so the two facts can share that entity
        , billing_document_item.sales_document_id
        , ltrim(billing_document_item.sales_document_item_id, '0') as sales_document_item
        , billing_document_item.billed_quantity
        , billing_document_item.sales_uom_id
        , case
            when lower(billing_document_header.cancellation_indicator) = 'x' then billing_document_item.net_val * -1
            else billing_document_item.net_val
        end as net_value
        , case
            when lower(billing_document_header.cancellation_indicator) = 'x' then billing_document_item.tax_amount_val * -1
            else billing_document_item.tax_amount_val
        end as tax_amount
        , billing_document_item._fivetran_deleted
        , billing_document_item._fivetran_synced
        {% endif %}

    from billing_document_header

    {% if using_billing_document_item %}
    inner join billing_document_item
        on billing_document_header.billing_document_id = billing_document_item.billing_document_id
        and billing_document_header.client_id = billing_document_item.client_id
    {% endif %}

)

select *
from final
