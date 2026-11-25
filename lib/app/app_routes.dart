/// Rutas de la app. En un archivo aparte para que las pantallas puedan
/// navegar sin depender del router completo.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const verify = '/verify';

  // Equipo
  static const home = '/home';
  static const catalog = '/catalog';
  static const sell = '/sell';
  static const cash = '/cash';
  static const evidence = '/evidence';
  static const team = '/team';
  static const week = '/week';

  // Jime y Dirección
  static const summary = '/control';
  static const pending = '/pending';
  static const close = '/close';
  static const bonuses = '/bonuses';
  static const commissions = '/commissions';
  static const approve = '/approve';
  static const more = '/more';

  // Pantallas dentro de una pestaña
  static String product(String id) => '$catalog/$id';
  static const sellAdd = '$sell/add';
  static const sellCustomer = '$sell/customer';

  /// Almacén, desde el Inicio.
  static const dispatches = '$home/dispatches';
  static const stock = '$home/stock';
  static const stockCounts = '$stock?tab=counts';
  static String stockProduct(String id) => '$stock/products/$id';
  static const newCount = '$stock/counts/new';
  static const newCountAdd = '$newCount/add';
  static String count(String id) => '$stock/counts/$id';

  /// La caja de un día anterior.
  static String cashDay(DateTime date) => '$cash/day/'
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// «Mis pedidos» (solo quienes venden).
  static const orders = '$home/orders';
  static String order(String id) => '$orders/$id';

  /// La evidencia de un indicador y una entrega de Sistemas, dentro de
  /// «Mi semana» o de «Evidencia» ([tab]). [weekNumber] para semanas pasadas.
  static String indicator(String tab, String id, {int? weekNumber}) =>
      _inWeek('$tab/indicator/$id', weekNumber);
  static String deliverable(String tab, String id, {int? weekNumber}) =>
      _inWeek('$tab/deliverable/$id', weekNumber);

  static String _inWeek(String path, int? weekNumber) =>
      weekNumber == null ? path : '$path?week=$weekNumber';

  /// Pestañas de la barra inferior. Su orden es el de las ramas del router.
  static const tabs = [
    home,
    catalog,
    sell,
    cash,
    evidence,
    team,
    week,
    summary,
    pending,
    close,
    bonuses,
    commissions,
    approve,
    more,
  ];
}
