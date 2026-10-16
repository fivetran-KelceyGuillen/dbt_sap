{{ config(enabled=var('sap_using_likp', True)) }}

select
    cast(mandt as {{ dbt.type_string() }}) as mandt,
    cast(vbeln as {{ dbt.type_string() }}) as vbeln,
    lfart,
    cast(kunnr as {{ dbt.type_string() }}) as kunnr,
    werks,
    vstel,
    route,
    vkorg,
    lfdat,

    wadat,
    wadat_ist,
    erdat,
    safe_cast(netwr as {{ dbt.type_numeric() }}) as netwr,
    waerk,
    safe_cast(btgew as {{ dbt.type_numeric() }}) as btgew,
    safe_cast(ntgew as {{ dbt.type_numeric() }}) as ntgew,
    gewei,
    safe_cast(volum as {{ dbt.type_numeric() }}) as volum,
    voleh,
    vbtyp,
    _fivetran_deleted,
    _fivetran_synced
from {{ ref('stg_sap__likp_tmp') }}
