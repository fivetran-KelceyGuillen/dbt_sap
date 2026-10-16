{{ config(enabled=var('sap_using_likp', True)) }}

select
    mandt as client_id,
    vbeln as delivery_document_id,
    lfart as delivery_type_id,
    kunnr as ship_to_party_id,
    werks as plant_id,
    vstel as shipping_point_id,
    route as route_id,
    vkorg as sales_organization_id,
    lfdat as delivery_date,

    wadat as planned_goods_issue_date,
    wadat_ist as actual_goods_issue_date,
    erdat as created_date,
    netwr as net_val,
    waerk as sd_document_currency_id,
    btgew as total_weight,
    ntgew as net_weight,
    gewei as weight_uom_id,
    volum as volume,
    voleh as volume_uom_id,
    vbtyp as sd_document_category,
    _fivetran_deleted,
    _fivetran_synced
from {{ ref('stg_sap__likp') }}
