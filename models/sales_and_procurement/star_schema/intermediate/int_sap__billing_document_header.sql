{{ config(enabled=var('sap_using_vbrk', True)) }}

select
    mandt as client_id,
    vbeln as billing_document_id,
    fkart as billing_type_id,
    vbtyp as sd_document_category,
    kunag as sold_to_party_id,
    kunrg as payer_party_id,
    vkorg as sales_organization_id,
    vtweg as distribution_channel_id,
    spart as division_id,
    fkdat as billing_date,
    erdat as created_date,
    netwr as net_val,
    waerk as sd_document_currency_id,
    zterm as payment_terms_id,
    fksto as cancellation_indicator,
    _fivetran_deleted,
    _fivetran_synced
from {{ ref('stg_sap__vbrk') }}
