{{ config(enabled=var('sap_using_tvag', True)) }}

select
	client_id,
	reason_rejection_id, 
	description as rejection_reason_description
from {{ ref('int_sap__sales_document_rejection_reason') }}

