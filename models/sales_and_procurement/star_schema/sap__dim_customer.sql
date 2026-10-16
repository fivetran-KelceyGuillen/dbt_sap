{{ config(enabled=var('sap_using_kna1', True)) }}

select
	client_id,
	ltrim(customer_id, '0' ) as customer_number,
	country_key_id,
	-- name (KNA1.PSON1, person name) is blank for virtually all company
	-- customers; name1 (KNA1.NAME1) is the actual organization/company name.
	name1 as customer_name,
	city,
	customer_id 	
from {{ ref('int_sap__customer') }}

