# Interpretación: Facturación (`sap__fact_billing`)

## Qué mide esta tabla de hechos

`sap__fact_billing` es la fact table a nivel de **línea de documento de facturación** (grano: `client_id` + `billing_document_number` + `billing_document_item`), construida a partir de VBRK (cabecera) y VBRP (ítem). Es la extensión que agregamos al star schema original — antes de esto, el proyecto no tenía visibilidad de facturación, solo de ventas y compras.

## Cómo leer los gráficos

- **Valor neto facturado por mes**: tendencia de `net_value` (ya con el signo invertido en anulaciones, aplicado en el modelo) agregado por `billing_date`.
- **Top 10 clientes por valor facturado**: a quién le estamos facturando realmente, no solo a quién le vendimos — compará este ranking contra el de `charts/ventas/` para detectar clientes con mucha venta pero poca facturación (señal de demora en el ciclo de cobro).
- **Distribución por tipo de documento**: `sd_document_category` separa facturas (`M`), notas de crédito (`O`) y sus anulaciones (`P`, `N`). Una proporción alta de notas de crédito puede señalar problemas de calidad en el proceso de venta o facturación.
- **KPIs de facturación**: `impuestos_total` es el monto total de impuestos facturados (`tax_amount`); `pct_lineas_anuladas` mide qué proporción de líneas tienen `cancellation_indicator` activo.

## Relación con las otras fact tables

Comparte la entidad `sales_order_line` con `sap__fact_sales_order` y `sap__fact_delivery` (vía los campos `VBRP.AUBEL`/`AUPOS`, que referencian el pedido de venta de origen). Esto permite responder "¿qué se vendió y todavía no se facturó?" combinando esta tabla con `fact_sales_order` — ver la métrica `sales_net_value_unbilled_amount` en el semantic layer (`SEMANTIC_LAYER.md`).

## Cosas a tener en cuenta

- El `billing_to_sales_value_ratio` (facturación / ventas) ronda el 17.7% sobre el histórico completo — es normal que sea bajo si hay mucho pedido reciente sin facturar todavía, pero conviene seguir esta proporción en el tiempo, no solo como foto.
- Esta tabla no indica si la factura fue cobrada — solo que fue emitida. Para seguimiento de cobranza hace falta integrar datos de cuentas por cobrar, que no están en este star schema.
