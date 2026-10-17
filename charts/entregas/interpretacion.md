# Interpretación: Entregas (`sap__fact_delivery`)

## Qué mide esta tabla de hechos

`sap__fact_delivery` es la fact table a nivel de **línea de entrega/despacho** (grano: `client_id` + `delivery_document_number` + `delivery_document_item`), construida a partir de LIKP (cabecera) y LIPS (ítem). Es la segunda extensión que agregamos al star schema, junto con facturación.

## Cómo leer los gráficos

- **Valor neto despachado por mes**: tendencia de `net_value` agregado por `delivery_date`.
- **Top 10 materiales por valor despachado**: qué se está moviendo físicamente desde el depósito, no solo qué se vendió — una diferencia marcada contra el ranking de `charts/ventas/` puede señalar productos vendidos pero con problemas de stock o logística.
- **Valor despachado por planta**: usa `shipping_plant_id` (planta a nivel de cabecera de la entrega) vía `sap__dim_plant`, para ver qué centro de distribución concentra más despachos.
- **KPIs de entregas**: `promedio_dias_atraso_salida` compara `planned_goods_issue_date` (fecha planificada de salida de mercancía) contra `actual_goods_issue_date` (fecha real) — un promedio positivo indica atrasos sistemáticos en el despacho.

## Relación con las otras fact tables

Comparte la entidad `sales_order_line` con `sap__fact_sales_order` y `sap__fact_billing` (vía `LIPS.VGBEL`/`VGPOS`, que referencian el pedido de venta de origen). Permite responder "¿qué está vendido pero no despachado?" (ver `sales_net_value_undelivered_amount` en `SEMANTIC_LAYER.md`) y, cruzando con facturación, "¿qué se despachó pero no se facturó?" — una señal de riesgo de caja.

## Cosas a tener en cuenta — IMPORTANTE

- **La cobertura histórica de esta tabla es mucho menor que la de ventas o facturación.** En el análisis original (ver `SEMANTIC_LAYER.md`), el valor total despachado fue de apenas ~$27.7M contra ~$10.6 mil millones de ventas y ~$1.9 mil millones de facturación — una proporción (0.26%) demasiado baja para ser realista como medida de cumplimiento logístico real. Antes de usar estos gráficos para decisiones operativas, confirmá con el equipo de datos si LIKP/LIPS tienen la misma profundidad histórica sincronizada que VBAK/VBRK, o si hay un corte de fecha más reciente a partir del cual los datos de entregas sí son representativos.
- `fact_delivery` no tiene dimensión de canal de distribución (`distribution_channel_id`) porque esa columna no existe en LIKP a nivel de cabecera de entrega — es un atributo de la orden de venta, no de la logística de despacho.
