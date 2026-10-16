{{ config(enabled=var('sap_using_vbrp', True)) }}

select
    cast(mandt as {{ dbt.type_string() }}) as mandt,
    cast(vbeln as {{ dbt.type_string() }}) as vbeln,
    cast(posnr as {{ dbt.type_string() }}) as posnr,
    cast(matnr as {{ dbt.type_string() }}) as matnr,
    werks,
    charg,
    cast(aubel as {{ dbt.type_string() }}) as aubel,
    cast(aupos as {{ dbt.type_string() }}) as aupos,
    vgbel,
    vgpos,
    safe_cast(fkimg as {{ dbt.type_numeric() }}) as fkimg,
    vrkme,
    safe_cast(netwr as {{ dbt.type_numeric() }}) as netwr,
    safe_cast(mwsbp as {{ dbt.type_numeric() }}) as mwsbp,
    shkzg,
    prctr,
    kostl,
    erdat,
    _fivetran_deleted,
    _fivetran_synced
from {{ ref('stg_sap__vbrp_tmp') }}
