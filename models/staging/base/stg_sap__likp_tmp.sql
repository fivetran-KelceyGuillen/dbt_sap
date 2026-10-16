{{ config(enabled=var('sap_using_likp', True)) }}

select *
from {{ var('likp') }}
