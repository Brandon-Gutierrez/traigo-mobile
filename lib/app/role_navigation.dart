import 'package:flutter/material.dart';

import '../features/auth/domain/auth.dart';
import 'app_routes.dart';

/// Una pestaña de la barra inferior.
class NavItem {
  const NavItem(
    this.label,
    this.icon,
    this.route, {
    this.central = false,
    this.showsPending = false,
  });

  final String label;
  final IconData icon;
  final String route;

  /// La acción principal del rol: botón violeta elevado al centro.
  final bool central;

  /// Lleva el número de cosas por revisar.
  final bool showsPending;

  /// Rama del router que muestra esta pestaña.
  int get branch => AppRoutes.tabs.indexOf(route);
}

const _home = NavItem('Inicio', Icons.home_outlined, AppRoutes.home);
const _catalog = NavItem('Catálogo', Icons.grid_view_outlined, AppRoutes.catalog);
const _team = NavItem('Equipo', Icons.groups_outlined, AppRoutes.team);
const _week = NavItem('Mi semana', Icons.checklist, AppRoutes.week);

const _summary = NavItem('Resumen', Icons.home_outlined, AppRoutes.summary);
const _bonuses = NavItem('Bonos', Icons.redeem_outlined, AppRoutes.bonuses);
const _more = NavItem('Más', Icons.menu, AppRoutes.more);

/// La barra de cada rol, de izquierda a derecha. También define a qué
/// pantallas puede entrar.
List<NavItem> navItemsFor(MemberRole role) {
  List<NavItem> member(NavItem central) => [_home, _catalog, central, _team, _week];

  return switch (role) {
    MemberRole.seller || MemberRole.wholesale => member(
        const NavItem('Vender', Icons.add, AppRoutes.sell, central: true),
      ),
    MemberRole.warehouse => member(
        const NavItem('Caja', Icons.payments_outlined, AppRoutes.cash, central: true),
      ),
    MemberRole.content || MemberRole.systems => member(
        const NavItem('Evidencia', Icons.photo_camera_outlined, AppRoutes.evidence, central: true),
      ),
    MemberRole.control => const [
        _summary,
        NavItem('Pendientes', Icons.inbox_outlined, AppRoutes.pending, showsPending: true),
        NavItem('Cierre', Icons.lock_outline, AppRoutes.close, central: true),
        _bonuses,
        _more,
      ],
    MemberRole.management => const [
        _summary,
        _bonuses,
        NavItem('Autorizar', Icons.verified_user_outlined, AppRoutes.approve, central: true),
        NavItem('Comisiones', Icons.monetization_on_outlined, AppRoutes.commissions),
        _more,
      ],
  };
}

/// Pantalla a la que llega cada rol al ingresar.
String startRouteFor(MemberRole role) =>
    role.isControlSide ? AppRoutes.summary : AppRoutes.home;
