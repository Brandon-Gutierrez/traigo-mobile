# Traigo Equipo

App móvil (Flutter, Android e iOS) del equipo de Traigo Importaciones: los seis
integrantes, Jime (control y validación) y Dirección. Cada quien ve el bono de
la semana, su KPI y lo propio de su puesto; Jime y Dirección ven el panel de
control.

## Cómo correrla

Sin backend, con datos de prueba en memoria (por defecto):

```powershell
flutter run
```

Todos entran con el PIN `1234`:

| Código | Quién | Qué ve al centro de la barra |
|---|---|---|
| `AIL-02` | Ailén · contenido y lives | Evidencia |
| `ISA-03` | Isaí · almacén y caja | Caja |
| `ALI-04` | Alison · ventas por comisión | Vender |
| `KIM-05` | Kim · ventas mayoristas | Vender |
| `SIS-06`, `SIS-07` | Sistemas 1 y 2 | Evidencia |
| `JIM-01` | Jime · panel de control | Cierre |
| `DIR-08` | Dirección | Autorizar |

Jime y Dirección escriben además el código de verificación `123456`.

La demo es una foto del **domingo 6 de diciembre de 2026** (cierre de la primera
semana). Metas, pesos de KPI, mínimos del equipo y reparto salen de los Excel, y
también el catálogo: **62 productos** con sus precios y su mínimo por mayor, con
la ortografía de los nombres corregida. El **stock**, las ventas cobradas, los
valores reales, las ventas del día, los cierres de caja anteriores y el conteo
son **de ejemplo**. La caja de cada día se calcula con los pedidos de la demo.

En la demo se puede registrar ventas, subir comprobantes y evidencia (con la
cámara o la galería de verdad), enviar entregas de Sistemas, cancelar pedidos y,
como Isaí, enviar la caja, despachar, registrar ingresos y ajustes y contar.
El stock se reserva, se libera y sale al entregar, y lo enviado queda «En
revisión» hasta que Jime lo valida. Todo vive en memoria y se borra al cerrar la
app. Las ventas no mueven lo cobrado de la semana ni los valores del KPI (esos
los carga Jime).

Para probar el panel completo en la demo:

1. Como Jime, el cierre pide revisar **3 comprobantes** y las **2 evidencias**
   de «Pendientes» y validar la **caja del sábado 5**.
2. Falta el efectivo del viernes 4 y de hoy: ingresa como Isaí (`ISA-03`),
   reenvía la caja del 4 (observada) y envía la de hoy. Después Jime las valida.
3. En «Cierre», Jime confirma los duplicados, cierra a Sistemas 1 como «no
   cumple» (o resuelve sus entregas) y envía a Dirección.
4. Dirección (`DIR-08`) autoriza el bono y Jime marca cada pago en «Bonos».

Sin cerrar la app, cambia de persona con «Cerrar sesión»: los datos de la demo se
conservan. En la demo **no se genera el Excel** (lo arma el backend) y las
comisiones no se pueden enviar porque diciembre no terminó.

Contra el backend Laravel:

```powershell
flutter run --dart-define=API_MODE=live --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

`10.0.2.2` es el `localhost` de tu PC visto desde el emulador de Android. En un
celular físico usa la IP de tu PC en la red local (en debug se permite `http`;
en producción debe ser `https`).

Lo que debe ofrecer el backend (app y tienda web) está en
[docs/api-contract.md](docs/api-contract.md). El backend se programa por fases
en su repositorio, rama `feature/endpoints-mobile` (su `README.md` dice cómo
levantarlo). Por ahora tiene **todo lo del equipo, el almacén y el panel de
Jime** (pendientes y validaciones, devoluciones y duplicados, cumplimiento,
cierre semanal, bono y comisiones). Faltan «Más» → Precios, Auditoría, reportes
y Accesos, y **autorizar** desde Dirección: contra él, un cierre enviado queda
esperando.

El documento se **genera**: se edita `tool/api-contract.template.md` y se corre

```powershell
dart tool/build_contract.dart
```

Los ejemplos JSON salen de `test/fixtures/`, los mismos que prueban la app, y una
prueba falla si el documento queda desactualizado o le falta alguna ruta.

## Precio por mayor

Cada producto tiene **su propia cantidad mínima**: al llegar a ella, todas las
unidades de ese producto pasan al precio mayorista. No se suman unidades de
distintos códigos y **no hay un monto mínimo de pedido**. La regla está en
`lib/features/catalog/domain/pricing.dart`; el backend debe calcular lo mismo.

## Evidencia y entregas

- La evidencia de un indicador es una **foto** (JPG o PNG, máximo 5 MB), un
  **enlace** o, para quienes venden, un **pedido propio**. No se adjuntan PDF:
  un informe se sube como enlace o como foto.
- Cuando Jime **ya la validó**, solo se puede ver. Si la observa, se vuelve a
  subir.
- En las entregas de Sistemas, **la fecha real la pone quien entrega** (viene con
  la de hoy) y Jime la comprueba; de ella sale «a tiempo» o «fuera de plazo».
- En «Mi semana» se pueden revisar las semanas anteriores y subir lo que falte
  mientras no estén cerradas.

## Venta, almacén y caja

- Al registrar una venta, quien vende pone la **fecha y hora de entrega
  acordadas** con el cliente. De ahí sale si un despacho va atrasado. Los
  pedidos de la web no la tienen. Un QR que Jime confirma después de esa hora
  no es atraso de almacén.
- Una venta **en efectivo** nace «Pagado» para que almacén la entregue. Jime la
  confirma al validar la caja; recién entonces cuentan el bono y la comisión.
  Quien vende ya no la puede cancelar.
- **Cada día se cierra la caja**, aunque no haya cobros, desde el 1 de
  diciembre. Isaí escribe lo que de verdad recibió (no se rellena solo) y puede
  enviar los días atrasados y los que Jime observó. Una diferencia exige
  explicación.
- **Cada cobro queda en un solo cierre.** El que llega después de enviar la caja
  de su día pasa al siguiente cierre que se envíe.
- **Despachos y stock** se abren desde la sección «Almacén» del Inicio de Isaí.
- Los **ajustes** de stock llevan motivo. En un **conteo** no se muestra lo que
  dice el sistema hasta guardarlo; la diferencia la ajusta Isaí con su motivo y
  el conteo queda tal cual para su KPI.

## Panel de Jime y de Dirección

- **Pendientes** junta comprobantes, evidencias, cierres de caja y entregas de
  Sistemas, primero lo más antiguo. En un comprobante, el sistema revisa que la
  referencia no se repita; el monto y la cuenta los marca Jime.
- **Cumplimiento** (desde el Resumen) muestra a cada persona; Jime puede cargar
  los valores reales aunque nadie haya subido evidencia.
- **Cierre semanal**: «Cobros conciliados» y «KPI con evidencia» los calcula el
  sistema; los duplicados los confirma Jime. Quien siga pendiente se cierra como
  «no cumple» con un motivo. Se envía cuando la semana termina (la demo, fija en
  el domingo 6, deja enviarla ese día).
- **Semanas**: Cumplimiento y Cierre abren la terminada más antigua sin enviar,
  y Bonos la que falta pagar; si no hay, la actual. Se puede ir a la anterior o
  a la siguiente.
- Mientras el cierre está con Dirección, nadie cambia valores, evidencia ni
  entregas de esa semana; para corregir, Dirección lo devuelve.
- Con la autorización de Dirección la semana queda cerrada y Jime marca cada
  pago del bono.
- **Comisiones**: se envían cuando termina el mes (las de diciembre, desde el 1
  de enero). Mientras tanto se pueden ver. Cuentan en el mes en que llegó el
  dinero; si ese mes ya se envió, pasan a la siguiente liquidación.
- **Precios**: Jime propone y Dirección aprueba. Si se aprueba el % de un
  producto, lo toman las ventas sin % que no se liquidaron.
- **«Más» → Pedidos**: devoluciones y ventas duplicadas.
- **«Más» → Accesos**: PIN nuevo y cerrar sesiones, solo de las 6 cuentas del
  equipo.
- **«Más» → Auditoría y reportes**: el historial y los tres Excel, que se abren
  en la hoja de compartir del celular (paquete `share_plus`).

## Estructura

```
lib/
  app/                 MaterialApp, rutas (go_router) y barra inferior por rol
  core/
    config/            demo vs. API real (--dart-define)
    network/           cliente Dio, errores tipados, rutas de la API
    money/             Money: dinero en centavos, con formato «Bs 412,50»
    media/             fotos con la cámara o la galería
    share/             compartir los reportes de Excel
    storage/           token de sesión en almacenamiento seguro
    theme/             colores, fuentes y tema del diseño «Ficha técnica»
    ui/                piezas del diseño (corte, botón, filas con puntos, regla)
    demo/              servidor de prueba en memoria
    providers.dart     ÚNICO lugar que elige demo o API real
  features/
    auth/              ingreso, verificación en dos pasos y sesión
    home/              Inicio del equipo
    catalog/           catálogo, ficha y regla de precio por mayor
    orders/            registrar venta, mis pedidos y comprobantes
    team/              bono y KPI: «Equipo», «Mi semana», evidencia y entregas
    warehouse/         despachos, caja del día, stock y conteos
    control/           panel de Jime: resumen, bandeja, cierre, bono, precios
    management/        autorizaciones de Dirección
```

Cada carpeta de `features` separa lo que necesita en `domain/` (modelos, reglas
e interfaz del repositorio), `data/` (contra la API) y `presentation/`
(pantallas).

Las pantallas hablan con interfaces (`AuthRepository`, `OrdersRepository`,
`ReviewRepository`…). `core/providers.dart` elige la implementación según
`API_MODE`. **Todas** tienen su versión para la API y su versión de demo, que
aplica las mismas reglas que pide el contrato.

La app **solo oculta** lo que no corresponde a cada rol. Los permisos de verdad
los tiene que aplicar el backend.

## Pruebas

```powershell
flutter analyze
flutter test
```

- `test/features/team`: reglas del bono y del KPI, «Equipo», «Mi semana»,
  evidencia y entregas.
- `test/core`: dinero y servidor de prueba (incluye que las cifras de la demo
  cuadren entre las pantallas; las ventas: stock, claves repetidas, cambios de
  precio y comprobantes; las reglas de evidencia, entregas, despachos, caja,
  stock y conteos; y las del panel: cierre, bono, precios, pedidos y accesos).
- `test/data`: la capa HTTP contra un servidor falso, con los ejemplos de
  `docs/api-contract.md`.
- `test/features`: ingreso, verificación, Inicio de cada puesto, Resumen,
  catálogo, registrar venta, mis pedidos, comprobantes, almacén y el panel de
  Jime y Dirección, incluso en un celular de 320 de ancho con letra grande.
- `test/app`: barra por rol, acceso a pantallas y cierre de sesión.

`test/flutter_test_config.dart` carga las fuentes de la app para que las
comprobaciones de desborde se parezcan a lo que se ve en el celular.

## Fases

Las cinco fases están hechas.

| Fase | Contenido | Pantallas |
|---|---|---|
| 1 | Diseño «Ficha técnica», logo e ícono, ingreso para todos (con verificación para Jime y Dirección), barra por rol, Inicio del equipo y Resumen | Hechas |
| 2 | Catálogo y ficha (todo el equipo); registrar venta en dos pasos con precio por mayor automático, Mis pedidos, detalle, comprobante y cancelar (quienes venden) | Hechas |
| 3 | «Mi semana» con el KPI, «Equipo», subir y ver evidencia, la pestaña «Evidencia» y las entregas de Sistemas | Hechas |
| 4 | Cierre de caja (también días atrasados), despachos, stock y conteos | Hechas |
| 5 | Panel de Jime y Dirección: pendientes, validaciones, cumplimiento, cierre, bonos, comisiones, precios, autorización, pedidos, auditoría, reportes y accesos | Hechas |

La versión anterior de la app (precio mínimo, mermas y stock) se quitó porque no
corresponde a cómo se manejan los productos según los Excel. Sigue en el
historial de git (commit `921eb45`).

## Marca y fuentes

El logo está en `assets/brand/` (recortado de los archivos oficiales). Las
fuentes van dentro de la app, en `assets/fonts`, con licencia OFL, y vienen de
Google Fonts:

- **Oxanium** (variable): títulos, cifras grandes y botones.
- **IBM Plex Sans** (variable): textos.
- **IBM Plex Mono** (400, 500 y 700): códigos, montos en filas y etiquetas.

## Pendientes conocidos

- **Decisiones del negocio**: están en la sección 17 de
  [docs/api-contract.md](docs/api-contract.md) (confirmar los mínimos por mayor
  de cada producto, el código del segundo paso y las comisiones, entre
  otras).
- **Mockups**: todavía mencionan el monto mínimo de Bs 1.000 para el precio por
  mayor, que ya no aplica (la app, la demo y la base de datos no lo usan).
- **Fotos de productos**: mientras no haya, la app dibuja una ilustración según
  la categoría.
- **Mockups del panel**: no muestran el cierre a mano de quien sigue pendiente,
  la pantalla de Pedidos ni la de Accesos, que la app sí tiene.
- **Excel**: lo genera el backend; en la demo solo se avisa.
- **Backend real**: la capa de datos se probó contra Laravel en cada fase del
  backend; falta usar la app en un emulador o celular conectada a él.
- **Celular real**: se revisó con pruebas automáticas y capturas, no en un
  dispositivo. Falta probar ahí la cámara, la galería y compartir el Excel.
- **Enlaces de evidencia**: se pueden copiar, pero la app no los abre (haría
  falta el paquete `url_launcher`).
- **Android release**: falta configurar la firma (`signingConfig`).
- **iOS**: renombrada a «Traigo Equipo» (`com.traigo.equipo`) pero sin compilar;
  requiere una Mac.
