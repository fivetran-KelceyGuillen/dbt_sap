{{ config(enabled=var('sap_using_knvv', True)) }}

select
    client_id,
    customer_id,
    ltrim(customer_id, '0') as customer_number,
    sales_organization_id,
    distribution_channel_id,
    division_id,
    customer_group_id,
    sales_district_id,
    sales_office_id,
    sales_group_id,
    currency_id,
    payment_terms_id,
    max_partial_deliveries,
    complete_delivery,
    delivery_block_id,
    billing_block_id,
    deletion_flag
from {{ ref('int_sap__customer_sales_area') }}
