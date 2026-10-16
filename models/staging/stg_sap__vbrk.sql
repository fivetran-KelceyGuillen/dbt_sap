{{ config(enabled=var('sap_using_vbrk', True)) }}

select
    cast(mandt as {{ dbt.type_string() }}) as mandt,
    cast(vbeln as {{ dbt.type_string() }}) as vbeln,
    fkart,
    vbtyp,
    cast(kunag as {{ dbt.type_string() }}) as kunag,
    cast(kunrg as {{ dbt.type_string() }}) as kunrg,
    vkorg,
    vtweg,
    spart,
    fkdat,
    erdat,
    safe_cast(netwr as {{ dbt.type_numeric() }}) as netwr,
    waerk,
    zterm,
    fksto,
    _fivetran_deleted,
    _fivetran_synced
from {{ ref('stg_sap__vbrk_tmp') }}
