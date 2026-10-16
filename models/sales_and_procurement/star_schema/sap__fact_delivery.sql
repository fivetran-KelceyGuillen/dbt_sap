{% set using_delivery_document_header = var('sap_using_likp', True) %}
{% set using_delivery_document_item = var('sap_using_lips', True) %}

{{ config(enabled=using_delivery_document_header) }}

with delivery_document_header as (
    select *
    from {{ ref('int_sap__delivery_document_header') }}

{% if using_delivery_document_item %}
), delivery_document_item as (
    select *
    from {{ ref('int_sap__delivery_document_item') }}
{% endif %}

), final as (
    select
        delivery_document_header.client_id,
        ltrim(delivery_document_header.delivery_document_id, '0') as delivery_document_number,

        delivery_document_header.delivery_type_id,
        delivery_document_header.sd_document_category,
        delivery_document_header.ship_to_party_id,
        delivery_document_header.plant_id as shipping_plant_id,
        delivery_document_header.shipping_point_id,
        delivery_document_header.route_id,
        delivery_document_header.sales_organization_id,
        delivery_document_header.delivery_date,

        delivery_document_header.planned_goods_issue_date,
        delivery_document_header.actual_goods_issue_date,
        delivery_document_header.created_date,
        delivery_document_header.sd_document_currency_id,
        delivery_document_header.total_weight,
        delivery_document_header.net_weight as header_net_weight,
        delivery_document_header.weight_uom_id as header_weight_uom_id,
        delivery_document_header.volume as header_volume,
        delivery_document_header.volume_uom_id as header_volume_uom_id,
        delivery_document_header.delivery_document_id

        {% if using_delivery_document_item %}
        , ltrim(delivery_document_item.delivery_document_item_id, '0') as delivery_document_item
        , delivery_document_item.material_id
        , delivery_document_item.plant_id
        , delivery_document_item.storage_location_id
        -- rebuilt in the same raw/ltrimmed shape as sap__fact_sales_order's
        -- sales_order_line entity key, so all three facts can share that entity
        , delivery_document_item.sales_document_id
        , ltrim(delivery_document_item.sales_document_item_id, '0') as sales_document_item
        , delivery_document_item.delivery_quantity
        , delivery_document_item.base_uom_id
        , delivery_document_item.net_val as net_value
        , delivery_document_item.gross_weight
        , delivery_document_item.net_weight as item_net_weight
        , delivery_document_item.weight_uom_id as item_weight_uom_id
        , delivery_document_item.volume as item_volume
        , delivery_document_item.volume_uom_id as item_volume_uom_id
        , delivery_document_item._fivetran_deleted
        , delivery_document_item._fivetran_synced
        {% endif %}

    from delivery_document_header

    {% if using_delivery_document_item %}
    inner join delivery_document_item
        on delivery_document_header.delivery_document_id = delivery_document_item.delivery_document_id
        and delivery_document_header.client_id = delivery_document_item.client_id
    {% endif %}

)

select *
from final
