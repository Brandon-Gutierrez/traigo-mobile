<!-- Se edita en tool/api-contract.template.md y se genera con
     `dart tool/build_contract.dart`. No editar docs/api-contract.md a mano. -->

# Contrato de la API · Traigo

Para quien programa el **backend Laravel**: todos los endpoints que necesitan la
app **Traigo Equipo** y la tienda web de Navidad, con sus datos, permisos y
reglas. Sale de los Excel de la campaña (precios, metas, KPI, bono y la hoja
«SISTEMA INTEGRADO») y de la base de datos nueva.

- **App** (secciones 4 a 11): la capa de datos ya está programada en Flutter y
  sus ejemplos JSON son los mismos que prueban las pruebas automáticas. Si el
  backend responde así, la app lo entiende.
- **Tienda web** (sección 12): propuesta; todavía no hay frontend que la pruebe.

## 0. Antes de empezar

### La base de datos

Está en el repositorio del backend, rama `feature/bd-segun-excel` (carpeta
`database/`): 16 migraciones para **PostgreSQL 13 o superior** y los datos de
arranque (62 productos, equipo, campaña de 7 semanas, 33 indicadores, sus metas
semanales, las 8 entregas de Sistemas y la configuración).

```powershell
composer install
copy .env.example .env      # completar DB_* y poner APP_LOCALE=es
php artisan key:generate
php artisan migrate --seed
```

Solo en una PC de desarrollo, para poder ingresar con el PIN `1234` como en la
demo de la app (necesita `APP_ENV=local`):

```powershell
php artisan db:seed --class=LocalPinSeeder
```

### Ajustes necesarios en el código (no se hicieron: solo se cambió `database/`)

1. **Zona horaria**: `config/app.php` → `'timezone' => 'America/La_Paz'`.
2. **Modelo `User`**: `$primaryKey = 'id_user'`, trait `HasUuids`,
   `$keyType = 'string'`, `$incrementing = false`, ocultar `password`,
   `pin_hash` y `remember_token`. Las demás tablas siguen el mismo estilo
   (`id_<tabla>` en UUID).
3. **Sanctum**: `php artisan install:api` y, **antes de migrar**, cambiar en la
   migración publicada `morphs('tokenable')` por `uuidMorphs('tokenable')`.
4. **Quién actúa**: un middleware que al empezar cada petición con sesión ejecute
   `select set_config('traigo.user_id', ?, false)` con el UUID de la persona y lo
   limpie al terminar. El historial (`audit_logs`) lo usa.
5. **Errores de la base**: la base rechaza lo que rompe una regla. Conviene
   revisar la regla antes y, si igual llega, traducir `23514` (check) y `23505`
   (único) a `409`/`422` con un mensaje en español. Los mensajes de los
   disparadores ya vienen en español.
6. **Archivos**: las tablas guardan `public_id` y `url` (Cloudinary, como el
   diseño original). Si se usa disco propio, devolver URLs firmadas.

## 1. Convenciones

| Tema | Regla |
|---|---|
| Base | `https://<dominio>/api/v1` (la app recibe el prefijo en `API_BASE_URL`) |
| Formato | JSON UTF-8. La app envía `Accept: application/json` y `Accept-Language: es` |
| Auth | `Authorization: Bearer <token>` en todo menos el ingreso y `/store/*` |
| Envoltorio | `{ "data": {...} }`; las listas paginadas agregan `"meta": { current_page, last_page, per_page, total }` |
| IDs | Texto (UUID). Los ejemplos usan ids cortos para que se lean mejor |
| Dinero | **Texto con 2 decimales y punto**: `"412.50"`. Nunca `number` |
| Tasas y pesos | Texto decimal: `"0.20"` = 20 % |
| % ya calculados | Entero redondeado **hacia abajo**: `83` |
| Fechas | `2026-12-06T11:09:00-04:00`; solo fecha: `2026-12-01` |
| «Hoy», «semana», «mes» | Días calendario de Bolivia (`America/La_Paz`) |
| Archivos | `multipart/form-data`, campo `file`; JPG, PNG o PDF, máx. 5 MB |
| Textos de error | En español y listos para mostrar |

**Idempotencia.** La app manda `Idempotency-Key: <uuid>` al crear ventas,
comprobantes, evidencias, entregas, cierres de caja, conteos y movimientos de
stock, y repite la misma clave al reintentar. Un middleware debe guardar la
respuesta por `(usuario, clave)` al menos 24 h y devolverla igual. Donde la tabla
tiene `client_uuid` (`orders`, `payments`, `kpi_evidence`, `stock_movements`),
guardar ahí la clave: es la segunda barrera contra duplicados.

### Errores

| HTTP | Cuándo | Cuerpo |
|---|---|---|
| 401 | Sin token, vencido o revocado. En el ingreso: código o PIN incorrectos | `{ "message" }` |
| 403 | El rol no puede hacer eso | `{ "message" }` |
| 404 | No existe **o no le corresponde a quien pregunta** | `{ "message" }` |
| 409 | Choca con el estado actual | `{ "message", "code", "data"? }` |
| 422 | Datos inválidos | `{ "message", "errors"?, "code"?, "data"? }` |
| 429 | Demasiados intentos | `{ "message" }` + `Retry-After` |
| 5xx | Falla del servidor | `{ "message" }` |

Un `401` fuera del ingreso hace que la app cierre la sesión. Sin internet o con
`5xx` **no** la cierra.

| `code` | HTTP | Significado |
|---|---|---|
| `two_factor_invalid`, `two_factor_expired` | 422 | Segundo paso |
| `price_changed` | 409 | El total calculado no es el que vio la persona (`data.total`) |
| `insufficient_stock` | 409 | No alcanza (`data.product_id`, `data.available`) |
| `product_unavailable` | 409 | Producto desactivado |
| `not_cancellable` | 409 | El pedido ya no se puede cancelar |
| `reference_duplicated` | 409 | La referencia del pago ya se usó |
| `already_reviewed` | 409 | Otra persona ya lo revisó |
| `own_record` | 409 | Nadie aprueba lo propio |
| `difference_needs_note` | 422 | La caja no cuadra y falta la explicación |
| `change_pending` | 409 | Ese producto ya tiene un cambio esperando a Dirección |
| `pending_members` | 409 | Al enviar o autorizar el bono queda alguien pendiente sin resolver |
| `not_pending` | 422 | Se intentó cerrar a mano a alguien que no está pendiente |
| `rates_pending` | 409 | Hay ventas sin % de comisión definido |
| `not_ready_to_pay` | 409 | Todavía no lo autorizó Dirección |
| `evidence_validated` | 409 | Jime ya validó ese indicador: no admite más evidencia |
| `deliverable_validated` | 409 | Jime ya validó esa entrega: no se vuelve a enviar |
| `week_closed` | 409 | La semana ya está autorizada o Jime cerró la de esa persona |

## 2. Roles y permisos

**La app solo oculta lo que no corresponde: el backend es quien debe negarlo.**

| `role` | Quién | Puede |
|---|---|---|
| `content` | Ailén | Lo del equipo |
| `warehouse` | Isaí | Lo del equipo + almacén (caja, despachos, stock) |
| `seller` | Alison | Lo del equipo + ventas |
| `wholesale` | Kim | Lo del equipo + ventas |
| `systems` | Sistemas 1 y 2 | Lo del equipo + sus entregas |
| `control` | Jime | `/control/*` (valida y propone; **no** autoriza pagos) |
| `management` | Dirección | `/management/*` y **leer** `/control/summary`, `bonus`, `compliance`, `commissions`, `audit`, `reports` y `products/{id}` |
| `customer` | Cliente web | Solo `/store/*` |

«Lo del equipo»: `/home`, `/team/week`, `/me/*` y leer `/catalog`.

- Cada persona ve **solo lo suyo** (sus ventas, su KPI, su comisión). Pedir algo
  ajeno responde `404`.
- El **costo** solo lo reciben `control` y `management`. La comisión de un
  producto, quienes venden, `control` y `management`.
- **Nadie aprueba lo propio** (la base también lo impide): Jime no confirma un
  comprobante que subió Jime, nadie carga su propio KPI ni valida su evidencia o
  su entrega, quien cierra la caja no la valida, quien pide un precio o envía un
  cierre no lo autoriza, y nadie autoriza su propio bono.

## 3. Índice de endpoints

| Método y ruta | Rol | Datos |
|---|---|---|
| `POST /auth/login` | todos | `users`, `two_factor_challenges` |
| `POST /auth/two-factor` | control, management | `two_factor_challenges` |
| `POST /auth/two-factor/resend` | control, management | `two_factor_challenges` |
| `POST /auth/logout` | con sesión | tokens |
| `GET /me` | con sesión | `users` |
| `GET /home` | equipo | vistas de bono y KPI |
| `GET /team/week` | equipo | `bonus_weeks`, `v_week_bonus` |
| `GET /me/week` | equipo | `kpi_weekly_results`, `kpi_evidence`, `system_deliverables` |
| `POST /me/kpi-results/{id}/evidence` | equipo (lo suyo) | `kpi_evidence` |
| `POST /me/deliverables/{id}/submission` | systems (lo suyo) | `system_deliverables` |
| `GET /catalog` | equipo | `products`, `inventory` |
| `GET /catalog/categories` | equipo | `categories` |
| `GET /catalog/{id}` | equipo | `products`, `product_images` |
| `GET /orders` | seller, wholesale | `orders` |
| `GET /orders/{id}` | seller, wholesale | `orders`, `order_items`, `payments`, `commissions` |
| `POST /orders` | seller, wholesale | idem + `inventory` |
| `POST /orders/{id}/cancel` | seller, wholesale | `orders`, `inventory` |
| `POST /orders/{id}/payment-proof` | seller, wholesale | `payments` |
| `GET /warehouse/dispatches` | warehouse | `orders` |
| `POST /warehouse/orders/{id}/ready` | warehouse | `orders` |
| `POST /warehouse/orders/{id}/delivered` | warehouse | `orders`, `inventory`, `stock_movements` |
| `GET /cash/today` | warehouse | `payments`, `cash_closings` |
| `POST /cash/closings` | warehouse | `cash_closings`, `cash_closing_lines` |
| `GET /inventory/counts` · `POST /inventory/counts` | warehouse | `inventory_counts` |
| `POST /inventory/movements` | warehouse | `stock_movements`, `inventory` |
| `GET /control/summary` | control, management | vistas |
| `GET /control/pending` | control | varias |
| `GET /control/payments/{id}` | control | `payments` |
| `POST /control/payments/{id}/confirm` · `POST /control/payments/{id}/reject` | control | `payments`, `orders`, `commissions` |
| `GET /control/kpi-results/{id}` | control | `kpi_weekly_results`, `kpi_evidence` |
| `POST /control/kpi-results/{id}/validate` · `POST /control/kpi-results/{id}/observe` | control | idem |
| `GET /control/cash-closings/{id}` | control | `cash_closings` |
| `POST /control/cash-closings/{id}/validate` · `POST /control/cash-closings/{id}/observe` | control | idem + `payments` |
| `GET /control/deliverables` | control | `system_deliverables` |
| `POST /control/deliverables/{id}/validate` · `POST /control/deliverables/{id}/reject` | control | idem |
| `POST /control/orders/{id}/return` | control | `orders`, `payments`, `commissions`, stock |
| `POST /control/orders/{id}/duplicate` | control | `orders` |
| `GET /control/compliance` | control, management | `v_member_week_compliance` |
| `GET /control/weekly-closing` · `POST /control/weekly-closing/{week}/send` | control | `weekly_closings` |
| `GET /control/bonus` | control, management | `v_week_member_bonus`, `weekly_member_results` |
| `POST /control/bonus/{week}/members/{member}/paid` | control | `weekly_member_results` |
| `GET /control/commissions` | control, management | `commissions` |
| `POST /control/commissions/{month}/send` · `POST /control/commissions/{month}/paid` | control | `commission_settlements` |
| `GET /control/products/{id}` | control, management | `products`, `price_change_requests` |
| `POST /control/products/{id}/price-changes` | control | `price_change_requests` |
| `GET /control/audit` | control, management | `audit_logs` |
| `GET /control/reports/{type}` | control, management | archivo Excel |
| `GET /control/system-status` | control | respaldos |
| `POST /control/members/{id}/pin` · `POST /control/members/{id}/revoke-sessions` | control | `users`, tokens |
| `GET /management/authorizations` | management | varias |
| `GET /management/authorizations/{type}/{id}` | management | varias |
| `POST /management/authorizations/{type}/{id}/approve` · `POST /management/authorizations/{type}/{id}/return` | management | varias |

## 4. Ingreso

`POST /auth/login` recibe `{ "code": "ALI-04", "pin": "1234", "device_name": "Traigo Equipo (android)" }`
(el código llega en mayúsculas). El equipo recibe el token:

{{loginResponse}}

Jime y Dirección reciben un segundo paso, **sin token todavía**:

{{secondStepResponse}}

- `401` con `"Código o PIN incorrectos."` si falla cualquiera de los dos o la
  cuenta está desactivada.
- `pin_hash` con bcrypt. **Obligatorio** limitar intentos (5 por minuto por
  código e IP) y bloquear con `failed_login_attempts` y `locked_until`.

`POST /auth/two-factor` recibe `{ "challenge_id", "code", "device_name" }`:

{{twoFactorResponse}}

Errores:

{{invalidSecondStepError}}

El código vence a los 5 minutos, sirve una vez, admite 5 intentos, se guarda
hasheado (`code_hash`) y **nunca** viaja en una respuesta.

`POST /auth/two-factor/resend` con `{ "challenge_id" }`: crea otro y anula el
anterior; antes de `resend_at`, `429`.

{{resendResponse}}

`POST /auth/logout`: revoca el token usado (`204`).
`GET /me`:

{{meResponse}}

## 5. Inicio, equipo y mi semana

**Semana en curso**: la de `bonus_weeks` que contiene la fecha de hoy en Bolivia.
Antes de la campaña, la primera; después, la última.

### `GET /home`

Solo datos de quien pregunta (`404` para `control` y `management`).

{{sellerHomeResponse}}

Almacén recibe además la caja del día y no recibe comisiones:

{{warehouseHomeResponse}}

Sistemas recibe sus entregas:

{{systemsHomeResponse}}

| Campo | De dónde sale |
|---|---|
| `collected` | `v_week_collected` |
| `fund_share_rate`, `kpi.minimum_percent` | `team_profiles` |
| `kpi.score_percent` | `v_kpi_member_week.partial_score_percent` (avance con lo cargado, nunca nulo), hacia abajo |
| `kpi.compliance` | `v_member_week_compliance.result` |
| `kpi.closed_reason` | `v_member_week_compliance.closed_reason`: motivo si Jime cerró a mano esa semana; si no, `null` |
| `kpi.indicators[].id` | `id_kpi_weekly_result` (con este id se sube evidencia) |
| `kpi.indicators[].evidence_status` | La evidencia más reciente; sin filas, `missing` |
| `kpi.deliverables` | `approved` = entregas `on_time`; solo Sistemas |
| `month_commission` | Suma de las comisiones `earned` y ajustes del mes. `pay_note` = ajuste `commission_pay_note` |
| `today_sales` | Ventas propias de hoy, la más nueva primero |
| `cash_today` | Resumen de `GET /cash/today` |

### `GET /team/week`

Los escalones salen de `bonus_tiers` (`sales_needed` redondeado hacia arriba).

{{teamWeekResponse}}

### `GET /me/week?week=1`

Sin `week`, la semana en curso. Con `week` también las anteriores (la app deja
revisarlas y subir evidencia mientras no se cierren); una semana que todavía no
empieza responde `404`. `score_percent` es `null` mientras falte cargar algún
indicador. `deliverables` solo para Sistemas en la semana que las pide.
`closed_reason` como en el Inicio. `accepts_evidence` es `false` cuando la
semana ya está autorizada o Jime cerró la de esta persona; entonces la app no
ofrece subir nada. Dentro de cada indicador, `evidence` va de lo más nuevo a lo
más antiguo.

{{myWeekResponse}}

`status` de una entrega: `pending` (sin enviar), `in_review` (enviada, sin
validar), `not_validated`, `on_time`, `late`. En la base, `result` es `pending`
mientras falte fecha real, evidencia o validación; con las tres es
`not_validated`, `on_time` o `late`.

### `POST /me/kpi-results/{id}/evidence`

`multipart`: `kind` (`photo`, `link` u `order`), `file` (foto JPG o PNG),
`url` (enlace `http` o `https`), `order_id` (pedido propio que no esté
cancelado, vencido ni devuelto; solo quienes venden) y `note` (opcional, hasta
500 caracteres). No se adjuntan otros archivos: un informe se sube como enlace o
foto (decisión del 24/11/2026).

- Solo el indicador propio; si no, `404`.
- Si Jime ya validó el indicador (la evidencia más reciente está `validated`),
  `409 evidence_validated`. Para que se pueda volver a subir, Jime la marca como
  observada.
- Si `accepts_evidence` es `false`, `409 week_closed`.
- La nueva queda `in_review` y ese pasa a ser el estado del indicador. Se pueden
  enviar varias mientras no esté validado.

`201`:

{{evidenceResponse}}

### `POST /me/deliverables/{id}/submission`

`multipart`: `delivered_on` (fecha real) y `file` (foto) o `url` (enlace). No
lleva nota: la base no la guarda y el Excel solo pide la evidencia o el enlace.

- La **fecha real la pone quien entrega** (la app propone hoy y deja elegir una
  anterior; no puede ser futura) y Jime la comprueba al validar. Con ella la base
  decide «a tiempo» o «fuera de plazo».
- Si ya está validada (`on_time` o `late`), `409 deliverable_validated`; si
  `accepts_evidence` es `false`, `409 week_closed`.
- Mientras no esté validada se puede reenviar y **reemplaza** lo anterior: queda
  sin validar (`jime_validated`, `validated_by`, `validated_at` y `review_note`
  en nulo), o sea `in_review`.

{{deliverableResponse}}

## 6. Catálogo y ventas

### `GET /catalog?search=&category=&page=`

Productos activos, por nombre, 30 por página. `search` busca en nombre y código
(sin distinguir mayúsculas ni tildes). `category` es el id de la categoría.

{{catalogResponse}}

`available = stock − reserved`. `commission_pct: null` = **por definir** (la app
muestra «[% por definir]»). El costo no viaja nunca aquí.

`GET /catalog/categories`:

{{categoriesResponse}}

`GET /catalog/{id}` agrega descripción e imágenes:

{{catalogDetailResponse}}

### `GET /orders?status=&page=`

Solo las ventas propias, la más nueva primero, 20 por página. `status`:
`pending_payment`, `payment_review`, `paid` (**incluye `ready`**) o `delivered`;
sin `status`, todas.

{{ordersResponse}}

### `GET /orders/{id}`

{{orderDetailResponse}}

`lines[]` guarda la copia de la venta; `category` e `image_url` son las del
producto hoy (solo para mostrarlo).

`can_cancel`: solo en `pending_payment` o `payment_review`. `can_upload_proof`:
pago `qr` o `transfer` en `pending_payment` o `payment_review` (en revisión, subir
otro **reemplaza** al anterior; la app lo muestra como «Cambiar»). Si Jime
rechazó el comprobante, `payment.status = rejected` y `reject_reason` dice por
qué. La línea de tiempo sale de `created_at`, `paid_at`, `ready_at` y
`delivered_at`.

### `POST /orders` (con `Idempotency-Key`)

La app manda productos y cantidades; **no manda precios**. `expected_total` es lo
que vio la persona.

{{newSaleRequest}}

`origin`: `in_person`, `whatsapp` o `wholesale` (la web usa `/store/orders`).
`201` con el detalle. En **una sola transacción**:

1. Bloquear el inventario de cada producto (`FOR UPDATE`).
2. Calcular precios con la regla 13.4 y comparar con `expected_total`:

{{priceChangedError}}

3. Revisar `available`:

{{insufficientStockError}}

4. Crear `orders` (`seller_id` = quien registra) y `order_items`, **copiando**
   código, nombre, precios, costo y `commission_pct` del momento.
5. Sumar a `inventory.reserved` y guardar `order_status_history`.
6. Crear una fila de `commissions` por línea (`pending`; sin %, `rate_pct` y
   `amount_bs` nulos).
7. Si es en efectivo, crear el `payments` en `submitted`: se confirma al validar
   el cierre de caja.

### `POST /orders/{id}/cancel` con `{ "reason"? }`

Libera la reserva, anula las comisiones, rechaza el comprobante pendiente y
deja `cancelled`. `409 not_cancellable` si ya está pagado.

### `POST /orders/{id}/payment-proof`

`multipart`: `file` y `reference`. Crea o reemplaza el `payments` en `submitted`
por el total y pasa el pedido a `payment_review`. Referencia repetida:
`409 reference_duplicated` (la base lo garantiza). Devuelve el detalle.

## 7. Almacén (rol `warehouse`)

### Despachos

`GET /warehouse/dispatches`: pedidos `paid` o `ready`, primero los que tienen la
hora acordada más cercana. `is_late` = ya pasó `promised_at` (sirve para el KPI
«Despachos dentro de plazo»).

{{dispatchesResponse}}

- `POST /warehouse/orders/{id}/ready`: `paid` → `ready` (`204`).
- `POST /warehouse/orders/{id}/delivered`: → `delivered`; guarda
  `dispatched_at` y `delivered_at`, **resta** de `stock` y de `reserved`, y crea
  un movimiento `sale` negativo por producto (en combos, por cada componente).

### Caja del día

`GET /cash/today`: lo cobrado hoy por forma de pago (`expected` = pagos
`submitted` o `confirmed` del día), lo contado si ya se cerró y los pedidos por
cobrar.

{{cashDayResponse}}

`POST /cash/closings` (la diferencia la calcula la base):

{{cashClosingRequest}}

Si algo no cuadra y no hay `note`: `422 difference_needs_note`. Queda `sent` y
los pagos incluidos se ligan al cierre (`payments.cash_closing_id`). Si Jime lo
observó, el mismo día se vuelve a enviar (hay un cierre por fecha). Responde con
el formato de `GET /cash/today`.

### Stock y conteos

`POST /inventory/movements`: entradas y ajustes. `type`: `initial`, `purchase`,
`adjustment_in` (cantidad positiva) o `adjustment_out` (**negativa**). El stock
empieza en 0: la primera carga es con `initial`. `409` si el stock quedaría por
debajo de lo reservado.

{{stockEntryRequest}}

{{stockLevelResponse}}

`POST /inventory/counts`: el servidor guarda lo que decía el sistema en ese
momento (`system_qty`). **El conteo no cambia el stock**; se corrige con un
ajuste. `GET /inventory/counts` devuelve la lista.

{{inventoryCountRequest}}

{{inventoryCountResponse}}

## 8. Panel de Jime: resumen y bandeja

### `GET /control/summary`

{{controlSummaryResponse}}

`members[].score_percent` es el avance con lo cargado. `pending` cuenta pagos
`submitted`, indicadores con evidencia `in_review`, cierres `sent` y entregas en
revisión. `bonus` sale de `v_week_bonus` y `v_week_member_bonus`.

### `GET /control/pending?type=`

`type`: `payment`, `evidence`, `cash_closing`, `deliverable`. **El más antiguo
primero.** `id` es el del pago, del indicador semanal, del cierre o de la entrega.

{{pendingResponse}}

### Pagos (conciliación)

`GET /control/payments/{id}`. `reference_unique` lo calcula el servidor.

{{paymentReviewResponse}}

`POST /control/payments/{id}/confirm`:

{{confirmPaymentRequest}}

Con `amount_matches` o `destination_ok` en falso: `422` (se debe rechazar). En una
transacción: pago `confirmed` (`reviewed_by`, `reviewed_at`; `received_at` = el
indicado o `submitted_at`), pedido `paid` con `paid_at`, y sus comisiones pasan a
`earned`. Responde con el pago.

`POST /control/payments/{id}/reject` con `{ "reason" }`: pago `rejected` y el
pedido vuelve a `pending_payment`.

### Evidencia y valores reales

`GET /control/kpi-results/{id}`:

{{evidenceReviewResponse}}

- `POST /control/kpi-results/{id}/validate` con `{ "actual", "note"? }`: carga el
  valor real (`loaded_by` = Jime) y valida la evidencia en revisión. Sirve también
  para indicadores sin evidencia pendiente.
- `POST /control/kpi-results/{id}/observe` con `{ "note" }`: la evidencia en
  revisión pasa a `observed`.

Ambos responden con el formato del `GET`.

### Cierres de caja y entregas

- `GET /control/cash-closings/{id}`: formato de la caja del día.
- `POST /control/cash-closings/{id}/validate`: `validated`; los pagos **en
  efectivo** ligados al cierre quedan `confirmed` (como al confirmar un pago).
- `POST /control/cash-closings/{id}/observe` con `{ "note" }`.
- `GET /control/deliverables`: las 8 entregas (lista con el formato de la sección 5).
- `POST /control/deliverables/{id}/validate` con `{ "delivered_on" }`.
- `POST /control/deliverables/{id}/reject` con `{ "note" }`: `jime_validated = false`.

### Devoluciones y duplicados

`POST /control/orders/{id}/return` (`204`):

{{returnOrderRequest}}

Pedido `returned`; pago `reversed` (deja de contar para el bono); comisión
`earned` → una fila `adjustment` con base negativa en el mes actual, comisión
`pending` → `cancelled`; si ya se entregó, movimiento `sale_return` y vuelve al
stock; si no, se libera la reserva.

`POST /control/orders/{id}/duplicate` (`204`): se anula este pedido
(`cancel_reason = 'duplicate'`, `duplicate_of_id`), se libera la reserva y se
anulan sus comisiones y pagos pendientes.

{{duplicateOrderRequest}}

## 9. Cumplimiento, cierre semanal, bono y comisiones

### `GET /control/compliance?week=`

De `v_member_week_compliance`:

{{complianceResponse}}

### Cierre semanal

`GET /control/weekly-closing?week=`: los 4 controles del Excel, calculados y
redactados. `pending_members` lista a quienes siguen pendientes y qué les falta.

{{weeklyClosingResponse}}

`POST /control/weekly-closing/{week}/send` (`{week}` = número de semana).
`close_pending` cierra como **«no cumple»** a quienes sigan pendientes, con un
motivo obligatorio por persona (puede ir vacío):

{{sendClosingRequest}}

En **una sola transacción**:

1. Con algún control en falso, `422`.
2. Borrar las filas de `weekly_member_results` de la semana (si se está
   reenviando; los cierres a mano se indican otra vez en cada envío). Así las
   vistas vuelven a calcular desde los datos cargados.
3. Cada `close_pending` debe estar pendiente: si no, `422 not_pending`.
4. Si queda alguien pendiente que no esté en `close_pending`,
   `409 pending_members` (el mensaje dice quién).
5. Guardar la foto en `weekly_closings` (cobrado, %, escalón, premio base, factor
   y fondo desde `v_week_bonus`) y una fila por integrante en
   `weekly_member_results` desde `v_week_member_bonus` (monto 0 si no cumple).
   A quienes se cierran: `result = 'fails'`, monto 0, `closed_by` = Jime,
   `closed_at` y `close_reason`.
6. Estado `sent`.

La parte de quien se cierra a mano **no se reparte**, igual que la de cualquiera
que no cumple. Dirección ve el motivo antes de autorizar.

La base solo permite el cierre a mano a Jime (`control`), a quien según los datos
esté pendiente y con motivo. Además **impide autorizar** si falta algún control,
si alguno de los 6 sigue pendiente, si el reparto no suma 100 %, si se pagaría
más que el fondo o si no autoriza Dirección. Después de autorizar, solo se puede
marcar el pago.

### Bono

`GET /control/bonus?week=`: antes de enviar, la vista previa de las vistas;
después, la foto guardada. `amount: null` = pendiente. La parte de quien no
cumple **no se reparte**. `closed_reason` = motivo del cierre a mano.
`GET /control/compliance` y las notas de `/control/summary` también lo muestran.

{{bonusResponse}}

`POST /control/bonus/{week}/members/{member}/paid`: solo con el cierre
autorizado (`409 not_ready_to_pay`). Cuando se pagó a todos, el cierre pasa a
`paid`.

### Comisiones

`GET /control/commissions?month=2026-12`: comisiones cobradas en el mes
(`earned_at`) con sus ajustes. Si alguna no tiene %, `rates_pending: true` y los
montos pueden ser `null`.

{{commissionsResponse}}

- `POST /control/commissions/{month}/send`: crea o actualiza la liquidación del
  mes, liga las comisiones `earned` y la manda a Dirección. Con % pendientes,
  `409 rates_pending`.
- `POST /control/commissions/{month}/paid`: solo si está autorizada.

## 10. «Más»: precios, historial, reportes y accesos

`GET /control/products/{id}`:

{{priceSheetResponse}}

`POST /control/products/{id}/price-changes`: **solo los valores que cambian**.
Guarda `previous_values`; un solo cambio pendiente por producto
(`409 change_pending`). Las ventas ya registradas no cambian.

{{priceChangeRequest}}

`GET /control/audit?page=`: de `audit_logs`, con cada cambio redactado en español
(no se puede editar ni borrar):

{{auditResponse}}

`GET /control/reports/{type}?period=`: devuelve el **.xlsx** (el archivo, no
JSON). `week` (número de semana: KPI, bono, cierre y pagos), `cash` (fecha: caja
por método con diferencias) y `commissions` (mes: por persona y producto).

`GET /control/system-status`:

{{systemStatusResponse}}

- `POST /control/members/{id}/pin` con `{ "pin": "4821" }`: guarda el hash,
  desbloquea la cuenta y borra sus tokens (`204`).
- `POST /control/members/{id}/revoke-sessions`: borra sus tokens (`204`).

## 11. Dirección

`GET /management/authorizations`: lo que está esperando (cierres `sent`,
liquidaciones `sent`, cambios de precio y promociones `pending`).
`id`: número de semana, mes `2026-12`, o el UUID del cambio o la promoción.

{{authorizationsResponse}}

`GET /management/authorizations/{type}/{id}` (`type`: `weekly_bonus`,
`commissions`, `price_change`, `promotion`):

{{authorizationDetailResponse}}

En el bono, a quien Jime cerró a mano va en `unpaid` con el motivo («Cerrado por
Jime: …»).

`POST /management/authorizations/{type}/{id}/approve` (`204`):

| `type` | Efecto |
|---|---|
| `weekly_bonus` | `weekly_closings` → `authorized`, `direction_approved`, `authorized_by/at`. Si la base lo impide: `409 pending_members` con su mensaje |
| `commissions` | Liquidación → `authorized` |
| `price_change` | `approved` y **en la misma transacción** se aplica al producto |
| `promotion` | `approved` |

`POST /management/authorizations/{type}/{id}/return` con `{ "reason" }` (`204`):
cierre o liquidación → `returned`; precio o promoción → `rejected` con la nota.

## 12. Tienda web de Navidad (sin sesión) — propuesta

Ajustes públicos: filas de `settings` con `is_public`. Limitar peticiones por IP
en todo lo que escribe.

| Método y ruta | Para qué |
|---|---|
| `GET /store/config` | WhatsApp, TikTok, punto de recojo, QR de pago, horas de reserva y fechas límite |
| `GET /store/categories` | Categorías con cantidad y precio «desde» |
| `GET /store/products?category=&min_price=&max_price=&search=&sort=price_asc&page=` | Catálogo (sin costo ni comisión; `available` solo como disponible/agotado) |
| `GET /store/products/{slug}` | Ficha, precio por mayor y productos relacionados |
| `GET /store/offers/calendar` | 24 puertas: `[{ day, state: "past"/"today"/"locked", offer }]`. **No revelar** ofertas futuras |
| `GET /store/gifts?max_price=60&audience=kids` | Buscador de regalos (`kids`, `home`, `school_sport`) |
| `POST /store/cart/quote` | `{ lines: [{ product_id, quantity }] }` → precios, totales y cuánto falta para el precio por mayor |
| `POST /store/orders` (con `Idempotency-Key`) | `{ customer: { name, phone }, delivery: { type, address }, payment_method: "qr"/"card", lines, expected_total }` → `{ number, token, total, expires_at, payment: { qr_url } o { checkout_url } }` |
| `GET /store/orders/{number}?token=` | Estado del pedido. Sin el `public_token` correcto: `404` |
| `POST /store/orders/{number}/payment-proof?token=` | Subir comprobante del QR |
| `POST /store/payments/gateway/webhook` | La pasarela avisa el cobro con tarjeta: **verificar la firma**, guardar `gateway_provider` y `gateway_transaction_id` y confirmar |
| `POST /store/quotes` | `{ name, phone, message }` → «Pide tu cotización» (responde Kim) |

Un pedido web: `origin = web`, sin vendedor (sin comisión), reserva el stock por
`order_reservation_hours` (hoy 2) y guarda `expires_at`. Los precios y las
ofertas los calcula el servidor. **Nunca** se reciben ni guardan datos de tarjeta.

## 13. Reglas de negocio

La base ya tiene vistas que repiten las fórmulas del Excel; conviene leer de
ellas en vez de reescribirlas. Se comprobó que, con los datos de la primera
semana de la demo, dan los mismos números que la app.

### 13.1 Bono semanal (`v_week_collected`, `v_week_bonus`, `v_week_member_bonus`)

- Cuenta lo **cobrado y confirmado** (no devuelto) según el día de Bolivia en que
  llegó el dinero (`payments.received_at`).
- 90 % de la meta libera 50 % del premio base; 100 %, 100 %; 115 %, 125 %.
- Reparto 20/20/20/20/10/10; cada quien cobra solo si cumple su KPI.
- Lo no ganado no se redistribuye.
- Para pagar, nadie puede quedar pendiente: al cerrar la semana, Jime resuelve
  sus datos o lo cierra como «no cumple» con un motivo (sección 9).

### 13.2 KPI (`v_kpi_member_week`, `v_member_week_compliance`)

- Avance = `actual / target` con **tope de 100 %**; puntaje = suma por peso.
- Falta algún `actual` → `pending`. Mínimo 90 % (Alison 80 %); 89,9 no llega.
- Metas de cantidad reducidas en la primera (×0,9) y última semana (×0,7),
  redondeadas hacia arriba; ya vienen generadas en `kpi_weekly_results`.

### 13.3 Entregas de Sistemas

Solo la primera semana: cada ingeniero necesita sus **4 entregas a tiempo** y
validadas, además de su KPI. Alguna sin resolver → `pending`; alguna tarde o no
validada → `fails`.

### 13.4 Precios

Cada producto va a precio por mayor cuando la línea llega a su cantidad mínima
(`wholesale_min_qty` unidades del **mismo código**); si no, va por unidad. Las
unidades de distintos productos no se suman y **no hay monto mínimo de pedido**
(decisión del 24/11/2026; el Excel proponía Bs 1.000). Referencia con sus
pruebas: `lib/features/catalog/domain/pricing.dart` y
`test/features/catalog/pricing_test.dart`.

Promociones: se publican solo autorizadas; una por puerta; **ninguna baja del
precio por mayor** (lo valida el backend al crear y al vender).

> Las pantallas para **crear** promociones, productos, imágenes y combos no
> están en los mockups de la app. Hará falta un panel web o agregarlas.

### 13.5 Comisiones

Una persona por venta, con la tasa **de cada producto** al momento de vender.
`pending` → `earned` al cobrar; devolución de algo cobrado = `adjustment`
negativo. Se liquida por mes; es independiente del bono.

### 13.6 Estados del pedido e inventario

```
pending_payment → payment_review → paid → ready → delivered
       │                │           └───────┴──────────→ returned
       ├────────────────┴→ cancelled
       └→ expired (web sin pagar a tiempo)
```

| Momento | Inventario |
|---|---|
| Se registra el pedido | `reserved += cantidad` |
| Se cancela, vence o es duplicado | `reserved -= cantidad` |
| Se entrega | `stock -= cantidad`, `reserved -= cantidad`, movimiento `sale` |
| Se devuelve algo entregado | movimiento `sale_return`, `stock += cantidad` |

El stock se cambia siempre junto a su movimiento y en la misma transacción.

## 14. La base de datos

| Área | Tablas |
|---|---|
| Cuentas | `users`, `team_profiles`, `two_factor_challenges`, `sessions`, `password_reset_tokens` |
| Catálogo | `categories`, `products`, `product_attributes`, `product_images`, `price_change_requests`, `promotions`, `promotion_products`, `combos`, `combo_items`, `combo_images` |
| Ventas | `orders`, `order_items`, `order_status_history`, `payments`, `quote_requests` |
| Almacén | `inventory`, `inventory_counts`, `inventory_count_items`, `stock_movements`, `cash_closings`, `cash_closing_lines` |
| Comisiones | `commissions`, `commission_settlements` |
| KPI y bono | `bonus_weeks`, `bonus_tiers`, `kpi_indicators`, `kpi_weekly_results`, `kpi_evidence`, `system_deliverables`, `weekly_closings`, `weekly_member_results` |
| Otros | `settings`, `audit_logs`, `cache`, `jobs` y las demás de Laravel |

Los valores de los ENUM son los mismos que viajan en la API.

**La base ya impide**, además de las claves y montos válidos: aprobar lo propio;
vender sin vendedor (salvo la web); confirmar un cobro sin respaldo; repetir una
referencia de pago; pagar comisión a quien no vendió o dos veces la misma línea;
liquidar comisiones sin %; reservar más que el stock; autorizar el bono sin
cumplir «LISTO PARA PAGO» o cambiarlo después; cerrar a mano a alguien que no
está pendiente, sin motivo o si no es Jime; semanas superpuestas; y editar o
borrar el historial y el kardex. El historial de cambios de precios, cobros,
inventario, comisiones, KPI, entregas y cierres lo escribe **la propia base**.

**Datos del negocio que faltan** (filas de `settings` en `null`):
`payment_qr_url`, `store_whatsapp`, `pickup_address`, `delivery_fee_note`,
`christmas_order_deadline`, `same_day_cutoff_time` y `commission_pay_note`.
También el stock inicial, los PIN, el % de comisión y el costo de cada producto,
las imágenes y la audiencia de regalo (`gift_audience`).

## 15. Tareas programadas

| Cada | Qué |
|---|---|
| 5 minutos | Pedidos web `pending_payment` con `expires_at` vencido → `expired` y liberar la reserva |
| Día | Borrar `two_factor_challenges` vencidos |
| Día | Respaldo de la base (cifrado si sale del servidor) y, cada cierto tiempo, **probar la restauración** (el Excel lo exige) |

## 16. Seguridad

- HTTPS siempre. CORS de `/store/*` solo para el dominio de la tienda.
- Políticas por rol en cada ruta (sección 2) y pruebas con intentos prohibidos
  (el Excel pide probar el acceso de 3 roles).
- PIN y códigos hasheados; límites y bloqueo; tokens revocables.
- Archivos: validar tipo y tamaño, nombres generados y URLs no adivinables.
- Segundo paso obligatorio para `control` y `management`.

## 17. Decisiones que faltan

| Tema | Hoy | Falta decidir |
|---|---|---|
| Mínimos por producto | Los del Excel (24, 12, 6 y 3 unidades) | Confirmarlos: el Excel los llama «propuesta comercial» |
| Código del segundo paso | `channel` libre | ¿WhatsApp, SMS, correo o app autenticadora? |
| % de comisión y fecha de pago | `null` | Definirlos |
| Comisión de ventas web | Sin vendedor, sin comisión | Si alguien debe cobrarlas |
| Cobros en efectivo | Se confirman al validar la caja | Confirmar |
| Hora acordada de despacho | Campo `promised_dispatch_at` | Quién la define y cuál es el plazo normal |
| Envío y pasarela | `shipping_bs` nulo; `gateway_provider` libre | Costo del delivery y proveedor de tarjeta |
| Códigos del equipo | `JIM-01` … `DIR-08` (propuesta) | Confirmarlos antes de entregar los PIN |
