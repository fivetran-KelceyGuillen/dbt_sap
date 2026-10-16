{{ config(enabled=var('sap_using_lips', True)) }}

select *
from {{ var('lips') }}
