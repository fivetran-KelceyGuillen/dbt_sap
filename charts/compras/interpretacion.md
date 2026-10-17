# Interpretación: Compras (`sap__fact_purchasing_order`)

## Qué mide esta tabla de hechos

`sap__fact_purchasing_order` es la fact table a nivel de **línea de orden de compra** (grano: `client_id` + `purchasing_document_id` + `purchasing_document_item_id`), construida a partir de EKKO (cabecera), EKPO (ítem), EKBE (historial de recepciones/facturas) y EKET (programación de entrega). Es la única fact table del lado de procurement en este star schema — no comparte entidades con el ciclo sales-to-cash salvo `material` y `plant`.

## Cómo leer los gráficos

- **Monto comprado por mes**: tendencia de `purchase_order_amount` (ya convertido a la moneda de la sociedad usando el tipo de cambio de la cabecera) agregado por `purchasing_document_date`.
- **Top 10 proveedores por monto comprado**: concentración de gasto por proveedor. Si 1-2 proveedores explican una porción muy grande del total, hay riesgo de dependencia que vale la pena que compras revise (en el análisis original, los 2 principales proveedores concentraban ~42% del monto total).
- **Top 10 materiales por monto comprado**: qué insumos/materiales explican más del gasto.
- **KPIs de compras**: `pct_cancelacion` mide qué proporción del monto comprado fue cancelada posteriormente; `pct_entrega_tardia` mide qué proporción de líneas tuvo al menos un ítem entregado después de la fecha programada (`purchase_item_late_count`).

## Relación con las otras fact tables

No comparte la entidad `sales_order_line` con el resto (compras y ventas son procesos independientes en este negocio), pero sí comparte `material` y `plant` — permite cruzar "¿cuánto compramos de un material vs. cuánto vendimos del mismo material?" Ver la métrica cross-model `purchase_to_sales_value_ratio` en `SEMANTIC_LAYER.md`.

## Cosas a tener en cuenta — IMPORTANTE

- **Esta tabla ya tiene aplicado un filtro de calidad de datos.** Durante el análisis encontramos 41 líneas (0.12% del total) que concentraban el 97.6% del monto total de compras: 30 líneas con un precio unitario de exactamente $20,121,212.00 (los dígitos coinciden con la fecha `2012-12-12`, señal de que alguien tipeó una fecha en el campo de precio por error) y 5 documentos con cantidades hasta 1.000.000 de veces más grandes que cualquier otra orden del mismo material al mismo precio. El modelo `sap__fact_purchasing_order.sql` excluye estas líneas con un filtro documentado línea por línea — sin ese filtro, el ratio compras/ventas daba un 6,091% sin sentido de negocio. Ver `SEMANTIC_LAYER.md` para el detalle completo de la investigación.
- Esas exclusiones están pendientes de confirmación formal con el equipo de compras — son casi seguro errores de carga, pero no hay 100% de certeza sobre los 5 documentos de cantidad atípica.
