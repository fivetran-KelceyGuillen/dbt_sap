{{ config(enabled=var('sap_using_knvv', True)) }}

select
    cast(mandt as {{ dbt.type_string() }}) as mandt,
    cast(kunnr as {{ dbt.type_string() }}) as kunnr,
    vkorg,
    vtweg,
    spart,
    kdgrp,
    bzirk,
    vkbur,
    vkgrp,
    waers,
    zterm,
    safe_cast(antlf as {{ dbt.type_numeric() }}) as antlf,
    autlf,
    lifsd,
    faksd,
    loevm,
    erdat,
    _fivetran_deleted,
    _fivetran_synced
from {{ ref('stg_sap__knvv_tmp') }}
