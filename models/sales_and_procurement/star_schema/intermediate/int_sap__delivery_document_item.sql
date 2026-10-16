{{ config(enabled=var('sap_using_lips', True)) }}

select
    mandt as client_id,
    vbeln as delivery_document_id,
    posnr as delivery_document_item_id,
    matnr as material_id,
    werks as plant_id,
    lgort as storage_location_id,
    charg as batch_id,
    -- vgbel/vgpos reference the originating sales order (vbak.vbeln / vbap.posnr),
    -- kept in raw zero-padded SAP format so sap__fact_delivery can rebuild the
    -- same sales_order_line entity key used by sap__fact_sales_order / sap__fact_billing.
    vgbel as sales_document_id,
    vgpos as sales_document_item_id,
    aufnr as order_id,
    lfimg as delivery_quantity,
    meins as base_uom_id,
    netwr as net_val,
    brgew as gross_weight,
    ntgew as net_weight,
    gewei as weight_uom_id,
    volum as volume,
    voleh as volume_uom_id,
    erdat as created_date,
    _fivetran_deleted,
    _fivetran_synced
from {{ ref('stg_sap__lips') }}
