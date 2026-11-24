# Contrato de la API · Traigo Vendedores

Lo que la app móvil necesita del backend (Laravel). Está pensado para entregarse
tal cual a quien construya la API. Cada ejemplo JSON de este documento está
**verificado por pruebas automáticas** de la app (`test/fixtures/api_samples.dart`
y `test/data/api_repositories_test.dart`): si el backend responde así, la app lo
entiende.

La app corre hoy contra un servidor de prueba en memoria. Para cambiar al real
no hay que tocar pantallas:

```powershell
flutter run --dart-define=API_MODE=live --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

## 1. Convenciones

| Tema | Regla |
|---|---|
| Base | `https://<dominio>/api/v1` (la app recibe el prefijo en `API_BASE_URL`) |
| Formato | JSON UTF-8. Peticiones con `Accept: application/json` y `Accept-Language: es` |
| Auth | `Authorization: Bearer <token>` en todo menos `POST /auth/login` |
| Envoltorio | Un objeto viaja en `{ "data": {...} }`; una lista paginada en `{ "data": [...], "meta": {...} }` (el de los API Resources de Laravel) |
| IDs | Siempre **texto**: `"131"`, aunque en la base sean enteros |
| Dinero | **Texto con 2 decimales y punto**: `"120.00"`, `"86.40"`. Nunca `number` |
| Fechas | ISO-8601 con zona: `2026-11-23T11:20:00-04:00` (Bolivia es UTC−4, sin horario de verano) |
| «Hoy» | Día calendario en `America/La_Paz`, no en UTC |
| Paginación | `?page=1` (desde 1). `meta`: `current_page`, `last_page`, `per_page`, `total` |
| Moneda | Bolivianos (Bs). No hay otra |
| Textos de error | En español, listos para mostrarse al vendedor |

### Errores

| HTTP | Cuándo | Cuerpo |
|---|---|---|
| 401 | Token faltante, vencido o revocado. En `/auth/login`: código o PIN incorrectos | `{ "message": "..." }` |
| 404 | Recurso inexistente **o de otro vendedor** | `{ "message": "..." }` |
| 409 | La operación choca con el estado actual | `{ "message", "code", "data"? }` |
| 422 | Datos inválidos | `{ "message", "errors": { "campo": ["..."] }, "code"?, "data"? }` |
| 429 | Demasiados intentos | `{ "message" }` + cabecera `Retry-After` (segundos) |
| 5xx | Falla del servidor | `{ "message" }` |

Los campos de `errors` usan notación de punto (`lines.0.unit_price`,
`customer.name`, `delivery.address`), como entrega Laravel por defecto.

**Códigos de negocio** (campo `code`, la app reacciona a ellos):

| `code` | HTTP | Significado |
|---|---|---|
| `price_below_minimum` | 422 | Un precio de venta es menor al mínimo vigente |
| `insufficient_stock` | 409 | No hay unidades suficientes |
| `item_unavailable` | 409 | El producto o combo fue desactivado |
| `not_cancellable` | 409 | El pedido ya no se puede cancelar |
| `idempotency_conflict` | 409 | Misma `Idempotency-Key` con un cuerpo distinto |

### Idempotencia (ventas y mermas)

`POST /orders` y `POST /waste` llevan `Idempotency-Key: <uuid>`. La app genera el
UUID al abrir el formulario y lo reutiliza si el vendedor reintenta tras un
corte de red. El servidor debe **devolver el mismo resultado** y no duplicar
la venta ni descontar stock dos veces. Guardar `(seller_id, key, hash del cuerpo,
respuesta)` unas 24 horas.

### Archivos

Subidas `multipart/form-data`. Imágenes JPG o PNG, máx. 5 MB (la app las
comprime antes). Las URLs de imágenes que devuelve la API deben poder abrirse
con el token del vendedor o ser URLs firmadas temporales.

## 2. Resumen de endpoints

| # | Método y ruta | Para qué | Fase |
|---|---|---|---|
| 1 | `POST /auth/login` | Ingresar con código + PIN | 1 |
| 2 | `POST /auth/logout` | Revocar el token actual | 1 |
| 3 | `GET /me` | Recuperar la sesión al abrir la app | 1 |
| 4 | `GET /home` | Comisión de hoy y del mes, fondo, últimas ventas | 1 |
| 5 | `GET /catalog` | Productos y combos con stock y mínimo | 2 |
| 6 | `GET /catalog/categories` | Pestañas de categoría | 2 |
| 7 | `GET /catalog/{kind}/{id}` | Un ítem actualizado antes de vender | 2 |
| 8 | `POST /orders` | Registrar una venta | 2 |
| 9 | `GET /orders` | Mis pedidos (filtro por estado) | 3 |
| 10 | `GET /orders/{id}` | Detalle de un pedido | 3 |
| 11 | `POST /orders/{id}/cancel` | Cancelar mientras esté por confirmar | 3 |
| 12 | `POST /orders/{id}/payment-proof` | Subir foto del comprobante QR | 3 |
| 13 | `GET /stock/summary` | Contadores y «poco stock» | 4 |
| 14 | `GET /stock/movements` | Movimientos de bodega del día | 4 |
| 15 | `POST /waste` | Registrar una merma | 4 |
| 16 | `GET /waste` | Mis mermas y su estado | 4 |

La columna **Fase** sirve para construir el backend en paralelo: la Fase 1 de la
app solo necesita los endpoints 1 al 4.

---

## 3. Autenticación

### 1 · `POST /auth/login`

El PIN de 4 dígitos solo no identifica a nadie, por eso se pide el **código de
vendedor** (`ANA-07`). Sin ese código no hay forma de saber de quién es el PIN.

```json
{ "code": "ANA-07", "pin": "1234", "device_name": "Traigo Vendedores (android)" }
```

`200`:

```json
{
  "data": {
    "token": "1|k9sPq3",
    "seller": { "id": "1", "code": "ANA-07", "name": "Ana López" },
    "rules": { "personal_rate": "0.40", "fund_rate": "0.25" }
  }
}
```

- `rules`: porcentajes vigentes de la **ganancia de cada venta**. La app los usa
  solo para la vista previa; el monto real siempre lo calcula el servidor.
- `401` si el código no existe, el PIN no coincide o la cuenta está desactivada
  (mensaje distinto para cada caso, sin revelar cuál campo falló).
- `429` con `Retry-After` al exceder intentos (sugerido: 5 por minuto por código
  e IP). Un PIN de 4 números se adivina rápido: **limitar y bloquear** es
  obligatorio, y guardarlo hasheado.
- Sanctum: `createToken($device_name)`. La sesión **no vence sola**; termina con
  `logout` o cuando el admin revoca el token.

### 2 · `POST /auth/logout`

Sin cuerpo. Revoca el token usado. `204`. La app borra el token aunque este
llamado falle.

### 3 · `GET /me`

```json
{
  "data": {
    "seller": { "id": "1", "code": "ANA-07", "name": "Ana López" },
    "rules": { "personal_rate": "0.40", "fund_rate": "0.25" }
  }
}
```

`401` ⇒ la app cierra la sesión. Cualquier otro error (sin internet, 5xx) **no**
la cierra: reintenta.

---

## 4. Inicio

### 4 · `GET /home`

```json
{
  "data": {
    "today": { "commission": "86.40", "sales_count": 5, "sold_total": "1080.00" },
    "month": {
      "personal_commission": "1340.00",
      "fund_share": "643.33",
      "estimated_total": "1983.33"
    },
    "fund": { "current": "3860.00", "goal": "5000.00", "prize_label": null },
    "payout_note": null,
    "recent_orders": [ { "...": "mismo formato que un elemento de GET /orders" } ]
  }
}
```

Cómo se calcula (para que la pantalla cuadre con el panel admin):

| Campo | Regla |
|---|---|
| `today.commission` | Suma de la comisión personal de los pedidos del vendedor creados hoy, **sin contar los cancelados ni devueltos** |
| `today.sales_count` / `sold_total` | Cantidad y total de esos mismos pedidos |
| `month.personal_commission` | Igual, del 1.º del mes a hoy |
| `month.fund_share` | `fund.current` ÷ número de vendedores activos |
| `month.estimated_total` | `personal_commission + fund_share` |
| `fund.current` | Suma del aporte al fondo (25 % de la ganancia) de todos los pedidos del equipo en el mes, sin cancelados ni devueltos |
| `fund.goal` | Meta del hito, configurable por el admin |
| `fund.prize_label` | Premio del hito. `null` mientras el dueño no lo defina |
| `payout_note` | Texto de cómo/cuándo se pagan comisiones. `null` = **todavía por definir** (la app muestra «Pago de comisiones: por definir») |
| `recent_orders` | Los últimos 3 pedidos del vendedor, no cancelados |

---

## 5. Catálogo

### 5 · `GET /catalog`

Query: `search` (nombre o código), `category`, `kind` (`product` o `combo`),
`page`, `per_page` (la app pide 30). Solo ítems activos. Orden: nombre.

```json
{
  "data": [
    {
      "id": "1", "kind": "product", "code": "TR-0151",
      "name": "Audífonos bluetooth ANC con estuche", "category": "Audio",
      "image_url": null,
      "suggested_price": "120.00", "min_price": "90.00",
      "stock": 34, "low_stock_alert": 10,
      "components": []
    },
    {
      "id": "1", "kind": "combo", "code": "CMB-01",
      "name": "Combo Escritorio Pro", "category": "Combos",
      "image_url": null,
      "suggested_price": "199.00", "min_price": "191.00",
      "stock": 12, "low_stock_alert": 5,
      "components": [
        { "name": "Lámpara luna LED recargable", "quantity": 1 },
        { "name": "Audífonos bluetooth ANC con estuche", "quantity": 1 },
        { "name": "Organizador plegable multiuso", "quantity": 1 }
      ]
    }
  ],
  "meta": { "current_page": 1, "last_page": 5, "per_page": 30, "total": 124 }
}
```

Reglas importantes:

- `id` **no es único entre tipos**: el producto `1` y el combo `1` coexisten. La
  clave real es `(kind, id)`.
- `suggested_price`: precio normal de la tienda; con él parte la venta.
- `min_price`: **piso para el vendedor, con el descuento de temporada ya
  aplicado** (si hoy rige un «mínimo de temporada −12 %», aquí viaja el valor
  rebajado). La app nunca calcula temporadas.
- `stock`: unidades en bodega central. En un combo, cuántos **combos completos**
  se pueden armar (el menor de `stock ÷ cantidad` de sus componentes).
- `low_stock_alert`: desde cuántas unidades se marca «poco stock».
- Combo: `min_price` es el mínimo propio del combo (la suma de los mínimos de sus
  productos).

### 6 · `GET /catalog/categories`

```json
{ "data": ["Audio", "Hogar", "Cocina", "Bienestar", "Combos"] }
```

### 7 · `GET /catalog/{kind}/{id}`

`kind` = `products` o `combos`. Devuelve `{ "data": <ítem> }` con el mismo formato.
La app lo pide justo antes de confirmar una venta, para validar mínimo y stock
actuales. `404` si no existe o está desactivado.

---

## 6. Pedidos (ventas del vendedor)

### 8 · `POST /orders`

Cabecera `Idempotency-Key: <uuid>`.

```json
{
  "lines": [
    { "kind": "product", "item_id": "1", "quantity": 1, "unit_price": "120.00" }
  ],
  "customer": { "name": "Mariela Quispe", "whatsapp": "71234567" },
  "payment_method": "qr",
  "delivery": { "type": "delivery", "address": "Av. Blanco Galindo km 4", "city": null }
}
```

| Campo | Regla |
|---|---|
| `lines` | Al menos 1. `kind`: `product` o `combo`. `quantity` ≥ 1. `unit_price` = precio al que vendió |
| `customer.name`, `customer.whatsapp` | Obligatorios |
| `payment_method` | `qr` o `cash` |
| `delivery.type` | `handoff` (en mano/encuentro), `delivery` (Cochabamba), `other_city`, `pickup` (recojo) |
| `delivery.address` | Obligatoria si `type = delivery` |
| `delivery.city` | Obligatoria si `type = other_city` |

`201` con el **detalle del pedido** (ver §6.10). Lo que el servidor debe hacer, de
forma atómica (transacción con `lockForUpdate` sobre el stock):

1. Validar `unit_price ≥ min_price` **vigente** de cada línea ⇒ si no, `422`:
   ```json
   {
     "message": "No puedes vender Audífonos bluetooth ANC con estuche por debajo de Bs 90.",
     "code": "price_below_minimum",
     "errors": { "lines.0.unit_price": ["El precio mínimo es Bs 90."] },
     "data": { "kind": "product", "item_id": "1", "min_price": "90.00" }
   }
   ```
2. Validar stock (un combo consume sus componentes) ⇒ si no alcanza, `409`:
   ```json
   {
     "message": "Solo quedan 3 de Termo digital 500 ml.",
     "code": "insufficient_stock",
     "data": { "kind": "product", "item_id": "3", "available": 3 }
   }
   ```
3. Descontar stock y registrar movimientos `sale`.
4. Calcular la comisión y **guardarla con el mínimo y los porcentajes de ese
   momento** (si mañana cambian, la venta no se recalcula):
   - `gain = Σ (unit_price − min_price) × quantity`
   - `personal = redondear(gain × personal_rate)` a 2 decimales
   - `fund = redondear(gain × fund_rate)`
5. Estado inicial `pending_payment`, comisión `pending`. Comprobante `missing`
   si es `qr`, `not_required` si es `cash`.
6. Avisar al admin (panel de pedidos).

### 9 · `GET /orders`

Query: `status` (opcional, uno de los estados de §7), `page`. Solo los pedidos
del vendedor autenticado, del más nuevo al más antiguo. 20 por página.

```json
{
  "data": [
    {
      "id": "131", "number": "131",
      "created_at": "2026-11-23T11:20:00-04:00",
      "customer_name": "Mariela Quispe",
      "items_label": "Combo Escritorio Pro",
      "total": "199.00",
      "payment_method": "qr",
      "status": "pending_payment",
      "commission": { "amount": "3.20", "state": "pending" }
    }
  ],
  "meta": { "current_page": 1, "last_page": 1, "per_page": 20, "total": 1 }
}
```

- `number`: número visible sin «#».
- `items_label`: resumen en una línea. Un producto: `Lámpara luna LED × 1`; un
  combo suelto: `Combo Escritorio Pro`; varias líneas: `Lámpara luna LED × 1 y 2 más`.

### 10 · `GET /orders/{id}`

```json
{
  "data": {
    "id": "131", "number": "131",
    "created_at": "2026-11-23T11:20:00-04:00",
    "customer_name": "Mariela Quispe",
    "items_label": "Combo Escritorio Pro",
    "total": "199.00",
    "payment_method": "qr",
    "status": "pending_payment",
    "commission": { "amount": "3.20", "state": "pending" },
    "customer_whatsapp": "71234567",
    "delivery": { "type": "delivery", "address": "Av. Blanco Galindo km 4", "city": null },
    "lines": [
      {
        "kind": "combo", "item_id": "1", "code": "CMB-01",
        "name": "Combo Escritorio Pro", "quantity": 1,
        "unit_price": "199.00", "min_price": "191.00"
      }
    ],
    "breakdown": { "gain": "8.00", "personal": "3.20", "fund": "2.00" },
    "payment_proof": {
      "status": "uploaded",
      "url": "https://api.traigo.bo/storage/proofs/131.jpg",
      "uploaded_at": "2026-11-23T11:25:00-04:00",
      "rejection_reason": null
    },
    "timeline": [
      { "key": "registered", "at": "2026-11-23T11:20:00-04:00" },
      { "key": "payment_confirmed", "at": null },
      { "key": "delivered", "at": null }
    ]
  }
}
```

- `lines[].min_price`: el mínimo **vigente al momento de la venta** (copia guardada).
- `timeline`: siempre esas 3 claves; `at = null` significa pendiente.
- `payment_proof.status`: ver §7.

### 11 · `POST /orders/{id}/cancel`

Sin cuerpo. Solo si el estado es `pending_payment`. Debe devolver el stock
(movimiento `cancelled`), pasar la comisión a `reverted` y el pedido a
`cancelled`. `200` con el detalle. Si ya no se puede:

```json
{
  "message": "Este pedido ya no se puede cancelar porque el pago fue confirmado.",
  "code": "not_cancellable"
}
```

### 12 · `POST /orders/{id}/payment-proof`

`multipart/form-data` con el archivo en el campo **`proof`**. Solo para pedidos
`qr` en `pending_payment`. Se puede volver a subir si el admin lo rechazó.
Devuelve el detalle con `payment_proof.status = "uploaded"`. Si el pago es en
efectivo: `422`.

---

## 7. Estados y enumeraciones

**`status` del pedido**

| Valor | Etiqueta en la app | Lo cambia |
|---|---|---|
| `pending_payment` | Por confirmar | (estado inicial) |
| `preparing` | Pago confirmado | Admin confirma el pago |
| `on_the_way` | En camino | Admin despacha |
| `delivered` | Entregado | Admin marca entregado |
| `returned` | Devuelto | Admin registra devolución |
| `cancelled` | Cancelado | El vendedor (solo desde `pending_payment`) |

**`commission.state`**: `pending` (provisoria: la venta está registrada y espera
confirmación de pago y entrega), `approved` (el pedido se entregó), `reverted`
(devuelto o cancelado).

**`payment_proof.status`**: `missing`, `uploaded`, `confirmed`, `rejected`
(con `rejection_reason`), `not_required` (efectivo).

**`payment_method`**: `qr`, `cash`. **`delivery.type`**: `handoff`, `delivery`,
`other_city`, `pickup`.

**Acciones del admin que cambian lo que ve el vendedor** (ya existen en el panel
web, solo hay que reflejarlas en estos campos):

| Acción en el admin | Efecto visible en la app |
|---|---|
| Confirmar pago | `status → preparing`, `payment_proof → confirmed`, `timeline.payment_confirmed.at` con fecha |
| Rechazar comprobante | `payment_proof → rejected` + `rejection_reason`; el vendedor puede volver a subir |
| Marcar entregado | `status → delivered`, `commission.state → approved`, `timeline.delivered.at` |
| Marcar devuelto | `status → returned`, `commission.state → reverted` |
| Aprobar / rechazar merma | `waste.status`; si se aprueba baja el stock |

---

## 8. Stock

### 13 · `GET /stock/summary`

```json
{
  "data": {
    "products_total": 124,
    "low_count": 2,
    "out_count": 1,
    "attention_items": [
      {
        "id": "3", "kind": "product", "code": "TR-0133",
        "name": "Termo digital 500 ml", "category": "Cocina", "image_url": null,
        "suggested_price": "75.00", "min_price": "48.00",
        "stock": 3, "low_stock_alert": 10, "components": []
      }
    ]
  }
}
```

`attention_items`: **solo productos sueltos** con `stock ≤ low_stock_alert`
(incluye agotados), del que tiene menos al que tiene más. `low_count` excluye
los agotados.

### 14 · `GET /stock/movements`

Query: `date` (`YYYY-MM-DD`, por defecto hoy en `America/La_Paz`), `page`.

```json
{
  "data": [
    {
      "id": "901",
      "occurred_at": "2026-11-23T11:20:00-04:00",
      "quantity_delta": -1,
      "item_name": "Combo Escritorio Pro",
      "description": "Venta #131 de Ana",
      "type": "sale",
      "pending": false
    }
  ],
  "meta": { "current_page": 1, "last_page": 1, "per_page": 20, "total": 1 }
}
```

`type`: `sale`, `entry`, `waste`, `adjustment`, `returned`, `cancelled`.
`pending = true` solo para una merma aún sin aprobar (el stock real **todavía no
bajó**). Del más nuevo al más antiguo. Decisión de este contrato: muestra los
movimientos de **toda la bodega** (ventas web, de otros vendedores, ingresos),
no solo los del vendedor, porque la pantalla se llama «Stock sincronizado».

---

## 9. Mermas

### 15 · `POST /waste`

`multipart/form-data` + `Idempotency-Key`.

| Campo | Regla |
|---|---|
| `item_id` | Id de un **producto suelto** (los combos no se reportan) |
| `quantity` | Entre 1 y el stock actual |
| `reason` | `damaged`, `factory_defect`, `lost_or_theft`, `sample_or_gift`, `supplier_return`, `count_adjustment` |
| `note` | Opcional, hasta 200 caracteres |
| `photo` | Opcional, imagen |

`201`:

```json
{
  "data": {
    "id": "19", "item_id": "3", "item_name": "Termo digital 500 ml",
    "quantity": 1, "reason": "damaged", "status": "pending",
    "note": "Se cayó del estante",
    "created_at": "2026-11-23T09:12:00-04:00"
  }
}
```

Queda `pending`. **El stock no baja hasta que el admin la aprueba.** Debe aparecer
en `GET /stock/movements` con `pending: true`.

### 16 · `GET /waste`

Query: `status` (`pending`, `approved`, `rejected`), `page`. Solo las del vendedor.
Formato `{ data: [<merma>], meta }`.

---

## 10. Notas para Laravel

- **Sanctum**: tokens personales con `createToken($device_name)`; `logout` borra
  `currentAccessToken()`; el admin puede borrar todos los tokens de un vendedor
  (celular perdido).
- **API Resources** para producir exactamente estas formas (`JsonResource` ya
  envuelve en `data` y `ResourceCollection` agrega `meta`).
- **Dinero**: columnas `decimal(10,2)` y casteo a string con 2 decimales. Evitar
  `float`.
- **Zona horaria**: `config('app.timezone') = 'America/La_Paz'`.
- **Idempotencia**: un middleware que guarde la respuesta por
  `(seller_id, Idempotency-Key)` y la repita.
- **Comprobantes y fotos**: disco privado; devolver `payment_proof.url` firmada
  (`Storage::temporaryUrl`) o servida solo con el token.
- **Mensajes en español**: `lang/es` para que `422` llegue legible.
- **Rate limit** de login por código + IP con `RateLimiter`.
- **Visibilidad**: un vendedor nunca ve pedidos, mermas ni comprobantes de otro
  (`404`, no `403`).

## 11. Decisiones que aún no están cerradas

Se resolvieron con valores por defecto; cambiarlas toca poco código, pero hay
que decidirlas antes de producción:

| Tema | Hoy en el contrato | Pendiente |
|---|---|---|
| Pago de comisiones | `payout_note = null` («por definir») y sin endpoints de retiro | Definir si es quincena, mes o a pedido |
| Cuándo cuenta la comisión | «Ganaste hoy» y el mes incluyen las comisiones `pending` (desde que se registra la venta) | Decidir si solo cuentan desde que el admin confirma el pago |
| Premio del hito | `fund.prize_label = null` | El dueño define el premio |
| Efectivo | Se registra como `cash` pero no hay endpoint de rendición de cuentas | Si el vendedor debe «rendir» efectivo, hace falta un flujo aparte |
| Comprobante rechazado | Se puede volver a subir con `POST …/payment-proof` | Confirmar con el admin cuántos reintentos |
| Movimientos de stock | Toda la bodega | Si se prefiere solo los del vendedor, cambiar la regla de §8 |
| Actualización del stock | La app solo consulta al abrir y al deslizar para actualizar | Si se quiere tiempo real, agregar WebSocket |
| Versión mínima de la app | No existe | `GET /app/config` con `min_app_version` para forzar actualización |
