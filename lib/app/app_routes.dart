/// Rutas de la app. En un archivo aparte para que las pantallas puedan
/// navegar sin depender del router completo.
abstract final class AppRoutes {
  static const attendance = '/asistencia';
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

  /// Cumplimiento, desde el Resumen: la semana de cada integrante y la
  /// evidencia de un indicador suyo.
  static const compliance = '$summary/compliance';
  static String complianceWeek(int? weekNumber) => _inWeek(compliance, weekNumber);
  static String complianceMember(String memberId, {int? weekNumber}) =>
      _inWeek('$compliance/$memberId', weekNumber);
  static String complianceIndicator(String memberId, String resultId, {int? weekNumber}) =>
      _inWeek('$compliance/$memberId/indicator/$resultId', weekNumber);

  /// El cierre y el bono de una semana; sin número, la que toca.
  static String closeWeek(int? weekNumber) => _inWeek(close, weekNumber);
  static String bonusesWeek(int? weekNumber) => _inWeek(bonuses, weekNumber);

  /// La bandeja de Jime y cada cosa por revisar.
  static String pendingOfType(String type) => '$pending?type=$type';
  static String pendingPayment(String id) => '$pending/payment/$id';
  static String pendingEvidence(String resultId) => '$pending/evidence/$resultId';
  static String pendingCash(String id) => '$pending/cash/$id';
  static const pendingDeliverables = '$pending/deliverables';
  static String pendingDeliverable(String id) => '$pendingDeliverables/$id';

  /// Lo que hay dentro de «Más».
  static const moreDeliverables = '$more/deliverables';
  static String moreDeliverable(String id) => '$moreDeliverables/$id';
  static const morePrices = '$more/prices';
  static String morePrice(String productId) => '$morePrices/$productId';
  static const moreCommissions = '$more/commissions';
  static const moreCounts = '$more/counts';
  static String moreCount(String id) => '$moreCounts/$id';
  static const moreOrders = '$more/orders';
  static String moreOrder(String id) => '$moreOrders/$id';
  static const moreAudit = '$more/audit';
  static const moreAccess = '$more/access';

  /// Una autorización de Dirección.
  static String authorization(String type, String id) => '$approve/$type/$id';

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
