{{ config(enabled=var('sap_using_lips', True)) }}

select
    cast(mandt as {{ dbt.type_string() }}) as mandt,
    cast(vbeln as {{ dbt.type_string() }}) as vbeln,
    cast(posnr as {{ dbt.type_string() }}) as posnr,
    cast(matnr as {{ dbt.type_string() }}) as matnr,
    werks,
    lgort,
    charg,
    cast(vgbel as {{ dbt.type_string() }}) as vgbel,
    cast(vgpos as {{ dbt.type_string() }}) as vgpos,
    aufnr,
    safe_cast(lfimg as {{ dbt.type_numeric() }}) as lfimg,
    meins,
    safe_cast(netwr as {{ dbt.type_numeric() }}) as netwr,
    safe_cast(brgew as {{ dbt.type_numeric() }}) as brgew,
    safe_cast(ntgew as {{ dbt.type_numeric() }}) as ntgew,
    gewei,
    safe_cast(volum as {{ dbt.type_numeric() }}) as volum,
    voleh,
    erdat,
    _fivetran_deleted,
    _fivetran_synced
from {{ ref('stg_sap__lips_tmp') }}
