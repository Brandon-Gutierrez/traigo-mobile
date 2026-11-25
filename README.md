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
semana). Metas, pesos de KPI, mínimos y reparto salen de los Excel; las ventas
cobradas, los valores reales, las ventas del día y la caja son **de ejemplo**.

Contra el backend Laravel:

```powershell
flutter run --dart-define=API_MODE=live --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

`10.0.2.2` es el `localhost` de tu PC visto desde el emulador de Android. En un
celular físico usa la IP de tu PC en la red local (en debug se permite `http`;
en producción debe ser `https`).

Lo que debe ofrecer el backend (app y tienda web) está en
[docs/api-contract.md](docs/api-contract.md). La base de datos correspondiente
está en el repositorio del backend, rama `feature/bd-segun-excel`.

El documento se **genera**: se edita `tool/api-contract.template.md` y se corre

```powershell
dart tool/build_contract.dart
```

Los ejemplos JSON salen de `test/fixtures/`, los mismos que prueban la app, y una
prueba falla si el documento queda desactualizado o le falta alguna ruta.

## Estructura

```
lib/
  app/                 MaterialApp, rutas (go_router) y barra inferior por rol
  core/
    config/            demo vs. API real (--dart-define)
    network/           cliente Dio, errores tipados, rutas de la API
    money/             Money: dinero en centavos, con formato «Bs 412,50»
    storage/           token de sesión en almacenamiento seguro
    theme/             colores, fuentes y tema del diseño «Ficha técnica»
    ui/                piezas del diseño (corte, botón, filas con puntos, regla)
    demo/              servidor de prueba en memoria
    providers.dart     ÚNICO lugar que elige demo o API real
  features/
    auth/              ingreso, verificación en dos pasos y sesión
    home/              Inicio del equipo
    catalog/           productos y reglas de precio por mayor
    orders/            ventas y comprobantes
    team/              reglas del bono y del KPI, equipo y «Mi semana»
    warehouse/         despachos, caja del día, stock y conteos
    control/           panel de Jime: resumen, bandeja, cierre, bono, precios
    management/        autorizaciones de Dirección
```

Cada carpeta de `features` separa lo que necesita en `domain/` (modelos, reglas
e interfaz del repositorio), `data/` (contra la API) y `presentation/`
(pantallas).

Las pantallas hablan con interfaces (`AuthRepository`, `OrdersRepository`,
`ReviewRepository`…). `core/providers.dart` elige la implementación según
`API_MODE`. **Todas** ya tienen su versión para la API; la versión de demo existe
para el ingreso, el Inicio y el resumen, y las demás se agregan junto con la
pantalla de su fase (mientras tanto, en modo demo avisan que llegan después).

La app **solo oculta** lo que no corresponde a cada rol. Los permisos de verdad
los tiene que aplicar el backend.

## Pruebas

```powershell
flutter analyze
flutter test
```

- `test/features/team`: reglas del bono y del KPI.
- `test/core`: dinero y servidor de prueba (incluye que las cifras de la demo
  cuadren entre las pantallas).
- `test/data`: la capa HTTP contra un servidor falso, con los ejemplos de
  `docs/api-contract.md`.
- `test/features`: ingreso, verificación, Inicio de cada puesto y Resumen,
  incluso en un celular de 320 de ancho con letra grande.
- `test/app`: barra por rol, acceso a pantallas y cierre de sesión.

`test/flutter_test_config.dart` carga las fuentes de la app para que las
comprobaciones de desborde se parezcan a lo que se ve en el celular.

## Fases

La **capa de datos de todas las fases** (modelos, rutas y repositorios de la
API, con pruebas) ya está lista. Falta construir las pantallas de las fases 2 a 5.

| Fase | Contenido | Pantallas |
|---|---|---|
| 1 | Diseño «Ficha técnica», logo e ícono, ingreso para todos (con verificación para Jime y Dirección), barra por rol, Inicio del equipo y Resumen | Hechas |
| 2 | Catálogo y registrar venta (precio por mayor automático) | Pendientes |
| 3 | Mi semana, equipo, KPI y subir evidencia (pedirá un paquete para la cámara) | Pendientes |
| 4 | Cierre de caja, despachos, stock y entregas técnicas | Pendientes |
| 5 | Panel de Jime y Dirección: pendientes, validaciones, cierre, bonos, comisiones, precios y autorización | Pendientes |

Las pestañas de las fases pendientes muestran una pantalla provisional
(`core/ui/phase_placeholder.dart`) que dice qué habrá ahí.

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
  [docs/api-contract.md](docs/api-contract.md) (pedido mayorista, código del
  segundo paso y comisiones, entre otras).
- **Pantalla de cierre de Jime** (fase 5): debe permitir cerrar como «no cumple»
  a quien siga pendiente, con un motivo. Los mockups todavía no lo muestran.
- **Backend real**: la app aún no se probó contra Laravel.
- **Celular real**: se revisó con pruebas automáticas y capturas, no en un
  dispositivo.
- **Android release**: falta configurar la firma (`signingConfig`).
- **iOS**: renombrada a «Traigo Equipo» (`com.traigo.equipo`) pero sin compilar;
  requiere una Mac.
