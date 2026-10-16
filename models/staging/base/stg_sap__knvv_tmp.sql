{{ config(enabled=var('sap_using_knvv', True)) }}

select *
from {{ var('knvv') }}
