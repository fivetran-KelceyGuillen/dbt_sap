{{ config(enabled=var('sap_using_vbrp', True)) }}

select *
from {{ var('vbrp') }}
