{{ config(enabled=var('sap_using_vbrk', True)) }}

select *
from {{ var('vbrk') }}
