# Interpretación: Ventas (`sap__fact_sales_order`)

## Qué mide esta tabla de hechos

`sap__fact_sales_order` es la fact table a nivel de **línea de orden de venta** (grano: `client_id` + `sales_document_number` + `sales_document_item`), construida a partir de VBAK (cabecera), VBAP (ítem), VBUK/VBUP (estado de entrega). Cada fila es un ítem de un pedido de venta — no una factura ni una entrega, sino la intención de venta registrada en SAP.

## Cómo leer los gráficos

- **Valor neto de ventas por mes**: tendencia de `net_value` agregado por `document_date`. Sirve para detectar estacionalidad y picos puntuales (ej. un pedido grande de un solo cliente puede inflar un mes específico — conviene cruzar con el gráfico de top clientes antes de sacar conclusiones de tendencia).
- **Top 10 clientes por valor neto de ventas**: concentración de ingresos por cliente. Si pocos clientes explican la mayoría del valor, hay riesgo de concentración de cartera que vale la pena monitorear.
- **Top 10 materiales por valor neto de ventas**: qué productos mueven más valor. Útil para priorizar foco comercial o detectar dependencia de un único producto.
- **KPIs de ventas**: `valor_neto_total` es el total histórico vendido; `precio_neto_promedio` es el precio por unidad sin ponderar por cantidad (no confundir con un precio promedio ponderado); `pct_devolucion` mide qué proporción del valor vendido corresponde a líneas marcadas como devolución (`returns_item`).

## Relación con las otras fact tables

Esta es la **primera pierna** del ciclo sales-to-cash. Comparte la entidad `sales_order_line` con `sap__fact_delivery` y `sap__fact_billing` — un pedido de venta recién se convierte en ingreso real cuando pasa por despacho y facturación. Ver `charts/facturacion/` y `charts/entregas/` para el resto del ciclo, y `SEMANTIC_LAYER.md` en la raíz del repo para el detalle completo de métricas y entidades compartidas.

## Cosas a tener en cuenta

- `sd_document_category` distingue entre orden (`C`) y nota de crédito por devolución (`H`) — si necesitás ventas "puras" sin devoluciones, filtrá por `C`.
- Esta tabla no refleja si el pedido realmente se despachó o se cobró — para eso hay que cruzar con `fact_delivery` y `fact_billing`.
