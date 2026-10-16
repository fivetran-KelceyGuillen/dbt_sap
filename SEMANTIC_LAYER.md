# Semantic Layer — `sales_and_procurement`

Documentación de referencia de todo el semantic layer (dbt Semantic Layer / MetricFlow) definido en
`models/sales_and_procurement/star_schema/sales_and_procurement.yml`. Cubre los modelos semánticos
originales del paquete (compras y ventas) y la extensión de facturación, entregas y datos de área de
ventas del cliente agregada sobre VBRK/VBRP, LIKP/LIPS y KNVV.

> Spec utilizada: **latest spec** de dbt (`semantic_model: enabled: true` a nivel de modelo,
> entidades/dimensiones declaradas en `columns:`, bloque `derived_semantics:` para entidades/dimensiones
> calculadas). Todas las queries se hacen con `dbt sl query` o la herramienta de Semantic Layer del
> agente — no hace falta escribir SQL a mano para consumir estas métricas.

## Índice

- [Cómo está organizado](#cómo-está-organizado)
- [Entidades compartidas (joins entre modelos)](#entidades-compartidas-joins-entre-modelos)
- [Modelos de dimensión](#modelos-de-dimensión)
  - [`dim_customer`](#dim_customer)
  - [`dim_customer_sales_area`](#dim_customer_sales_area)
  - [`dim_material`](#dim_material)
  - [`dim_plant`](#dim_plant)
  - [`dim_purchasing_order`](#dim_purchasing_order)
  - [`dim_purchasing_organization`](#dim_purchasing_organization)
  - [`dim_rejection_reason`](#dim_rejection_reason)
  - [`dim_vendor`](#dim_vendor)
- [Modelos de hechos (fact)](#modelos-de-hechos-fact)
  - [`fact_purchasing_order`](#fact_purchasing_order)
  - [`fact_sales_order`](#fact_sales_order)
  - [`fact_billing`](#fact_billing)
  - [`fact_delivery`](#fact_delivery)
- [Métricas cross-model (nivel proyecto)](#métricas-cross-model-nivel-proyecto)
- [Preguntas de negocio que ya se pueden responder](#preguntas-de-negocio-que-ya-se-pueden-responder)
- [Consideraciones y limitaciones conocidas](#consideraciones-y-limitaciones-conocidas)

---

## Cómo está organizado

El semantic layer cubre tres procesos de negocio conectados por una misma clave de línea de orden de
venta:

```
Compras (purchasing)                 Ciclo Sales-to-Cash (sales-to-cash)
┌─────────────────────┐              ┌──────────────┐      ┌────────────────┐      ┌───────────────┐
│ fact_purchasing_order│              │ fact_sales_  │ ───► │ fact_delivery  │ ───► │ fact_billing   │
└─────────────────────┘              │ order        │      │ (LIKP/LIPS)    │      │ (VBRK/VBRP)    │
                                      └──────────────┘      └────────────────┘      └───────────────┘
                                             │                      │                      │
                                             └──────── entidad compartida: sales_order_line ┘
```

- **Compras**: una sola fact (`fact_purchasing_order`) con sus dimensiones de apoyo
  (`dim_vendor`, `dim_purchasing_organization`, `dim_purchasing_order`).
- **Sales-to-cash**: tres facts a nivel de línea — venta, entrega y facturación — que comparten la
  entidad `sales_order_line`. Esto permite responder preguntas de principio a fin del ciclo
  (vendido → despachado → facturado) sin escribir SQL, solo combinando métricas de los tres modelos
  en una misma query del semantic layer.
- **Dimensiones compartidas** entre ambos procesos: `dim_customer`, `dim_material`, `dim_plant`.
- **`dim_customer_sales_area`** es una dimensión adicional, más fina que `dim_customer` (grano
  cliente + organización de ventas + canal de distribución + división), para atributos comerciales
  específicos de cada combinación (bloqueos, condiciones de pago, moneda).

## Entidades compartidas (joins entre modelos)

Estas entidades existen en más de un modelo semántico con la **misma fórmula y el mismo label** (es
un requisito de MetricFlow: una entidad con el mismo nombre en dos modelos debe tener el mismo label).
Son el mecanismo que permite combinar métricas de distintos modelos en una sola consulta.

| Entidad | Fórmula (`expr`) | Aparece en | Label |
|---|---|---|---|
| `customer` | `concat(client_id, '-', customer_id)` (o `sold_to_customer_id` / `ship_to_party_id` según el modelo) | `dim_customer`, `dim_customer_sales_area` (foreign), `fact_sales_order` (foreign), `fact_billing` (foreign), `fact_delivery` (foreign) | Cliente |
| `material` | `concat(client_id, '-', material_id)` | `dim_material`, `fact_purchasing_order`, `fact_sales_order`, `fact_billing`, `fact_delivery` | Material |
| `plant` | `concat(client_id, '-', plant_id)` | `dim_plant`, `fact_purchasing_order`, `fact_sales_order`, `fact_billing`, `fact_delivery` | Planta |
| `company` | `concat(client_id, '-', company_code_id)` | `dim_purchasing_order`, `dim_purchasing_organization`, `fact_purchasing_order` | Código de Sociedad |
| `purchasing_document` | `concat(client_id, '-', purchasing_document_id)` | `dim_purchasing_order`, `fact_purchasing_order` (foreign) | Documento de Compra |
| `purchasing_organization` | `concat(client_id, '-', company_code_id, '-', purchasing_organization_id)` | `dim_purchasing_organization`, `fact_purchasing_order` (foreign) | Organización de Compras |
| `vendor` | `concat(client_id, '-', vendor_id)` | `dim_vendor`, `fact_purchasing_order` (foreign) | Proveedor |
| **`sales_order_line`** | `concat(client_id, '-', sales_document_id, '-', sales_document_item)` | `fact_sales_order` (**primary**), `fact_billing` (foreign), `fact_delivery` (foreign) | Línea de Orden de Venta |

La entidad `sales_order_line` es la pieza clave de la extensión: en `fact_billing` y `fact_delivery`
se reconstruye con el mismo formato (documento sin recortar + ítem sin ceros a la izquierda) que usa
`fact_sales_order` como clave primaria, usando los campos `VBRP.AUBEL`/`AUPOS` y `LIPS.VGBEL`/`VGPOS`
que SAP usa para referenciar el pedido de venta de origen.

## Modelos de dimensión

### `dim_customer`
**Modelo dbt:** `sap__dim_customer` · **Fuente:** KNA1 · **Grano:** cliente (`client_id` + `customer_id`)

Entidad primaria: `customer` — `concat(client_id, '-', customer_id)`.

| Dimensión | Descripción |
|---|---|
| `client_id` | Mandante SAP (mandt) |
| `customer_number` | Número de cliente en SAP |
| `country_key_id` | País del cliente |
| `customer_name` | Nombre completo |
| `city` | Ciudad |

No tiene métricas propias (es una dimensión pura).

### `dim_customer_sales_area`
**Modelo dbt:** `sap__dim_customer_sales_area` · **Fuente:** KNVV (nueva) · **Grano:** cliente + organización de ventas + canal de distribución + división

Entidad primaria: `customer_sales_area` — `concat(client_id, '-', customer_id, '-', sales_organization_id, '-', distribution_channel_id, '-', division_id)`.
Entidad foránea: `customer`.

⚠️ Un mismo cliente puede tener varias filas (una por cada combinación de organización de
ventas/canal/división en la que opera) — es una dimensión de grano más fino que `dim_customer`.

| Dimensión | Descripción |
|---|---|
| `customer_number` | Número de cliente |
| `sales_organization_id` | Organización de ventas |
| `distribution_channel_id` | Canal de distribución |
| `division_id` | División |
| `customer_group_id` | Grupo de cliente |
| `sales_district_id` | Zona de ventas |
| `sales_office_id` | Oficina de ventas |
| `sales_group_id` | Grupo de ventas |
| `currency_id` | Moneda de esta área de ventas |
| `payment_terms_id` | Condiciones de pago |
| `max_partial_deliveries` | Máximo de entregas parciales permitidas |
| `complete_delivery` | Indicador de entrega completa |
| `delivery_block_id` | Motivo de bloqueo de entrega |
| `billing_block_id` | Motivo de bloqueo de facturación |
| `deletion_flag` | Marca de eliminación |

No tiene métricas propias (es una dimensión pura).

### `dim_material`
**Modelo dbt:** `sap__dim_material` · **Fuente:** MARA/MAKT · **Grano:** material (`client_id` + `material_id`)

Entidad primaria: `material` — `concat(client_id, '-', material_id)`.

| Dimensión | Descripción |
|---|---|
| `material_number` | Identificador único del material |
| `material_description` | Descripción del material |
| `material_type_id` / `material_type_description` | Tipo de material |
| `base_uom_id` | Unidad de medida base |
| `weight_uom_id` | Unidad de medida de peso |
| `gross_weight` | Peso bruto (atributo numérico, no es una métrica agregable) |

### `dim_plant`
**Modelo dbt:** `sap__dim_plant` · **Fuente:** T001W · **Grano:** planta (`client_id` + `plant_id`)

Entidad primaria: `plant` — `concat(client_id, '-', plant_id)`.

| Dimensión | Descripción |
|---|---|
| `plant_name` | Nombre de la planta |
| `country_key_id` | País de la planta |

### `dim_purchasing_order`
**Modelo dbt:** `sap__dim_purchasing_order` · **Fuente:** EKKO · **Grano:** documento de compra (`client_id` + `purchasing_document_id`)

Entidad primaria: `purchasing_document`. Entidad foránea: `company`.

| Dimensión | Descripción |
|---|---|
| `purchasing_document_category` / `_txt` | Categoría del documento de compra |
| `purchasing_document_type_id` / `_text` | Tipo de documento (ej. NB, FO) |
| `purchasing_group_id` / `description_purchasing_group` | Grupo de compras responsable |
| `purchasing_document_status` / `_txt` | Estado del documento |
| `payment_terms` | Condiciones de pago |
| `reason_cancellation_id` | Motivo de cancelación |
| `company_code_id` | Sociedad asociada |

### `dim_purchasing_organization`
**Modelo dbt:** `sap__dim_purchasing_organization` · **Fuente:** T024E · **Grano:** sociedad + organización de compras

Entidad primaria: `purchasing_organization`. Entidad foránea: `company`.

| Dimensión | Descripción |
|---|---|
| `description` | Descripción de la organización de compras |

### `dim_rejection_reason`
**Modelo dbt:** `sap__dim_rejection_reason` · **Fuente:** TVAG · **Grano:** motivo de rechazo

Entidad primaria: `rejection_reason`.

| Dimensión | Descripción |
|---|---|
| `rejection_reason_description` | Descripción del motivo de rechazo |

### `dim_vendor`
**Modelo dbt:** `sap__dim_vendor` · **Fuente:** LFA1 · **Grano:** proveedor (`client_id` + `vendor_id`)

Entidad primaria: `vendor`.

| Dimensión | Descripción |
|---|---|
| `country_key_id` | País del proveedor |
| `name` / `name_2` | Nombre del proveedor |
| `city` | Ciudad |
| `sort_field` | Campo de ordenamiento |
| `authorization_group_id` | Grupo de autorización |
| `industry_key_id` | Clave de industria |
| `group_key` | Clave de agrupación |
| `vendor_account_group_id` | Grupo de cuentas del proveedor |

---

## Modelos de hechos (fact)

### `fact_purchasing_order`
**Modelo dbt:** `sap__fact_purchasing_order` · **Fuentes:** EKKO/EKPO/EKBE/EKET · **Grano:** línea de orden de compra (`client_id` + `purchasing_document_id` + `purchasing_document_item_id`) · **Dimensión temporal por defecto:** `purchasing_document_date`

**Entidades:**

| Entidad | Tipo | Fórmula |
|---|---|---|
| `purchasing_order_line` | primary | `concat(client_id, '-', purchasing_document_id, '-', purchasing_document_item_id)` |
| `purchasing_document` | foreign | `concat(client_id, '-', purchasing_document_id)` |
| `material` | foreign | `concat(client_id, '-', material_id)` |
| `plant` | foreign | `concat(client_id, '-', plant_id)` |
| `vendor` | foreign | `concat(client_id, '-', vendor_id)` |
| `purchasing_organization` | foreign | `concat(client_id, '-', company_code_id, '-', purchasing_organization_id)` |
| `company` | foreign | `concat(client_id, '-', company_code_id)` |

**Dimensiones clave:** `purchasing_document_date` / `scheduled_delivery_date` / `latest_goods_receive_date`
(tiempo), `currency_id`, `document_currency_id`, `purchasing_group_id`, `order_uom_id`, `returns_item`,
`rejection_indicator`, `delivery_completed`.

**Métricas:**

| Métrica | Tipo | Qué mide |
|---|---|---|
| `purchase_order_quantity_total` | simple (sum) | Cantidad total pedida |
| `purchase_order_amount_total` | simple (sum) | Monto total pedido |
| `purchase_delivered_quantity_total` | simple (sum) | Cantidad entregada |
| `purchase_delivered_amount_total` | simple (sum) | Monto entregado |
| `purchase_open_quantity_total` | simple (sum) | Cantidad aún abierta (sin entregar) |
| `purchase_open_amount_total` | simple (sum) | Monto abierto |
| `purchase_late_quantity_total` | simple (sum) | Cantidad entregada tarde |
| `purchase_late_amount_total` | simple (sum) | Monto entregado tarde |
| `purchase_cancelled_quantity_total` | simple (sum) | Cantidad cancelada |
| `purchase_cancelled_amount_total` | simple (sum) | Monto cancelado |
| `purchase_invoiced_amount_total` | simple (sum) | Monto facturado por el proveedor |
| `purchase_order_line_count` | simple (count) | Cantidad de líneas de orden de compra |
| `purchase_late_item_count` | simple (sum) | Cantidad de ítems entregados tarde |
| `purchase_open_item_count` | simple (sum) | Cantidad de ítems abiertos |
| `purchase_closed_item_count` | simple (sum) | Cantidad de ítems cerrados |
| `purchase_deliver_late_days_average` | simple (average) | Promedio de días de atraso en la entrega |
| `purchase_late_delivery_rate` | ratio | `purchase_late_item_count / purchase_order_line_count` — proporción de líneas entregadas tarde |
| `purchase_cancellation_rate` | ratio | `purchase_cancelled_amount_total / purchase_order_amount_total` — proporción cancelada del valor pedido |
| `purchase_order_amount_cumulative` | cumulative (histórico) | Monto acumulado de órdenes de compra, sin ventana |
| `purchase_order_amount_mtd` | cumulative (`grain_to_date: month`) | Monto acumulado desde el inicio del mes |
| `purchase_order_amount_l30d` | cumulative (`window: 30 days`) | Monto en ventana móvil de 30 días |
| `purchase_order_amount_growth_mom` | derived | Crecimiento % mes contra mes anterior |
| `purchase_order_amount_growth_yoy` | derived | Crecimiento % año contra año anterior |
| `purchase_order_average_value` | ratio | `purchase_order_amount_total / purchase_order_line_count` — valor promedio por línea |
| `purchase_fulfillment_rate` | ratio | `purchase_delivered_amount_total / purchase_order_amount_total` — tasa de cumplimiento |
| `purchase_net_order_value` | derived | `purchase_order_amount_total - purchase_cancelled_amount_total` — valor neto de cancelaciones |

### `fact_sales_order`
**Modelo dbt:** `sap__fact_sales_order` · **Fuentes:** VBAK/VBAP/VBUK/VBUP · **Grano:** línea de orden de venta (`client_id` + `sales_document_number` + `sales_document_item`) · **Dimensión temporal por defecto:** `document_date`

**Entidades:**

| Entidad | Tipo | Fórmula |
|---|---|---|
| `sales_order_line` | **primary** | `concat(client_id, '-', sales_document_id, '-', sales_document_item)` |
| `customer` | foreign | `concat(client_id, '-', sold_to_customer_id)` |
| `material` | foreign | `concat(client_id, '-', material_id)` |
| `plant` | foreign | `concat(client_id, '-', plant_id)` |

**Dimensiones clave:** `sd_document_category` (`C`=orden, `H`=nota de crédito por devolución),
`sales_document_type_id`, `order_reason_id`, `delivery_block_id`, `sales_organization_id`,
`distribution_channel_id`, `division_id`, `document_date` / `requested_delivery_date` / `created_date`
(tiempo), `returns_item`, `reason_rejection_id`, `delivery_status`, `overall_status`, `item_delivery_status`.

**Métricas:**

| Métrica | Tipo | Qué mide |
|---|---|---|
| `sales_order_quantity_total` | simple (sum) | Cantidad total pedida |
| `sales_net_value_total` | simple (sum) | Valor neto total de ventas |
| `sales_net_price_average` | simple (average) | Precio neto promedio (no ponderado por cantidad) |
| `sales_gross_weight_total` | simple (sum) | Peso bruto total |
| `sales_order_line_count` | simple (count) | Cantidad de líneas de orden de venta |
| `sales_net_value_per_unit` | ratio | `sales_net_value_total / sales_order_quantity_total` — valor neto por unidad, ponderado por cantidad (a diferencia de `sales_net_price_average`) |
| `sales_net_value_cumulative` | cumulative (histórico) | Valor neto acumulado, sin ventana |
| `sales_net_value_mtd` | cumulative (`grain_to_date: month`) | Valor neto acumulado desde el inicio del mes |
| `sales_net_value_l7d` | cumulative (`window: 7 days`) | Valor neto en ventana móvil de 7 días |
| `sales_net_value_growth_mom` | derived | Crecimiento % mes contra mes anterior |
| `sales_net_value_growth_yoy` | derived | Crecimiento % año contra año anterior |
| `sales_average_order_value` | ratio | `sales_net_value_total / sales_order_line_count` — valor promedio por línea de orden |
| `sales_returns_value_total` | simple (sum, filtrado) | Valor neto de las líneas marcadas como devolución (`returns_item != ''`) |
| `sales_return_rate` | ratio | `sales_returns_value_total / sales_net_value_total` — tasa de devolución |

### `fact_billing`
**Modelo dbt:** `sap__fact_billing` · **Fuentes:** VBRK/VBRP (nueva) · **Grano:** línea de facturación (`client_id` + `billing_document_number` + `billing_document_item`) · **Dimensión temporal por defecto:** `billing_date`

**Entidades:**

| Entidad | Tipo | Fórmula |
|---|---|---|
| `billing_line` | primary | `concat(client_id, '-', billing_document_id, '-', billing_document_item)` |
| `customer` | foreign | `concat(client_id, '-', sold_to_customer_id)` |
| `material` | foreign | `concat(client_id, '-', material_id)` |
| `plant` | foreign | `concat(client_id, '-', plant_id)` |
| `sales_order_line` | foreign | `concat(client_id, '-', sales_document_id, '-', sales_document_item)` — enlaza al pedido de venta de origen |

**Dimensiones clave:** `billing_type_id` (tipo de documento de facturación), `sd_document_category`
(`M`=factura, `O`=nota de crédito, `P`=anulación de factura, `N`=anulación de nota de crédito),
`payer_party_id`, `sales_organization_id`, `distribution_channel_id`, `division_id`, `billing_date` /
`created_date` (tiempo), `payment_terms_id`, `cancellation_indicator`.

**Métricas:**

| Métrica | Tipo | Qué mide |
|---|---|---|
| `billing_net_value_total` | simple (sum) | Valor neto total facturado (signo invertido en anulaciones) |
| `billing_quantity_total` | simple (sum) | Cantidad total facturada |
| `billing_tax_amount_total` | simple (sum) | Monto total de impuestos facturados |
| `billing_line_count` | simple (count) | Cantidad de líneas de facturación |
| `billing_net_value_average` | ratio | `billing_net_value_total / billing_line_count` — valor promedio por línea |
| `billing_net_value_cumulative` | cumulative (histórico) | Valor neto facturado acumulado, sin ventana |
| `billing_net_value_mtd` | cumulative (`grain_to_date: month`) | Valor neto facturado desde el inicio del mes |
| `billing_net_value_growth_mom` | derived | Crecimiento % mes contra mes anterior |

### `fact_delivery`
**Modelo dbt:** `sap__fact_delivery` · **Fuentes:** LIKP/LIPS (nueva) · **Grano:** línea de entrega (`client_id` + `delivery_document_number` + `delivery_document_item`) · **Dimensión temporal por defecto:** `delivery_date`

**Entidades:**

| Entidad | Tipo | Fórmula |
|---|---|---|
| `delivery_line` | primary | `concat(client_id, '-', delivery_document_id, '-', delivery_document_item)` |
| `customer` | foreign | `concat(client_id, '-', ship_to_party_id)` — ojo: acá es el **destinatario de la mercadería**, no necesariamente el mismo `sold_to_customer_id` de la venta |
| `material` | foreign | `concat(client_id, '-', material_id)` |
| `plant` | foreign | `concat(client_id, '-', plant_id)` |
| `sales_order_line` | foreign | `concat(client_id, '-', sales_document_id, '-', sales_document_item)` — enlaza al pedido de venta de origen |

**Dimensiones clave:** `delivery_type_id`, `sd_document_category`, `shipping_plant_id` (planta a nivel
de cabecera de la entrega, distinta de `plant_id` que es a nivel de ítem), `shipping_point_id`,
`route_id`, `sales_organization_id`, `delivery_date` / `planned_goods_issue_date` /
`actual_goods_issue_date` / `created_date` (tiempo), pesos y volúmenes a nivel de cabecera
(`total_weight`, `header_net_weight`, `header_volume`) y de ítem (`gross_weight`, `item_net_weight`,
`item_volume`), `storage_location_id`.

> Nota: esta fact **no tiene** `distribution_channel_id` — LIKP no trae ese campo a nivel de cabecera
> de entrega (es un atributo de la orden de venta, no de la logística de despacho).

**Métricas:**

| Métrica | Tipo | Qué mide |
|---|---|---|
| `delivery_net_value_total` | simple (sum) | Valor neto total despachado |
| `delivery_quantity_total` | simple (sum) | Cantidad total despachada |
| `delivery_gross_weight_total` | simple (sum) | Peso bruto total despachado |
| `delivery_line_count` | simple (count) | Cantidad de líneas de entrega |
| `delivery_net_value_average` | ratio | `delivery_net_value_total / delivery_line_count` — valor promedio por línea |
| `delivery_net_value_cumulative` | cumulative (histórico) | Valor neto despachado acumulado, sin ventana |
| `delivery_net_value_mtd` | cumulative (`grain_to_date: month`) | Valor neto despachado desde el inicio del mes |

---

## Métricas cross-model (nivel proyecto)

Estas métricas combinan modelos distintos (compras + ventas, o las tres piernas del ciclo
sales-to-cash) y por eso están declaradas en el bloque `metrics:` de nivel superior del archivo YAML,
no dentro de un modelo específico.

| Métrica | Tipo | Fórmula / definición | Qué mide |
|---|---|---|---|
| `purchase_to_sales_value_ratio` | ratio | `purchase_order_amount_total / sales_net_value_total` | Gasto en compras como proporción de los ingresos por ventas |
| `gross_margin_proxy_amount` | derived | `sales_net_value_total - purchase_order_amount_total` | Proxy de margen bruto entre modelos — **no es una cifra contable (GAAP)**, es una aproximación |
| `billing_to_sales_value_ratio` | ratio | `billing_net_value_total / sales_net_value_total` | Qué parte de lo vendido ya fue facturado |
| `sales_net_value_unbilled_amount` | derived | `sales_net_value_total - billing_net_value_total` | Monto vendido que todavía no se facturó |
| `delivery_to_sales_value_ratio` | ratio | `delivery_net_value_total / sales_net_value_total` | Qué parte de lo vendido ya fue despachado |
| `sales_net_value_undelivered_amount` | derived | `sales_net_value_total - delivery_net_value_total` | Monto vendido que todavía no se despachó |

---

## Preguntas de negocio que ya se pueden responder

Gracias a la entidad compartida `sales_order_line` y a las métricas cross-model, el semantic layer
permite responder sin SQL preguntas como:

- *"¿Cuánto llevamos vendido este mes y qué porcentaje ya facturamos?"* → `sales_net_value_mtd` +
  `billing_to_sales_value_ratio`.
- *"¿Qué pedidos están vendidos pero no despachados?"* → combinar `fact_sales_order` y
  `fact_delivery` por `sales_order_line`, o usar directamente `sales_net_value_undelivered_amount`.
- *"¿Qué se despachó pero todavía no se facturó?"* (riesgo de caja) → comparar
  `delivery_net_value_total` vs. `billing_net_value_total` por cliente o por mes.
- *"¿Cuál es nuestra relación compras/ventas por organización de compras?"* →
  `purchase_to_sales_value_ratio` agrupado por `purchasing_organization`.
- *"¿Qué clientes tienen bloqueo de facturación activo?"* → `dim_customer_sales_area` filtrando
  `billing_block_id`.

## Consideraciones y limitaciones conocidas

- **`dim_customer_sales_area` genera fan-out si se une solo por `customer`.** Como el grano es más
  fino que un cliente (puede haber varias filas por organización de ventas/canal/división), al
  cruzarla contra una fact por la entidad compartida `customer` sin filtrar por
  `sales_organization_id`/`distribution_channel_id`/`division_id` se puede duplicar el valor de las
  métricas. Conviene filtrar siempre por esas dimensiones cuando se combine con una fact.
- **`fact_delivery` no tiene `distribution_channel_id`** porque esa columna no existe realmente en
  LIKP (el source YAML original la documentaba por error).
- **Cobertura histórica dispar.** El valor total despachado en `fact_delivery` (~$27.7M) es mucho
  menor que el de ventas (~$10.6B) o facturación (~$1.9B) en el ambiente de desarrollo. Antes de usar
  `fact_delivery` para medir cumplimiento logístico real, vale la pena confirmar si LIKP/LIPS tienen
  la misma profundidad histórica sincronizada que VBAK/VBRK.
- **Tipos de datos del conector.** VBRK.NETWR, VBRP.NETWR/MWSBP/FKIMG, VBAK.NETWR y VBAP.NETWR/NETPR
  llegan como `STRING` desde Fivetran (no como tipo numérico nativo). Todos los staging models
  correspondientes usan `SAFE_CAST(... AS NUMERIC)` para convertirlos de forma segura (sin romper el
  build si llega un string vacío). Si el conector vuelve a cambiar el tipo de estas columnas, revisar
  primero `INFORMATION_SCHEMA.COLUMNS` antes de tocar el cast.
- **Ojo con `dbt show` para verificar magnitudes.** El renderizador CSV de `dbt show` (en este
  entorno dbt v2 Stable / Fusion 2.0.8) muestra mal las columnas `NUMERIC` que vienen de una
  expresión calculada (`CAST`/`SAFE_CAST`) — despliega el entero sin escalar en vez del decimal real.
  Para validar magnitudes de negocio, usar `execute_sql` (o la consola de BigQuery) en vez de
  `dbt show --inline`.
- **`gross_margin_proxy_amount`** es explícitamente un proxy, no una cifra contable: compara el valor
  neto de ventas contra el monto de órdenes de compra, sin considerar costos de producción, mano de
  obra ni otros gastos — no reemplaza un cálculo de margen bruto real (GAAP).
