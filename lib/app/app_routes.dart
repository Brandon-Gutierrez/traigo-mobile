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
