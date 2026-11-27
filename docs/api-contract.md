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

### El backend

En el repositorio del backend, rama `feature/endpoints-mobile`. Ya están la
**base de la API y el ingreso** (secciones 1, 2 y 4), el **Inicio, el equipo y
«Mi semana»** (sección 5), el **catálogo y las ventas** (sección 6), el
**almacén** (sección 7), el **panel de Jime** (secciones 8 y 9) y **«Más» y
Dirección** (10 y 11): todo lo que usa la app. La tienda web (12) no se hizo. Su `README.md` dice cómo instalarlo, dar el PIN y el correo de
cada persona (`php artisan traigo:pin` y `traigo:correo`) y correr las pruebas.

La base (`database/`) son las migraciones para **PostgreSQL 13 o superior** y los
datos de arranque: 62 productos, equipo, campaña de 7 semanas, 33 indicadores,
sus metas semanales, las 8 entregas de Sistemas y la configuración.

Ya resuelto en el código: zona horaria de Bolivia (aplicación y conexión),
Sanctum con ids UUID, `traigo.user_id` en cada petición para el historial,
errores en este formato (las reglas de la base llegan como `409` en español) e
`Idempotency-Key`.

**Archivos**: se guardan en el servidor (`storage/app/private`, que tiene que
entrar en el respaldo) y salen con un enlace firmado que vence; `public_id` y
`url` guardan la ruta (decidido en la fase 2, en vez de Cloudinary).

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
| `commission_pct` | Porcentaje de 0 a 100: `"5.00"` = 5 % |
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
| `idempotency_conflict` | 409 | La misma `Idempotency-Key` llegó con otros datos |
| `request_in_progress` | 409 | El primer envío con esa clave todavía se está procesando |
| `two_factor_unavailable` | 409 | Esa cuenta no tiene correo para recibir el código |
| `insufficient_stock` | 409 | No alcanza (`data.product_id`, `data.available`). Al entregar: lo apartado no alcanza (`data.product_id`) |
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
| `checks_failed` | 422 | Al enviar el cierre semanal falta un control (el mensaje dice cuál) |
| `month_not_ended` | 409 | Las comisiones se envían cuando el mes termina |
| `nothing_to_settle` | 409 | No hay comisiones cobradas que liquidar en ese mes |
| `not_ready_to_pay` | 409 | Todavía no lo autorizó Dirección |
| `evidence_validated` | 409 | Jime ya validó ese indicador: no admite más evidencia |
| `deliverable_validated` | 409 | Jime ya validó esa entrega: no se vuelve a enviar |
| `week_closed` | 409 | El cierre de la semana está con Dirección o ya se autorizó, o Jime cerró la de esa persona |
| `week_not_ended` | 409 | El cierre semanal se envía cuando la semana termina |
| `collected_changed` | 409 | Desde el envío cambió lo cobrado y con eso lo que se paga: se devuelve a Jime |
| `change_outdated` | 409 | El producto cambió y el precio pedido ya no cabe: se devuelve a Jime |
| `below_wholesale` | 409 | La promoción bajaría del precio por mayor |
| `promised_in_past` | 422 | La entrega acordada ya pasó (con 30 minutos de margen) |
| `invalid_status` | 409 | El pedido ya no está en el estado que pide la acción |
| `closing_already_sent` | 409 | El cierre de caja de ese día, el de la semana o la liquidación del mes ya se enviaron |
| `note_required` | 422 | Un ajuste de stock sin motivo |
| `below_reserved` | 409 | El stock quedaría por debajo de lo reservado |
| `already_adjusted` | 409 | Esa diferencia de conteo ya se corrigió |

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

«Lo del equipo»: `/home`, `/team/week`, `/me/*` y leer `/catalog`. El catálogo
también lo leen `control` y `management` («Precios autorizados» y pedidos).

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
| `GET /me/attendance` | cuenta activa del equipo | `attendance_assignments`, `attendance_marks` |
| `POST /me/attendance` | titular del turno | `attendance_attempts` |
| `POST /me/kpi-results/{id}/evidence` | equipo (lo suyo) | `kpi_evidence` |
| `POST /me/deliverables/{id}/submission` | systems (lo suyo) | `system_deliverables` |
| `GET /catalog` | equipo, control, management | `products`, `inventory` |
| `GET /catalog/categories` | equipo, control, management | `categories` |
| `GET /catalog/{id}` | equipo, control, management | `products`, `product_images` |
| `GET /orders` | seller, wholesale | `orders` |
| `GET /orders/{id}` | seller, wholesale | `orders`, `order_items`, `payments`, `commissions` |
| `POST /orders` | seller, wholesale | idem + `inventory` |
| `POST /orders/{id}/cancel` | seller, wholesale | `orders`, `inventory` |
| `POST /orders/{id}/payment-proof` | seller, wholesale | `payments` |
| `GET /warehouse/dispatches` | warehouse | `orders` |
| `POST /warehouse/orders/{id}/ready` | warehouse | `orders` |
| `POST /warehouse/orders/{id}/delivered` | warehouse | `orders`, `inventory`, `stock_movements` |
| `GET /cash/today` | warehouse | `payments`, `cash_closings` |
| `GET /cash/days/{date}` | warehouse | `payments`, `cash_closings` |
| `POST /cash/closings` | warehouse | `cash_closings`, `cash_closing_lines` |
| `GET /inventory/counts` | warehouse, control | `inventory_counts` |
| `POST /inventory/counts` | warehouse | `inventory_counts` |
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
| `GET /control/orders` · `GET /control/orders/{id}` | control | `orders`, `payments` |
| `POST /control/orders/{id}/return` | control | `orders`, `payments`, `commissions`, stock |
| `POST /control/orders/{id}/duplicate` | control | `orders` |
| `GET /control/compliance` | control, management | `v_member_week_compliance` |
| `GET /control/members/{id}/week` | control | `kpi_weekly_results`, `kpi_evidence`, `system_deliverables` |
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
| `GET /control/members` | control | `users` |
| `POST /control/members/{id}/pin` · `POST /control/members/{id}/revoke-sessions` | control | `users`, tokens |
| `GET /management/authorizations` | management | varias |
| `GET /management/authorizations/{type}/{id}` | management | varias |
| `POST /management/authorizations/{type}/{id}/approve` · `POST /management/authorizations/{type}/{id}/return` | management | varias |

## 4. Ingreso

`POST /auth/login` recibe `{ "code": "ALI-04", "pin": "1234", "device_name": "Traigo Equipo (android)" }`
(el código llega en mayúsculas). El equipo recibe el token:

```json
{
  "data": {
    "token": "12|k9sPq3",
    "member": {
      "id": "4",
      "code": "ALI-04",
      "name": "Alison",
      "role": "seller",
      "title": "Ventas por comisión"
    }
  }
}
```

Jime y Dirección reciben un segundo paso, **sin token todavía**:

```json
{
  "data": {
    "two_factor": {
      "challenge_id": "9f3a1c",
      "expires_at": "2026-12-06T18:05:00-04:00",
      "resend_at": "2026-12-06T18:00:45-04:00",
      "code_length": 6
    }
  }
}
```

- `401` con `"Código o PIN incorrectos."` si falla cualquiera de los dos o la
  cuenta está desactivada.
- `pin_hash` con bcrypt. Intentos: 5 por minuto por código e IP (20 por IP).
  Con **5 PIN fallidos seguidos** la cuenta se bloquea 15 minutos: `429` con
  `Retry-After`, también con el PIN correcto.
- La sesión no vence sola (el servidor puede ponerle plazo con
  `SANCTUM_EXPIRATION`); se cierra al salir, al cambiar el PIN o al revocarla.

`POST /auth/two-factor` recibe `{ "challenge_id", "code", "device_name" }`:

```json
{
  "data": {
    "token": "13|Zr81aa",
    "member": {
      "id": "1",
      "code": "JIM-01",
      "name": "Jime",
      "role": "control",
      "title": "Control y validación"
    }
  }
}
```

Errores:

```json
{
  "message": "El código no es correcto.",
  "code": "two_factor_invalid"
}
```

El código llega **por correo** a Jime y Dirección. Vence a los 5 minutos, sirve
una vez, admite 5 intentos, se guarda hasheado (`code_hash`) y **nunca** viaja
en una respuesta. Se pueden pedir 5 códigos cada 15 minutos (`429`). Si la
cuenta no tiene correo, `409 two_factor_unavailable`; si el correo no sale,
`503` y no queda ningún código.

`POST /auth/two-factor/resend` con `{ "challenge_id" }`: crea otro y anula el
anterior; antes de `resend_at`, `429`. Sirve aunque el código haya vencido, hasta
15 minutos después; luego, `422 two_factor_expired` y se vuelve a ingresar.

```json
{
  "data": {
    "challenge_id": "71be02",
    "expires_at": "2026-12-06T18:06:00-04:00",
    "resend_at": "2026-12-06T18:01:45-04:00",
    "code_length": 6
  }
}
```

`POST /auth/logout`: revoca el token usado (`204`).
`GET /me`:

```json
{
  "data": {
    "member": {
      "id": "4",
      "code": "ALI-04",
      "name": "Alison",
      "role": "seller",
      "title": "Ventas por comisión"
    }
  }
}
```

## 5. Inicio, equipo y mi semana

**Semana en curso**: la de `bonus_weeks` que contiene la fecha de hoy en Bolivia.
Antes de la campaña, la primera; después, la última.

### `GET /home`

Solo datos de quien pregunta. `/home`, `/team/week` y `/me/*` son del equipo:
`control` y `management` reciben `404`.

```json
{
  "data": {
    "week": {
      "label": "1–6 dic",
      "starts_on": "2026-12-01",
      "ends_on": "2026-12-06",
      "target": "40000.00",
      "base_prize": "1500.00"
    },
    "collected": "41600.00",
    "fund_share_rate": "0.20",
    "kpi": {
      "score_percent": 83,
      "minimum_percent": 80,
      "compliance": "passes",
      "deliverables": null,
      "indicators": [
        {
          "id": "41",
          "name": "Nuevos compradores contactados",
          "target": 27,
          "actual": 25,
          "weight": "0.30",
          "evidence_status": "validated"
        },
        {
          "id": "44",
          "name": "Registro semanal de ventas",
          "target": 1,
          "actual": null,
          "weight": "0.10",
          "evidence_status": "in_review"
        }
      ]
    },
    "month_commission": {
      "amount": "412.50",
      "pay_note": null
    },
    "today_sales": [
      {
        "id": "1046",
        "created_at": "2026-12-06T11:09:00-04:00",
        "items_label": "Tomatodos de Messi × 2",
        "customer_name": "Mariela Quispe",
        "total": "174.00",
        "payment_method": "qr"
      }
    ],
    "cash_today": null
  }
}
```

Almacén recibe además la caja del día y no recibe comisiones:

```json
{
  "data": {
    "week": {
      "label": "1–6 dic",
      "starts_on": "2026-12-01",
      "ends_on": "2026-12-06",
      "target": "40000.00",
      "base_prize": "1500.00"
    },
    "collected": "41600.00",
    "fund_share_rate": 0.2,
    "kpi": {
      "score_percent": 97,
      "minimum_percent": 90,
      "compliance": "passes",
      "indicators": []
    },
    "month_commission": null,
    "today_sales": [],
    "cash_today": {
      "collected": "4968.00",
      "paid_orders": 7,
      "pending_orders": 1,
      "status": "open",
      "pending_days": 1
    }
  }
}
```

Sistemas recibe sus entregas:

```json
{
  "data": {
    "week": {
      "label": "1–6 dic",
      "starts_on": "2026-12-01",
      "ends_on": "2026-12-06",
      "target": "40000.00",
      "base_prize": "1500.00"
    },
    "collected": "41600.00",
    "fund_share_rate": "0.10",
    "kpi": {
      "score_percent": 100,
      "minimum_percent": 90,
      "compliance": "pending",
      "deliverables": {
        "approved": 2,
        "total": 4
      },
      "closed_reason": null,
      "indicators": []
    }
  }
}
```

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
| `month_commission` | Solo quienes venden: comisiones `earned` y ajustes del mes. `amount` es `null` si alguna no tiene % (la app muestra «[% por definir]»). `pay_note` = ajuste `commission_pay_note` |
| `today_sales` | Ventas propias de hoy (sin las canceladas ni vencidas), la más nueva primero |
| `cash_today` | Resumen de `GET /cash/today`; `pending_days` = cuántos días anteriores faltan |

### `GET /team/week`

Los escalones salen de `bonus_tiers` (`sales_needed` redondeado hacia arriba).

```json
{
  "data": {
    "week": {
      "label": "1–6 dic",
      "starts_on": "2026-12-01",
      "ends_on": "2026-12-06",
      "target": "40000.00",
      "base_prize": "1500.00"
    },
    "collected": "31200.00",
    "tiers": [
      {
        "tier": "partial",
        "threshold_percent": 90,
        "sales_needed": "36000.00",
        "fund": "750.00",
        "my_share": "150.00"
      },
      {
        "tier": "complete",
        "threshold_percent": 100,
        "sales_needed": "40000.00",
        "fund": "1500.00",
        "my_share": "300.00"
      },
      {
        "tier": "superior",
        "threshold_percent": 115,
        "sales_needed": "46000.00",
        "fund": "1875.00",
        "my_share": "375.00"
      }
    ],
    "me": {
      "fund_share_rate": "0.20",
      "minimum_percent": 80,
      "partial_score_percent": 68,
      "compliance": "pending"
    },
    "weeks": [
      {
        "number": 1,
        "label": "1–6 dic",
        "starts_on": "2026-12-01",
        "ends_on": "2026-12-06",
        "target": "40000.00",
        "base_prize": "1500.00",
        "is_current": true
      },
      {
        "number": 2,
        "label": "7–13 dic",
        "starts_on": "2026-12-07",
        "ends_on": "2026-12-13",
        "target": "60000.00",
        "base_prize": "2500.00",
        "is_current": false
      }
    ]
  }
}
```

### `GET /me/week?week=1`

Sin `week`, la semana en curso. Con `week` también las anteriores (la app deja
revisarlas y subir evidencia mientras no se cierren); una semana que todavía no
empieza responde `404`. `score_percent` es `null` mientras falte cargar algún
indicador. `deliverables` solo para Sistemas en la semana que las pide.
`closed_reason` como en el Inicio. `accepts_evidence` es `false` cuando la
semana ya está autorizada o Jime cerró la de esta persona; entonces la app no
ofrece subir nada. Dentro de cada indicador, `evidence` va de lo más nuevo a lo
más antiguo.

```json
{
  "data": {
    "week": {
      "number": 1,
      "label": "1–6 dic",
      "starts_on": "2026-12-01",
      "ends_on": "2026-12-06",
      "target": "40000.00",
      "base_prize": "1500.00"
    },
    "count_target_factor": "0.90",
    "score_percent": null,
    "partial_score_percent": 68,
    "minimum_percent": 80,
    "compliance": "pending",
    "indicators": [
      {
        "id": "r-44",
        "name": "Registro semanal de ventas",
        "how_verified": "Pedidos, clientes y evidencias de cobro",
        "unit": "count",
        "target": 1,
        "actual": null,
        "weight": "0.10",
        "evidence_status": "in_review",
        "evidence": [
          {
            "id": "ev-1",
            "kind": "photo",
            "status": "in_review",
            "url": "https://res.cloudinary.com/traigo/registro-ventas.jpg",
            "order_id": null,
            "order_number": null,
            "note": "Incluye las 4 ventas cobradas del lunes",
            "submitted_at": "2026-12-06T09:40:00-04:00",
            "review_note": null
          }
        ]
      }
    ],
    "deliverables": [],
    "accepts_evidence": true,
    "closed_reason": null
  }
}
```

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

- Con `Idempotency-Key` UUID (`422` si falta); se guarda en
  `kpi_evidence.client_uuid`.
- Solo el indicador propio, de una semana que ya empezó; si no, `404`. El pedido
  también tiene que ser propio (`404`).
- Si Jime ya validó el indicador (la evidencia más reciente está `validated`),
  `409 evidence_validated`. Para que se pueda volver a subir, Jime la marca como
  observada.
- Si `accepts_evidence` es `false`, `409 week_closed`.
- La nueva queda `in_review` y ese pasa a ser el estado del indicador. Se pueden
  enviar varias mientras no esté validado.

`201`:

```json
{
  "data": {
    "id": "ev-1",
    "kind": "photo",
    "status": "in_review",
    "url": "https://res.cloudinary.com/traigo/registro-ventas.jpg",
    "order_id": null,
    "order_number": null,
    "note": "Incluye las 4 ventas cobradas del lunes",
    "submitted_at": "2026-12-06T09:40:00-04:00",
    "review_note": null
  }
}
```

### `POST /me/deliverables/{id}/submission`

`multipart`: `delivered_on` (fecha real, `AAAA-MM-DD`) y `file` (foto JPG o PNG
de hasta 5 MB) o `url` (enlace); si llegan los dos, vale la foto. Con
`Idempotency-Key` UUID. Solo `systems` y solo la propia (`404`). Responde `200`
con la entrega. No lleva nota: la base no la guarda y el Excel solo pide la
evidencia o el enlace.

- La **fecha real la pone quien entrega** (la app propone hoy y deja elegir una
  anterior; no puede ser futura) y Jime la comprueba al validar. Con ella la base
  decide «a tiempo» o «fuera de plazo».
- Si ya está validada (`on_time` o `late`), `409 deliverable_validated`; si
  `accepts_evidence` es `false`, `409 week_closed`.
- Mientras no esté validada se puede reenviar y **reemplaza** lo anterior: queda
  sin validar (`jime_validated`, `validated_by`, `validated_at` y `review_note`
  en nulo), o sea `in_review`.

```json
{
  "data": {
    "id": "d-1",
    "title": "Tienda web publicada, navegable y con catálogo",
    "acceptance_test": "Acceso público; categorías, precios y ficha de producto",
    "due_on": "2026-11-30",
    "status": "on_time",
    "member_id": "m-6",
    "member_name": "Sistemas 1",
    "delivered_on": "2026-11-30",
    "evidence_url": "https://res.cloudinary.com/traigo/tienda.png",
    "review_note": null
  }
}
```

### `GET /me/attendance`

Devuelve en `data` una lista de turnos propios. Cada elemento incluye
`id` (texto con el ID del turno), `site`, `starts_at`, `ends_at`, `active`,
`cancelled`, `entry_at` y `exit_at`. Las horas de las marcas pueden ser nulas.
Se incluyen turnos recientes y los que empiezan dentro de las próximas 24 horas.

### `POST /me/attendance`

La app pide una lectura puntual al pulsar para marcar. Envía `Idempotency-Key`
(UUID) y los campos `assignment_id`, `kind` (`entry` o `exit`), `latitude`,
`longitude`, `accuracy_m` y `captured_at` (ISO 8601 con zona horaria).
El servidor toma a la persona de la sesión y calcula la distancia al rango
vigente. Las coordenadas del dispositivo solo se usan para el cálculo.

Devuelve `200` con `data.accepted`, `data.marked_at`, `data.reason` y
`data.message`. Un intento rechazado tiene `marked_at: null`. Después de un
rechazo, la persona vuelve a pulsar con una nueva clave. En un reintento de
red, la misma clave conserva la decisión para ese turno y tipo de marca.
Una salida requiere una entrada. La respuesta usa el reloj del servidor.

## 6. Catálogo y ventas

### `GET /catalog?search=&category=&page=`

Productos activos, por nombre, 30 por página. `search` busca en nombre y código
(sin distinguir mayúsculas ni tildes). `category` es el id de la categoría.

```json
{
  "data": [
    {
      "id": "0b9a6f3c-1d2e-4f5a-8b7c-9d0e1f2a3b4c",
      "item_code": "8107",
      "name": "Tomatodos de Messi",
      "category": "Tomatodos",
      "price_unit": "87.00",
      "price_wholesale": "82.00",
      "wholesale_min_qty": 24,
      "stock": 48,
      "reserved": 3,
      "available": 45,
      "commission_pct": null,
      "image_url": null
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 1,
    "per_page": 30,
    "total": 1
  }
}
```

`available = stock − reserved`. `commission_pct: null` = **por definir** (la app
muestra «[% por definir]»); solo lo reciben quienes venden, `control` y
`management` (a los demás les llega `null`). El costo no viaja nunca aquí.

`GET /catalog/categories`: solo las que tienen productos activos, por nombre.

```json
{
  "data": [
    {
      "id": "c1",
      "name": "Tomatodos",
      "count": 9
    },
    {
      "id": "c2",
      "name": "Macetas",
      "count": 36
    },
    {
      "id": "c3",
      "name": "Juguetes",
      "count": 17
    }
  ]
}
```

`GET /catalog/{id}` agrega descripción e imágenes:

```json
{
  "data": {
    "id": "0b9a6f3c-1d2e-4f5a-8b7c-9d0e1f2a3b4c",
    "item_code": "8107",
    "name": "Tomatodos de Messi",
    "category": "Tomatodos",
    "price_unit": "87.00",
    "price_wholesale": "82.00",
    "wholesale_min_qty": 24,
    "stock": 48,
    "reserved": 3,
    "available": 45,
    "commission_pct": null,
    "image_url": null,
    "description": null,
    "images": []
  }
}
```

### `GET /orders?status=&page=`

Solo las ventas propias, la más nueva primero, 20 por página. `status`:
`pending_payment`, `payment_review`, `paid` (**incluye `ready`**) o `delivered`;
sin `status`, todas.

```json
{
  "data": [
    {
      "id": "o-1046",
      "number": "N-1046",
      "created_at": "2026-12-06T11:09:00-04:00",
      "customer_name": "Mariela Quispe",
      "items_label": "Tomatodos de Messi × 2",
      "total": "174.00",
      "payment_method": "qr",
      "status": "payment_review"
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 1,
    "per_page": 20,
    "total": 1
  }
}
```

### `GET /orders/{id}`

```json
{
  "data": {
    "id": "o-1046",
    "number": "N-1046",
    "created_at": "2026-12-06T11:09:00-04:00",
    "customer_name": "Mariela Quispe",
    "items_label": "Tomatodos de Messi × 2",
    "total": "174.00",
    "payment_method": "qr",
    "status": "payment_review",
    "origin": "whatsapp",
    "customer_phone": "71234567",
    "delivery": {
      "type": "pickup",
      "address": null,
      "promised_at": "2026-12-06T18:00:00-04:00"
    },
    "lines": [
      {
        "product_id": "p-8107",
        "item_code": "8107",
        "name": "Tomatodos de Messi",
        "category": "Tomatodos",
        "image_url": null,
        "quantity": 2,
        "price_type": "unit",
        "unit_price": "87.00",
        "line_total": "174.00"
      }
    ],
    "payment": {
      "method": "qr",
      "status": "submitted",
      "reference": null,
      "proof_url": "https://res.cloudinary.com/traigo/comprobante-1046.jpg",
      "submitted_at": "2026-12-06T11:25:00-04:00",
      "reject_reason": null
    },
    "timeline": [
      {
        "status": "pending_payment",
        "at": "2026-12-06T11:09:00-04:00"
      },
      {
        "status": "paid",
        "at": null
      },
      {
        "status": "ready",
        "at": null
      },
      {
        "status": "delivered",
        "at": null
      }
    ],
    "commission": {
      "status": "pending",
      "amount": null
    },
    "can_cancel": true,
    "can_upload_proof": true
  }
}
```

`lines[]` guarda la copia de la venta; `category` e `image_url` son las del
producto hoy (solo para mostrarlo). `items_label` es la primera línea y, si hay
más, «y N productos más».

`payment` es `null` mientras no haya comprobante (el cobro está `pending`) y en
los pedidos cancelados o vencidos. `proof_url` es un enlace **firmado que vence
a los 60 minutos**: se abre sin sesión y no conviene guardarlo.

`can_cancel`: solo en `pending_payment` o `payment_review`. `can_upload_proof`:
pago `qr` o `transfer` en `pending_payment` o `payment_review` (en revisión, subir
otro **reemplaza** al anterior; la app lo muestra como «Cambiar»). Si Jime
rechazó el comprobante, `payment.status = rejected` y `reject_reason` dice por
qué. La línea de tiempo sale de `created_at`, `paid_at`, `ready_at` y
`delivered_at`.

### `POST /orders` (con `Idempotency-Key`)

La clave es **obligatoria y es un UUID** (`422` si falta); también se guarda en
`orders.client_uuid`.

La app manda productos y cantidades; **no manda precios**. `expected_total` es lo
que vio la persona.

```json
{
  "origin": "wholesale",
  "customer": {
    "name": "Comercio El Hogar",
    "phone": "71234567"
  },
  "delivery": {
    "type": "pickup",
    "address": null,
    "promised_at": "2026-12-06T18:00:00-04:00"
  },
  "payment_method": "transfer",
  "lines": [
    {
      "product_id": "p-8107",
      "quantity": 24
    },
    {
      "product_id": "p-1109",
      "quantity": 10
    }
  ],
  "expected_total": "2268.00"
}
```

`origin`: `in_person`, `whatsapp` o `wholesale` (la web usa `/store/orders`).
`delivery.promised_at` es obligatorio en la app: la fecha y hora que quien vende
**acordó con el cliente** (decisión del 24/11/2026). Va en
`orders.promised_dispatch_at`; si es anterior a ahora menos 30 minutos,
`422 promised_in_past`. Los pedidos de la web no la tienen. El detalle la
devuelve en `delivery.promised_at`. `201` con el detalle. En **una sola
transacción**:

1. Bloquear el inventario de cada producto (`FOR UPDATE`).
2. Calcular precios con la regla 13.4 y comparar con `expected_total`:

```json
{
  "message": "Los precios cambiaron. Revisa el total antes de registrar.",
  "code": "price_changed",
  "data": {
    "total": "2278.00"
  }
}
```

3. Revisar `available`:

```json
{
  "message": "Solo quedan 3 de Tomatodos de Messi.",
  "code": "insufficient_stock",
  "data": {
    "product_id": "p-8107",
    "available": 3
  }
}
```

4. Crear `orders` (`seller_id` = quien registra) y `order_items`, **copiando**
   código, nombre, precios, costo y `commission_pct` del momento.
5. Sumar a `inventory.reserved` y guardar `order_status_history`.
6. Crear una fila de `commissions` por línea (`pending`; sin %, `rate_pct` y
   `amount_bs` nulos).
7. Si es en efectivo, el pedido nace **`paid`** (con `paid_at`) para que almacén
   lo pueda entregar, y el `payments` queda en `submitted` con `submitted_at` =
   ahora. Jime lo confirma al validar el cierre de caja; recién entonces cuenta
   para el bono y la comisión pasa a `earned`. Como ya está pagado, quien vende
   no lo puede cancelar (decisión del 24/11/2026).

### `POST /orders/{id}/cancel` con `{ "reason"? }`

Libera la reserva, anula las comisiones, rechaza el comprobante pendiente y
deja `cancelled`. `409 not_cancellable` si ya está pagado.

### `POST /orders/{id}/payment-proof`

`multipart`: `file` (JPG, PNG o PDF de hasta 5 MB) y `reference` (opcional),
con `Idempotency-Key` UUID. Crea o reemplaza el `payments` en `submitted` por el
total y pasa el pedido a `payment_review`; si el anterior estaba rechazado,
queda como un cobro nuevo. Referencia repetida **en la misma forma de pago**:
`409 reference_duplicated` (la base lo garantiza); al cancelar o rechazar un
cobro, su referencia queda libre. En efectivo o ya cobrado:
`409 already_reviewed`. Devuelve el detalle.

## 7. Almacén (rol `warehouse`)

### Despachos

`GET /warehouse/dispatches`: pedidos `paid` o `ready` de todos (también de la
web), ordenados por la hora acordada más cercana; los que no tienen hora van al
final, por `paid_at`. `lines` trae todo lo que hay que sacar de la bodega, **por
producto**: los combos salen por sus componentes, sumados con los productos
sueltos. `is_late` = ya pasó `promised_dispatch_at`, no se entregó y se había
pagado antes de esa hora: un QR que Jime confirma tarde no es atraso de almacén;
el efectivo, que se cobra al registrar, siempre cuenta (decidido el 25/11/2026;
sirve para
el KPI «Despachos dentro de plazo»; sin hora acordada, nunca).

```json
{
  "data": [
    {
      "order_id": "o-1043",
      "number": "N-1043",
      "customer_name": "Comercio El Hogar",
      "items_label": "Tomatodos de Ronaldo × 24",
      "lines": [
        {
          "item_code": "8109",
          "name": "Tomatodos de Ronaldo",
          "quantity": 24
        }
      ],
      "delivery_type": "delivery",
      "status": "paid",
      "is_late": false,
      "customer_phone": "71234567",
      "shipping_address": "Av. Blanco Galindo km 4, Cochabamba",
      "paid_at": "2026-12-05T16:10:00-04:00",
      "promised_at": "2026-12-06T18:00:00-04:00"
    }
  ]
}
```

- `POST /warehouse/orders/{id}/ready`: `paid` → `ready` (`204`).
- `POST /warehouse/orders/{id}/delivered`: `ready` → `delivered`; guarda
  `dispatched_at` y `delivered_at`, **resta** de `stock` y de `reserved`, y crea
  un movimiento `sale` negativo por producto (en combos, por cada componente).

En otro estado, `409 invalid_status`. Si al entregar lo apartado no alcanza (algo
lo cambió por fuera), `409 insufficient_stock` y no se descuenta nada: cada
pedido aparta lo suyo al registrarse, también los de la tienda web.

### Caja del día

`GET /cash/today`: lo cobrado hoy por forma de pago, lo recibido si ya se cerró,
los pedidos por cobrar y los **días pendientes**. `expected` suma los pagos
`submitted` o `confirmed` (sin los de pedidos cancelados, vencidos o devueltos).
`lines` trae siempre `qr`, `transfer` y `cash`, y `card` solo si hubo pagos con
tarjeta de la web.

**Cada cobro queda en un solo cierre** (decisión del 25/11/2026):

- va en la caja del día en que llegó el dinero (`received_at`; mientras esté sin
  confirmar, `submitted_at`);
- si llega **después de que ese día se envió**, se suma al **siguiente cierre que
  se envíe** de un día posterior (mientras tanto aparece en cada día posterior
  sin enviar);
- lo cobrado antes del 1/12/2026 va en la caja del 1/12.

Un día enviado o validado se muestra **como se envió**. Uno observado se vuelve a
calcular y trae lo que se había contado. `pending` son los pedidos de ese día en
`pending_payment`, con `detail` «sin comprobante» o «comprobante rechazado».
`closed_by_name` y `sent_at` son `null` mientras no se envió.

**Cada día se cierra, aunque no haya cobros** (decisión del 24/11/2026).
`pending_days` son los días desde el 1/12/2026 hasta ayer sin enviar (`open`) u
observados, del más antiguo al más nuevo.

```json
{
  "data": {
    "closing_id": "cc-1",
    "business_date": "2026-12-01",
    "status": "sent",
    "collected": "4968.00",
    "paid_orders": 7,
    "pending_orders": 1,
    "lines": [
      {
        "method": "qr",
        "orders_count": 4,
        "expected": "2140.00",
        "counted": "2140.00",
        "note": null
      },
      {
        "method": "cash",
        "orders_count": 2,
        "expected": "860.00",
        "counted": "810.00",
        "note": null
      }
    ],
    "pending": [
      {
        "order_id": "o-1047",
        "number": "N-1047",
        "customer_name": "Pedro Alanoca",
        "payment_method": "qr",
        "total": "350.00",
        "seller_name": "Alison",
        "detail": "sin comprobante"
      }
    ],
    "pending_days": [
      {
        "date": "2026-11-30",
        "status": "observed"
      }
    ],
    "closed_by_name": "Isaí",
    "sent_at": "2026-12-01T18:30:00-04:00",
    "note": "Faltan Bs 50 de cambio, se revisa mañana.",
    "review_note": null
  }
}
```

`GET /cash/days/{date}` (`2026-12-04`): un día anterior, con el mismo formato y
sin `pending_days`. Antes del 1/12/2026 o en el futuro, `404`. Antes del 1/12,
`/cash/today` muestra lo del día, pero no se puede enviar.

`POST /cash/closings` (la diferencia la calcula la base), para hoy o un día
anterior, con `Idempotency-Key` UUID (`422` si falta):

```json
{
  "business_date": "2026-12-01",
  "lines": [
    {
      "method": "qr",
      "counted": "2140.00"
    },
    {
      "method": "cash",
      "counted": "810.00"
    }
  ],
  "note": "Faltan Bs 50 de cambio, se revisa mañana."
}
```

- Hay que mandar lo recibido de cada línea (`422` «Falta lo recibido por …»). Si
  además se contó algo de una forma de pago sin línea, queda con esperado 0.
- Si algo no cuadra y no hay `note`: `422 difference_needs_note`. La app solo
  envía sin nota lo que a su vista cuadra, así que entonces vuelve a pedir la
  caja (pudo entrar un cobro mientras se enviaba).
- Queda `sent` y los pagos incluidos se ligan al cierre
  (`payments.cash_closing_id`). Si ya está `sent` o `validated`,
  `409 closing_already_sent`; si Jime lo observó, se vuelve a enviar (hay un
  cierre por fecha), esa vez aunque el día ya haya pasado. Al reenviar se borran
  `validated_by`, `validated_at` y `review_note` (quedan en el historial) y los
  pagos que ya no cuentan se desligan.

Responde `200` con el formato de `GET /cash/today`.

### Stock y conteos

`POST /inventory/movements`: entradas y ajustes, con `Idempotency-Key` UUID (se
guarda en `stock_movements.client_uuid`). `type`: `initial`, `purchase`,
`adjustment_in` (cantidad positiva) o `adjustment_out` (**negativa**); con otro
signo, `422`. El stock empieza en 0: la primera carga es con `initial` (la app
solo la ofrece para productos en 0). Los ajustes **exigen `note`** (`422
note_required`). `409 below_reserved` si el stock quedaría por debajo de lo
reservado. Responde `201`.

Para corregir un conteo se manda `inventory_count_id`: tiene que ser un ajuste
(`adjustment_in` o `adjustment_out`) por **justo la diferencia** de ese producto
(si no, `422`) y solo una vez (`409 already_adjusted`). Un producto que no está
en el conteo, `404`.

```json
{
  "product_id": "p-8109",
  "type": "adjustment_out",
  "quantity": -2,
  "note": "Conteo del viernes",
  "inventory_count_id": "ic-1"
}
```

```json
{
  "data": {
    "product_id": "p-8109",
    "stock": 36,
    "reserved": 0,
    "available": 36
  }
}
```

`POST /inventory/counts` (con `Idempotency-Key`, responde `201`): el servidor
guarda lo que había **en bodega** (`system_qty` = `stock`, con lo reservado) en
ese momento. **El conteo no cambia el stock**; se corrige con un ajuste, que hace
almacén con su motivo (decisión del 24/11/2026). La app no muestra esas cifras
mientras se cuenta. `counted_on` no puede ser futura y cada producto va una sola
vez. `GET /inventory/counts` devuelve la lista, la más nueva primero, con los
productos por nombre; `adjusted` = ya hay un movimiento de ese conteo para ese
producto. La leen `warehouse` y `control` («Más» → Inventario y conteos); Jime no
puede ajustar.

```json
{
  "counted_on": "2026-12-04",
  "items": [
    {
      "product_id": "p-8109",
      "counted_qty": 36
    }
  ],
  "note": null
}
```

```json
{
  "data": {
    "id": "ic-1",
    "counted_on": "2026-12-04",
    "items": [
      {
        "product_id": "p-8109",
        "item_code": "8109",
        "name": "Tomatodos de Ronaldo",
        "system_qty": 38,
        "counted_qty": 36,
        "adjusted": false
      }
    ]
  }
}
```

## 8. Panel de Jime: resumen y bandeja

### `GET /control/summary`

```json
{
  "data": {
    "as_of": "2026-12-06T18:00:00-04:00",
    "week": {
      "label": "1–6 dic",
      "starts_on": "2026-12-01",
      "ends_on": "2026-12-06",
      "target": "40000.00",
      "base_prize": "1500.00"
    },
    "collected": "41600.00",
    "pending": {
      "payments": 3,
      "evidence": 2,
      "cash_closings": 1,
      "deliverables": 1
    },
    "members": [
      {
        "id": "5",
        "name": "Kim",
        "score_percent": 85,
        "minimum_percent": 90,
        "compliance": "fails",
        "fund_share_rate": "0.20",
        "note": null
      },
      {
        "id": "6",
        "name": "Sistemas 1",
        "score_percent": 100,
        "minimum_percent": 90,
        "compliance": "pending",
        "fund_share_rate": "0.10",
        "note": "2 de 4 entregas validadas"
      }
    ],
    "bonus": {
      "level": "complete",
      "prize": "1500.00",
      "payable": "1050.00",
      "unpaid_failing": "300.00",
      "unpaid_pending": "150.00"
    }
  }
}
```

El resumen es de la **semana en curso**. `members[].score_percent` es el avance
con lo cargado. `pending` cuenta comprobantes `submitted` (el efectivo va con la
caja), indicadores con evidencia `in_review`, cierres de caja `sent` y entregas
en revisión (de semanas que todavía se pueden cambiar). `collected` y `bonus`
salen de `v_week_bonus` y `v_week_member_bonus` o, si la semana ya se envió, de
su foto. Lo leen `control` y `management`.

### `GET /control/pending?type=`

`type`: `payment`, `evidence`, `cash_closing`, `deliverable`. **El más antiguo
primero.** `id` es el del pago, del indicador semanal, del cierre o de la entrega.
La fecha de una evidencia es la de la más antigua sin revisar y la de una
entrega, cuando se envió. Solo `control`.

```json
{
  "data": [
    {
      "type": "cash_closing",
      "id": "cc-5",
      "title": "Isaí · cierre del sábado 5 dic",
      "subtitle": "QR, transferencia y efectivo",
      "created_at": "2026-12-05T18:30:00-04:00",
      "amount": "7670.00"
    },
    {
      "type": "payment",
      "id": "pay-9",
      "title": "Rosa Mamani · Alison",
      "subtitle": "QR",
      "created_at": "2026-12-06T10:48:00-04:00",
      "amount": "90.00"
    }
  ]
}
```

### Pagos (conciliación)

`GET /control/payments/{id}`. `reference_unique` lo calcula el servidor (en
cualquier forma de pago, sin contar pagos rechazados o devueltos).

```json
{
  "data": {
    "id": "pay-9",
    "order": {
      "id": "o-1052",
      "number": "N-1052",
      "customer_name": "Rosa Mamani",
      "seller_name": "Alison",
      "items_label": "Maceta tipo cemento pequeño × 3",
      "total": "90.00"
    },
    "method": "qr",
    "amount": "90.00",
    "status": "submitted",
    "reference": "0045-8812",
    "reference_unique": true,
    "proof_url": "https://res.cloudinary.com/traigo/comprobante-1052.jpg",
    "submitted_at": "2026-12-06T10:48:00-04:00",
    "destination_account": "Traigo",
    "reject_reason": null
  }
}
```

`POST /control/payments/{id}/confirm`:

```json
{
  "amount_matches": true,
  "destination_ok": true,
  "received_at": null
}
```

Con `amount_matches` o `destination_ok` en falso: `422` (se debe rechazar). Si el
pago ya no está `submitted`, `409 already_reviewed`; con la referencia usada en
otro pago vigente, `409 reference_duplicated`; si es efectivo, `409
invalid_status` (se confirma al validar la caja). `received_at` no puede ser
futura (`422`) ni de una semana ya enviada a Dirección (`409 week_closed`). En
una transacción: pago `confirmed` (`reviewed_by`, `reviewed_at`; `received_at`
= el indicado o `submitted_at`), pedido `paid` con `paid_at`, y sus comisiones
pasan a `earned` con `earned_at` = `received_at`. Responde con el pago.

`POST /control/payments/{id}/reject` con `{ "reason" }` (obligatorio): pago
`rejected` y el pedido vuelve a `pending_payment`.

### Evidencia y valores reales

`GET /control/kpi-results/{id}`:

```json
{
  "data": {
    "result_id": "r-44",
    "member": {
      "id": "m-4",
      "name": "Alison"
    },
    "week_label": "1–6 dic",
    "indicator": {
      "id": "r-44",
      "name": "Registro semanal de ventas",
      "how_verified": "Pedidos, clientes y evidencias de cobro",
      "unit": "count",
      "target": 1,
      "actual": null,
      "weight": "0.10",
      "evidence_status": "in_review"
    },
    "evidence": [
      {
        "id": "ev-1",
        "kind": "photo",
        "status": "in_review",
        "url": "https://res.cloudinary.com/traigo/registro-ventas.jpg",
        "order_id": null,
        "order_number": null,
        "note": "Incluye las 4 ventas cobradas del lunes",
        "submitted_at": "2026-12-06T09:40:00-04:00",
        "review_note": null
      }
    ]
  }
}
```

- `POST /control/kpi-results/{id}/validate` con `{ "actual", "note"? }`: carga el
  valor real (`loaded_by` = Jime) y valida la evidencia en revisión. Sirve también
  para indicadores sin evidencia pendiente.
- `POST /control/kpi-results/{id}/observe` con `{ "note" }`: la evidencia en
  revisión pasa a `observed` (si no hay ninguna esperando, `409
  already_reviewed`).

Ambos responden con el formato del `GET`. Una semana que no empezó: `422`.

**Con el cierre en Dirección la semana no cambia** (decidido el 25/11/2026):
mientras está `sent`, `authorized` o `paid`, ni Jime ni el equipo cambian
valores, evidencia o entregas (`409 week_closed`; en «Mi semana»,
`accepts_evidence: false`). Para corregir, Dirección lo devuelve.

`GET /control/members/{id}/week?week=1`: la semana de un integrante, **con el
mismo formato que `GET /me/week`**. Jime la abre desde Cumplimiento para cargar
valores aunque nadie haya subido evidencia. Sin `week`, la que falta cerrar
(sección 9). Con un `id` que no es del equipo, `404`. Solo `control`.

### Cierres de caja y entregas

- `GET /control/cash-closings/{id}`: formato de la caja del día.
- Validar u observar un cierre que ya no está `sent`: `409 already_reviewed`.
- `POST /control/cash-closings/{id}/validate`: `validated`; los pagos **en
  efectivo** ligados al cierre (también los que llegaron tarde) quedan
  `confirmed` (`received_at` =
  `submitted_at`) y sus comisiones pasan a `earned`. Esos pedidos ya estaban
  `paid`, `ready` o `delivered`: no cambian de estado.
- `POST /control/cash-closings/{id}/observe` con `{ "note" }`.
- `GET /control/deliverables`: las 8 entregas (lista con el formato de la sección 5).
- `POST /control/deliverables/{id}/validate` con `{ "delivered_on" }`: la fecha
  que Jime comprobó (no futura, `422`). Hasta `due_on` queda `on_time`; después,
  `late`.
- `POST /control/deliverables/{id}/reject` con `{ "note" }`: `jime_validated = false`.
- En las dos: solo las que están en revisión (`409 already_reviewed`) y con la
  semana sin enviar a Dirección (`409 week_closed`).

### Devoluciones y duplicados

Jime busca el pedido en «Más» → Pedidos.

`GET /control/orders?search=&page=`: **todos** los pedidos (también los de la web),
del más nuevo al más antiguo, 20 por página. `search` busca por número
(`N-1046`) o nombre del cliente, sin importar mayúsculas ni tildes.
`seller_name` es `null` en los de la web. Todo lo de pedidos es solo de
`control`.

```json
{
  "data": [
    {
      "id": "o-1046",
      "number": "N-1046",
      "created_at": "2026-12-06T11:09:00-04:00",
      "customer_name": "Mariela Quispe",
      "items_label": "Tomatodos de Messi × 2",
      "total": "174.00",
      "payment_method": "qr",
      "status": "payment_review",
      "seller_name": "Alison"
    },
    {
      "id": "o-1037",
      "number": "N-1037",
      "created_at": "2026-12-05T19:40:00-04:00",
      "customer_name": "Lucía Rojas",
      "items_label": "Lámpara de noche × 1",
      "total": "95.00",
      "payment_method": "transfer",
      "status": "payment_review",
      "seller_name": null
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 1,
    "per_page": 20,
    "total": 2
  }
}
```

`GET /control/orders/{id}`: el formato de `GET /orders/{id}` (sin comisión;
`can_cancel` y `can_upload_proof` en falso) y además:

- `can_return`: está `paid`, `ready` o `delivered`.
- `can_mark_duplicate`: su cobro **no** está confirmado y está `pending_payment`,
  `payment_review`, `paid` o `ready` (los dos últimos: efectivo por confirmar).
- `void_reason`: motivo de la devolución. `duplicate_of_number`: el original, si
  se anuló por duplicado.

```json
{
  "data": {
    "id": "o-1046",
    "number": "N-1046",
    "created_at": "2026-12-06T11:09:00-04:00",
    "customer_name": "Mariela Quispe",
    "items_label": "Tomatodos de Messi × 2",
    "total": "174.00",
    "payment_method": "qr",
    "status": "payment_review",
    "origin": "whatsapp",
    "customer_phone": "71234567",
    "delivery": {
      "type": "pickup",
      "address": null,
      "promised_at": "2026-12-06T18:00:00-04:00"
    },
    "lines": [
      {
        "product_id": "p-8107",
        "item_code": "8107",
        "name": "Tomatodos de Messi",
        "category": "Tomatodos",
        "image_url": null,
        "quantity": 2,
        "price_type": "unit",
        "unit_price": "87.00",
        "line_total": "174.00"
      }
    ],
    "payment": {
      "method": "qr",
      "status": "submitted",
      "reference": null,
      "proof_url": "https://res.cloudinary.com/traigo/comprobante-1046.jpg",
      "submitted_at": "2026-12-06T11:25:00-04:00",
      "reject_reason": null
    },
    "timeline": [
      {
        "status": "pending_payment",
        "at": "2026-12-06T11:09:00-04:00"
      },
      {
        "status": "paid",
        "at": null
      },
      {
        "status": "ready",
        "at": null
      },
      {
        "status": "delivered",
        "at": null
      }
    ],
    "commission": null,
    "can_cancel": false,
    "can_upload_proof": false,
    "seller_name": "Alison",
    "can_return": false,
    "can_mark_duplicate": true,
    "void_reason": null,
    "duplicate_of_number": null
  }
}
```

`POST /control/orders/{id}/return` (`204`), con motivo obligatorio. Si no se puede
devolver, `409 invalid_status`:

```json
{
  "reason": "Llegó golpeado"
}
```

Pedido `returned`; el pago confirmado queda `reversed` (deja de contar para el
bono) y el que faltaba confirmar, `rejected`; comisión `earned` → una fila
`adjustment` con base negativa en el mes actual, comisión `pending` →
`cancelled`; si ya se entregó, movimiento `sale_return` y vuelve al stock (de un
combo, sus componentes); si no, se libera la reserva. El motivo queda en la
línea de tiempo y en los pagos.

`POST /control/orders/{id}/duplicate` (`204`): se anula este pedido
(`cancel_reason = 'duplicate'`, `duplicate_of_id`), se libera la reserva y se
anulan sus comisiones y pagos pendientes. Si no se puede (`can_mark_duplicate` en
falso), `409 invalid_status`; el original tiene que ser otro pedido vigente (ni
cancelado, vencido, devuelto ni anulado por duplicado), si no, `422`.

```json
{
  "original_order_id": "o-1048"
}
```

## 9. Cumplimiento, cierre semanal, bono y comisiones

### Qué semana se muestra

Cumplimiento, cierre y bono se trabajan cuando la semana ya terminó. Sin
`?week=`, el servidor elige (decidido el 25/11/2026):

- **Cumplimiento y cierre**: la semana terminada más antigua sin enviar a
  Dirección (`open` o `returned`);
- **Bono**: la terminada más antigua sin pagar (sin enviar, sin autorizar o
  autorizada con pagos sin marcar);
- si no queda ninguna, la semana en curso.

Con `?week=n` se ve cualquier semana que ya empezó (otra, `404`). Las tres
respuestas dicen qué semana muestran y cuál es la actual (`current_week`); la
app deja ir a la anterior y a la siguiente.

### `GET /control/compliance?week=`

De `v_member_week_compliance` (las entregas, solo en la semana que las pide):

```json
{
  "data": [
    {
      "id": "m-6",
      "name": "Sistemas 1",
      "title": "Sistemas",
      "score_percent": 100,
      "partial_score_percent": 100,
      "minimum_percent": 90,
      "compliance": "pending",
      "indicators_loaded": 5,
      "indicators_total": 5,
      "deliverables_on_time": 2,
      "deliverables_total": 4,
      "closed_reason": null
    },
    {
      "id": "m-5",
      "name": "Kim",
      "title": "Ventas mayoristas",
      "score_percent": 85,
      "partial_score_percent": 85,
      "minimum_percent": 90,
      "compliance": "fails",
      "indicators_loaded": 6,
      "indicators_total": 6,
      "deliverables_on_time": null,
      "deliverables_total": null,
      "closed_reason": null
    }
  ],
  "meta": {
    "week": {
      "number": 1,
      "label": "1–6 dic",
      "starts_on": "2026-12-01",
      "ends_on": "2026-12-06",
      "target": "40000.00",
      "base_prize": "1500.00"
    },
    "current_week": 2
  }
}
```

### Cierre semanal

`GET /control/weekly-closing?week=`: los 4 controles del Excel, calculados y
redactados. `pending_members` lista a quienes siguen pendientes y qué les falta
(solo mientras está `open` o `returned`). `sendable_from` es el día siguiente al
fin de la semana: desde ahí se puede enviar. Solo `control`.

| Control | Quién lo decide | Pasa cuando |
|---|---|---|
| `payments_reconciled` | El servidor | Todos los pagos recibidos en la semana, de pedidos no cancelados ni devueltos, están confirmados: ningún comprobante por revisar y el efectivo con su caja validada |
| `kpi_evidence` | El servidor | Ningún indicador de la semana tiene evidencia `in_review` |
| `duplicates_cleared` | **Jime** al enviar | `detail` lista los duplicados quitados en la semana; antes de enviar va en falso |
| `direction_approval` | Dirección | El cierre está `authorized` o `paid` |

```json
{
  "data": {
    "week": {
      "number": 1,
      "label": "1–6 dic",
      "starts_on": "2026-12-01",
      "ends_on": "2026-12-06",
      "target": "40000.00",
      "base_prize": "1500.00"
    },
    "current_week": 2,
    "sendable_from": "2026-12-07",
    "status": "open",
    "checks": {
      "payments_reconciled": {
        "ok": true,
        "detail": "34 de 34 pagos confirmados"
      },
      "kpi_evidence": {
        "ok": true,
        "detail": "6 de 6 personas sin evidencia por revisar"
      },
      "duplicates_cleared": {
        "ok": true,
        "detail": "1 duplicado quitado (N-1049)"
      },
      "direction_approval": {
        "ok": false,
        "detail": "Falta su aprobación"
      }
    },
    "pending_members": [
      {
        "id": "m-6",
        "name": "Sistemas 1",
        "pending_reason": "2 de 4 entregas validadas"
      }
    ],
    "observations": null,
    "return_reason": null
  }
}
```

`POST /control/weekly-closing/{week}/send` (`{week}` = número de semana). La app
**no** manda los cobros ni la evidencia: el servidor los vuelve a comprobar.
`close_pending` cierra como **«no cumple»** a quienes sigan pendientes, con un
motivo obligatorio por persona (puede ir vacío):

```json
{
  "duplicates_cleared": true,
  "close_pending": [
    {
      "member_id": "m-6",
      "reason": "Solo 2 de sus 4 entregas quedaron validadas."
    }
  ],
  "observations": null
}
```

**Solo cuando la semana terminó** (desde `sendable_from`, hora de Bolivia), para
que no quede ninguna venta fuera del bono; antes, `409 week_not_ended`.

En **una sola transacción**:

1. Si el cierre no está `open` ni `returned`, `409 closing_already_sent`. Si
   `payments_reconciled` o `kpi_evidence` no pasan, o `duplicates_cleared` no es
   `true`, `422 checks_failed` (el mensaje dice cuál).
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

```json
{
  "data": {
    "week": {
      "number": 1,
      "label": "1–6 dic",
      "starts_on": "2026-12-01",
      "ends_on": "2026-12-06",
      "target": "40000.00",
      "base_prize": "1500.00"
    },
    "current_week": 2,
    "status": "sent",
    "collected": "41600.00",
    "achievement_percent": 104,
    "tier": "complete",
    "release_factor": "1.00",
    "fund": "1500.00",
    "payable": "1050.00",
    "unpaid": "450.00",
    "members": [
      {
        "id": "m-2",
        "name": "Ailén",
        "fund_share_rate": "0.20",
        "compliance": "passes",
        "share_amount": "300.00",
        "amount": "300.00",
        "paid_at": null,
        "closed_reason": null
      },
      {
        "id": "m-6",
        "name": "Sistemas 1",
        "fund_share_rate": "0.10",
        "compliance": "fails",
        "share_amount": "150.00",
        "amount": "0.00",
        "paid_at": null,
        "closed_reason": "Solo 2 de sus 4 entregas quedaron validadas."
      }
    ]
  }
}
```

`POST /control/bonus/{week}/members/{member}/paid`: solo con el cierre
autorizado, a quien cumple y todavía no cobró (`409 not_ready_to_pay`). Cuando
ya se pagó a todos los que tienen algo que cobrar, el cierre pasa a `paid`.
Responde con el bono.

### Comisiones

`GET /control/commissions?month=2026-12`: comisiones cobradas en el mes
(`earned_at` = cuando llegó el dinero) con sus ajustes, una fila por quien vende
(`seller` y `wholesale`). Lo que se gana cuando la liquidación de su mes **ya se
envió** (un cobro confirmado tarde) entra en la siguiente que se envíe de un mes
posterior (decidido el 25/11/2026). Enviada, se muestra como se envió. Si alguna no tiene %, `rates_pending: true` y los montos pueden ser
`null`. `settles_on` = último día del mes. La app consulta también el mes
anterior para saber si falta liquidarlo, así que **un mes sin ventas (también
antes de la campaña) responde `200`** con ceros, no `404`.

```json
{
  "data": {
    "month": "2026-12",
    "status": "open",
    "rates_pending": true,
    "total": null,
    "settles_on": "2026-12-31",
    "return_reason": null,
    "members": [
      {
        "id": "m-4",
        "name": "Alison",
        "amount": null,
        "paid_sales": 11,
        "adjustments": "0.00"
      },
      {
        "id": "m-5",
        "name": "Kim",
        "amount": null,
        "paid_sales": 5,
        "adjustments": "-45.00"
      }
    ]
  }
}
```

- `POST /control/commissions/{month}/send`: crea o actualiza la liquidación del
  mes, liga las comisiones `earned` y la manda a Dirección. **Solo cuando el mes
  terminó** (desde el día 1 del siguiente, hora de Bolivia): antes,
  `409 month_not_ended`. Sin comisiones cobradas, `409 nothing_to_settle`; con %
  pendientes, `409 rates_pending`; ya enviada, `409 closing_already_sent`.
- `POST /control/commissions/{month}/paid`: solo si está autorizada.

## 10. «Más»: precios, historial, reportes y accesos

`GET /control/products/{id}`:

```json
{
  "data": {
    "product_id": "p-8107",
    "item_code": "8107",
    "name": "Tomatodos de Messi",
    "category": "Tomatodos",
    "current": {
      "price_unit": "87.00",
      "price_wholesale": "82.00",
      "wholesale_min_qty": 24,
      "commission_pct": null,
      "cost": null
    },
    "pending_change": {
      "id": "pc-1",
      "proposed": {
        "price_unit": "89.00",
        "price_wholesale": "84.00"
      },
      "requested_by": "Jime",
      "requested_at": "2026-12-06T11:00:00-04:00",
      "reason": null
    }
  }
}
```

`POST /control/products/{id}/price-changes` (solo `control`): **solo los valores
que cambian** (lo igual a lo vigente se ignora). Guarda `previous_values`; un solo
cambio pendiente por producto (`409 change_pending`). Las ventas ya registradas no
cambian. `422` si no cambia nada, si un precio es 0, si el mayorista supera al
minorista, si el mínimo es menor que 2 (la base lo exige), si el precio por mayor
y su mínimo no van juntos o si la comisión no está entre 0 y 100 (hasta 2
decimales). Responde `201` con la ficha. La ficha la leen `control` y
`management`.

```json
{
  "price_unit": "89.00",
  "price_wholesale": "84.00",
  "reason": null
}
```

`GET /control/audit?page=` (`control` y `management`): del registro que escribe la
base (no se puede editar ni borrar), con cada hecho redactado en español, 30 por
página y lo más nuevo primero. **Solo lo importante** (decidido el 25/11/2026):
comprobantes confirmados o rechazados, cierres de caja, valores del KPI y
evidencia observada, entregas, cierres semanales y quien se cierra a mano, bonos
pagados, comisiones, precios y promociones, pedidos cancelados, devueltos o
duplicados, stock cargado o ajustado, conteos, PIN y sesiones, y lo cambiado
directo en la base («Sistema»). Los pasos automáticos (apartar stock, crear
comisiones al vender…) quedan en la base sin mostrarse. `id` es texto único (los
de stock y conteos empiezan con `m-` y `c-`).

```json
{
  "data": [
    {
      "id": "812",
      "at": "2026-12-06T10:42:00-04:00",
      "actor_name": "Jime",
      "description": "Cargó el valor real de «Registro semanal de ventas» de Alison: sin cargar → 1"
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 3,
    "per_page": 30,
    "total": 72
  }
}
```

`GET /control/reports/{type}?period=` (`control` y `management`): devuelve el
**.xlsx** (el archivo, no JSON), hecho con `openspout`. Los textos van siempre
como texto, así un nombre que empiece con «=» no se vuelve fórmula.

| `type` | `period` | Hojas |
|---|---|---|
| `week` | número de semana | Cierre, KPI, Bono, Pagos y, la primera semana, Entregas |
| `cash` | fecha `2026-12-05` | Caja (por forma de pago, con diferencias), Cierre, Cobros y Por cobrar |
| `commissions` | mes `2026-12` | Por persona, Por producto, Detalle y Liquidación |

Un periodo mal escrito: `422`; una semana que no empezó o un día sin caja:
`404` (el mensaje llega en JSON, como siempre).

`GET /control/system-status` (solo `control`). El backend no hace respaldos: los
hace el hosting o un script, que al terminar ejecuta `php artisan
traigo:respaldo` (y, cuando se prueba restaurar uno, `php artisan
traigo:respaldo restauracion`; `--fecha="2026-12-06 03:00"` para anotar otra
hora). Mientras no se anote nada, `null` (decidido el 25/11/2026).

```json
{
  "data": {
    "last_backup_at": "2026-12-06T03:00:00-04:00",
    "restore_tested_at": "2026-11-29T16:00:00-04:00"
  }
}
```

`GET /control/members`: las cuentas **del equipo** (sin `control` ni
`management`):

```json
{
  "data": [
    {
      "id": "2",
      "code": "AIL-02",
      "name": "Ailén",
      "title": "Contenido y lives"
    },
    {
      "id": "4",
      "code": "ALI-04",
      "name": "Alison",
      "title": "Ventas por comisión"
    }
  ]
}
```

- `POST /control/members/{id}/pin` con `{ "pin": "4821" }` (4 números): guarda el
  hash, desbloquea la cuenta y borra sus tokens (`204`). El PIN no se escribe en
  el historial ni en los registros del servidor (el historial solo dice que se
  cambió).
- `POST /control/members/{id}/revoke-sessions`: borra sus tokens (`204`).
- Las dos solo para cuentas del equipo (si no, `404`): las de Jime y Dirección
  las cambia quien administra el servidor.

## 11. Dirección

`GET /management/authorizations`: lo que está esperando (cierres `sent`,
liquidaciones `sent`, cambios de precio y promociones `pending`).
`id`: número de semana, mes `2026-12`, o el UUID del cambio o la promoción.

```json
{
  "data": [
    {
      "type": "weekly_bonus",
      "id": "1",
      "title": "Bono semana 1–6 dic",
      "requested_by": "Jime",
      "requested_at": "2026-12-06T11:02:00-04:00",
      "amount": "1050.00"
    }
  ]
}
```

`GET /management/authorizations/{type}/{id}` (`type`: `weekly_bonus`,
`commissions`, `price_change`, `promotion`):

```json
{
  "data": {
    "type": "weekly_bonus",
    "id": "1",
    "title": "Bono semana 1–6 dic",
    "requested_by": "Jime",
    "requested_at": "2026-12-06T11:02:00-04:00",
    "amount": "1050.00",
    "pays": [
      {
        "name": "Ailén",
        "amount": "300.00"
      },
      {
        "name": "Sistemas 2",
        "amount": "150.00"
      }
    ],
    "unpaid": [
      {
        "name": "Kim",
        "amount": "300.00",
        "reason": "KPI 85 % de 90 %"
      },
      {
        "name": "Sistemas 1",
        "amount": "150.00",
        "reason": "Cerrado por Jime: solo 2 de sus 4 entregas quedaron validadas."
      }
    ],
    "checks": [
      "Cobros conciliados: 34 de 34 pagos confirmados",
      "KPI con evidencia revisada",
      "Duplicados depurados"
    ],
    "changes": [],
    "can_approve": true,
    "blocked_reason": null
  }
}
```

En el bono, a quien Jime cerró a mano va en `unpaid` con el motivo («Cerrado por
Jime: …»); los demás que no cumplen, con sus entregas o su puntaje contra el
mínimo. Todo es de `management`. Lo que ya no espera (o no existe): `404`.

**Si después de enviar se devuelve algo cobrado** (decidido el 25/11/2026): el
bono sigue siendo la foto enviada, pero si con lo cobrado hoy **cambiaría lo que
se paga**, `can_approve` es `false` con `blocked_reason`, y aprobar responde
`409 collected_changed`: hay que devolverlo para que Jime lo envíe de nuevo. Si
no cambia lo que se paga, se puede autorizar y `checks` lo avisa. Una devolución
en curso hace esperar a la autorización.

Un cambio de precio que ya no cabe (porque el producto cambió después):
`can_approve: false` y `409 change_outdated`. Una promoción que bajaría del precio
por mayor: `can_approve: false` y `409 below_wholesale`.

`POST /management/authorizations/{type}/{id}/approve` (`204`):

| `type` | Efecto |
|---|---|
| `weekly_bonus` | `weekly_closings` → `authorized`, `direction_approved`, `authorized_by/at`. Si la base lo impide: `409 pending_members` con su mensaje |
| `commissions` | Liquidación → `authorized` |
| `price_change` | `approved` y **en la misma transacción** se aplica al producto. Si define la comisión, las `commissions` sin % de ese producto que no se liquidaron la toman (sección 13.5) |
| `promotion` | `approved` |

`POST /management/authorizations/{type}/{id}/return` con `{ "reason" }`
obligatorio (`204`): cierre o liquidación → `returned`; precio o promoción →
`rejected` con la nota (la de una promoción queda en el historial). Al devolver un
cierre se borran sus resultados: quien Jime cerró a mano puede completar lo suyo y
los cierres a mano se indican otra vez al reenviar.

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

Promociones: son de la tienda web (las puertas del calendario) y **no se aplican
a las ventas de la app**. Se publican solo autorizadas; una por puerta;
**ninguna baja del precio por mayor** (lo valida el backend al crear y al
vender).

> Las pantallas para **crear** promociones, productos, imágenes y combos no
> están en los mockups de la app. Hará falta un panel web o agregarlas.

### 13.5 Comisiones

Una persona por venta, con la tasa **de cada producto** al momento de vender.
`pending` → `earned` cuando el cobro se **confirma** (el efectivo, al validar la
caja, aunque el pedido ya esté `paid`), con la fecha en que llegó el dinero;
devolución de algo cobrado = `adjustment` negativo del día en que se devuelve. Se liquida por mes, **cuando el mes termina**, y es independiente del
bono. Si Dirección aprueba el % de un producto, las ventas de ese producto que no
tenían % y no se liquidaron **toman ese %** (queda en el historial).

### 13.6 Estados del pedido e inventario

```
pending_payment → payment_review → paid → ready → delivered
       │                │           └───────┴──────────→ returned
       ├────────────────┴→ cancelled
       └→ expired (web sin pagar a tiempo)

En efectivo (vendedores): nace en paid, con el cobro por confirmar.
```

| Momento | Inventario |
|---|---|
| Se registra el pedido | `reserved += cantidad` (en combos, la de cada componente) |
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
| Día | Respaldo de la base **y de `storage/app/private`** (cifrado si sale del servidor) por el hosting o un script, que lo anota con `php artisan traigo:respaldo`; cada cierto tiempo, **probar la restauración** y anotarla (el Excel lo exige) |

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
| Correo para los códigos | En desarrollo quedan en el log | Qué cuenta (SMTP) los envía en producción |
| % de comisión y fecha de pago | `null` | Definirlos |
| Comisión de ventas web | Sin vendedor, sin comisión | Si alguien debe cobrarlas |
| Envío y pasarela | `shipping_bs` nulo; `gateway_provider` libre | Costo del delivery y proveedor de tarjeta |
| Códigos del equipo | `JIM-01` … `DIR-08` (propuesta) | Confirmarlos antes de entregar los PIN |
