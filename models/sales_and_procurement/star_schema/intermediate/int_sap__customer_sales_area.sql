{{ config(enabled=var('sap_using_knvv', True)) }}

select
    mandt as client_id,
    kunnr as customer_id,
    vkorg as sales_organization_id,
    vtweg as distribution_channel_id,
    spart as division_id,
    kdgrp as customer_group_id,
    bzirk as sales_district_id,
    vkbur as sales_office_id,
    vkgrp as sales_group_id,
    waers as currency_id,
    zterm as payment_terms_id,
    antlf as max_partial_deliveries,
    autlf as complete_delivery,
    lifsd as delivery_block_id,
    faksd as billing_block_id,
    loevm as deletion_flag,
    erdat as created_date,
    _fivetran_deleted,
    _fivetran_synced
from {{ ref('stg_sap__knvv') }}
