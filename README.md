# Traigo Vendedores

App móvil (Flutter, Android e iOS) del equipo de ventas de Traigo Importaciones:
registrar ventas con el precio real, ver comisión personal y fondo del equipo,
consultar stock sincronizado con la tienda y reportar mermas.

## Cómo correrla

Sin backend, con datos de prueba en memoria (por defecto):

```powershell
flutter run
```

Ingresa con el código `ANA-07` y el PIN `1234`.

Contra el backend Laravel:

```powershell
flutter run --dart-define=API_MODE=live --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

`10.0.2.2` es el `localhost` de tu PC visto desde el emulador de Android. En un
celular físico usa la IP de tu PC en la red local (en debug se permite `http`;
en producción debe ser `https`).

Los endpoints que debe ofrecer el backend están en
[docs/api-contract.md](docs/api-contract.md).

## Estructura

```
lib/
  app/                 MaterialApp, rutas (go_router) y barra de pestañas
  core/
    config/            demo vs. API real (--dart-define)
    network/           cliente Dio, errores tipados, rutas de la API
    money/             Money: dinero en centavos, con formato «Bs 86,40»
    storage/           token de sesión en almacenamiento seguro
    theme/             colores y tema del diseño «Feria y live»
    demo/              servidor de prueba en memoria
    providers.dart     ÚNICO lugar que elige demo o API real
  features/
    auth/ catalog/ orders/ home/ stock/ waste/
      domain/          modelos e interfaz del repositorio
      data/            implementación contra la API (Laravel)
      presentation/    pantallas (se completan por fases)
```

Cada feature habla con una interfaz (`CatalogRepository`, `OrdersRepository`, …).
Hay una implementación para la API y otra de prueba; `core/providers.dart` elige
cuál según `API_MODE`. Las pantallas no saben cuál están usando.

## Pruebas

```powershell
flutter analyze
flutter test
```

- `test/data`: la capa HTTP contra un servidor falso, con las mismas respuestas
  de `docs/api-contract.md`.
- `test/core/demo_backend_test.dart`: las reglas de negocio (mínimo, stock,
  idempotencia, cancelación, merma).
- `test/features/auth`: ingreso (código + PIN, último código precargado, error
  de credenciales).
- `test/features/home`: Inicio (comisión de hoy y del mes, fondo del equipo,
  últimas ventas), estados de carga/error, cierre de sesión y navegación.
- `test/features/orders`: cálculo de la comisión (el servidor es quien manda;
  la app solo la estima).

## Fases

| Fase | Contenido | Estado |
|---|---|---|
| 0 | Fundación: red, sesión, modelos, repositorios API y de prueba, rutas, contrato | Hecha |
| 1 | Ingreso con el diseño final, barra de pestañas e Inicio | Hecha |
| 2 | Catálogo y registrar venta (precio, cantidad, cliente, entrega, QR/efectivo) | Pendiente |
| 3 | Mis pedidos, detalle, cancelar y subir comprobante con la cámara | Pendiente |
| 4 | Stock y registrar merma | Pendiente |
| 5 | Pulido: estados vacíos y de error, ícono, logo real, prueba en celular real | Pendiente |

En las pestañas de las fases pendientes se ve una pantalla provisional
(`core/ui/phase_placeholder.dart`) que dice qué falta; la barra inferior y las
rutas ya están completas.

## Fuentes

Las fuentes van dentro de la app (no se descargan al abrirla), en `assets/fonts`
y declaradas en `pubspec.yaml`. Ambas tienen licencia OFL y vienen de Google
Fonts:

- **Archivo** (variable, pesos 400–800): textos y títulos.
- **Space Mono** (regular y bold): códigos de producto y de vendedor.

## Pendientes conocidos

- **Logo e ícono**: no hay archivo del logo; en el ingreso se dibuja un marcador
  provisional y el ícono de la app es el de Flutter.
- **Android release**: falta configurar la firma (`signingConfig`).
- **iOS**: renombrado a «Traigo Vendedores» (`com.traigo.vendedores`) pero sin
  compilar ni probar en un dispositivo; requiere una Mac.
- **Backend real**: la app aún no se probó contra Laravel; las decisiones
  abiertas están en la sección 11 de [docs/api-contract.md](docs/api-contract.md).
