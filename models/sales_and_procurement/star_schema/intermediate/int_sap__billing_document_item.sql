{{ config(enabled=var('sap_using_vbrp', True)) }}

select
    mandt as client_id,
    vbeln as billing_document_id,
    posnr as billing_document_item_id,
    matnr as material_id,
    werks as plant_id,
    charg as batch_id,
    -- aubel/aupos reference the originating sales order (vbak.vbeln / vbap.posnr),
    -- kept in their raw zero-padded SAP format so sap__fact_billing can rebuild
    -- the same sales_order_line entity key used by sap__fact_sales_order.
    aubel as sales_document_id,
    aupos as sales_document_item_id,
    vgbel as reference_document_id,
    vgpos as reference_document_item_id,
    fkimg as billed_quantity,
    vrkme as sales_uom_id,
    netwr as net_val,
    mwsbp as tax_amount_val,
    shkzg as debit_credit_indicator,
    prctr as profit_center_id,
    kostl as cost_center_id,
    erdat as created_date,
    _fivetran_deleted,
    _fivetran_synced
from {{ ref('stg_sap__vbrp') }}
