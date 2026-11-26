/// Los precios autorizados: Jime propone cambios y Dirección los aprueba.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/money/money.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/dialogs.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth.dart';
import '../../catalog/presentation/catalog_browser.dart';
import '../application/control_providers.dart';
import '../domain/admin.dart';
import 'panel_widgets.dart';

class PriceListScreen extends StatelessWidget {
  const PriceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogBrowser(
      header: [
        BackLink('Más', onTap: () => context.go(AppRoutes.more)),
        const PageTitle('Precios autorizados', size: 28),
      ],
      onSelect: (item) => context.go(AppRoutes.morePrice(item.id)),
    );
  }
}

class PriceScreen extends StatelessWidget {
  const PriceScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: priceSheetProvider(productId),
      header: [BackLink('Precios', onTap: () => context.go(AppRoutes.morePrices))],
      builder: (context, ref, sheet) {
        final role = ref.watch(sessionControllerProvider).value?.member.role;
        final pending = sheet.pendingChange;
        return [
          Text('${sheet.itemCode} · ${sheet.category}'.toUpperCase(),
              style: AppText.mono(12, color: AppColors.muted)),
          Text(sheet.name, style: AppText.display(26, height: 1.15)),
          const SizedBox(height: 10),
          if (pending != null) ...[
            _PendingChange(pending, sheet.current),
            if (role == MemberRole.management) ...[
              const SizedBox(height: 10),
              CutButton(
                label: 'Revisar y autorizar',
                onPressed: () =>
                    context.go(AppRoutes.authorization('price_change', pending.id)),
              ),
            ],
          ] else if (role == MemberRole.control)
            // Si cambian los precios vigentes, el formulario se rellena de nuevo.
            _PriceForm(
              sheet,
              key: ValueKey((
                sheet.productId,
                sheet.current.priceUnit,
                sheet.current.priceWholesale,
                sheet.current.wholesaleMinQty,
                sheet.current.commissionPct,
                sheet.current.cost,
              )),
            )
          else
            _Current(sheet.current),
        ];
      },
    );
  }
}

String _rate(double? value) =>
    value == null ? 'Por definir' : '${value == value.roundToDouble() ? value.round() : value} %';

class _Current extends StatelessWidget {
  const _Current(this.values);

  final PriceValues values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Precios vigentes'),
        LeaderRow('Minorista', values.priceUnit?.format() ?? '—'),
        LeaderRow('Mayorista', values.priceWholesale?.format() ?? '—'),
        LeaderRow('Mínimo mayorista', '${values.wholesaleMinQty ?? '—'} u.'),
        LeaderRow('Comisión', _rate(values.commissionPct)),
        LeaderRow('Costo', values.cost?.format() ?? 'Sin definir'),
      ],
    );
  }
}

class _PendingChange extends ConsumerWidget {
  const _PendingChange(this.change, this.current);

  final PriceChange change;
  final PriceValues current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = change.proposed;
    String money(Money? m) => m?.format() ?? '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Esperando a Dirección'),
        if (p.priceUnit != null)
          LeaderRow('Minorista', '${money(current.priceUnit)} → ${money(p.priceUnit)}'),
        if (p.priceWholesale != null)
          LeaderRow(
              'Mayorista', '${money(current.priceWholesale)} → ${money(p.priceWholesale)}'),
        if (p.wholesaleMinQty != null)
          LeaderRow('Mínimo mayorista',
              '${current.wholesaleMinQty} → ${p.wholesaleMinQty} u.'),
        if (p.commissionPct != null)
          LeaderRow('Comisión', '${_rate(current.commissionPct)} → ${_rate(p.commissionPct)}'),
        if (p.cost != null) LeaderRow('Costo', '${money(current.cost)} → ${money(p.cost)}'),
        const SizedBox(height: 4),
        HintText(
          'Lo pidió ${change.requestedBy} '
          '${timeAgo(change.requestedAt, ref.watch(nowProvider)())}'
          '${change.reason == null ? '' : ': ${change.reason}'}. Mientras tanto se '
          'vende con los precios de siempre.',
        ),
        const SizedBox(height: 10),
        _Current(current),
      ],
    );
  }
}

class _PriceForm extends ConsumerStatefulWidget {
  const _PriceForm(this.sheet, {super.key});

  final PriceSheet sheet;

  @override
  ConsumerState<_PriceForm> createState() => _PriceFormState();
}

class _PriceFormState extends ConsumerState<_PriceForm> {
  PriceValues get _current => widget.sheet.current;

  late final _unit = TextEditingController(text: _money(_current.priceUnit));
  late final _wholesale = TextEditingController(text: _money(_current.priceWholesale));
  late final _minimum =
      TextEditingController(text: _current.wholesaleMinQty?.toString() ?? '');
  late final _commission = TextEditingController(
    text: _current.commissionPct == null
        ? ''
        : _rate(_current.commissionPct).replaceAll(' %', ''),
  );
  late final _cost = TextEditingController(text: _money(_current.cost));
  final _reason = TextEditingController();

  static String _money(Money? m) => m?.format(symbol: false) ?? '';

  @override
  void dispose() {
    for (final c in [_unit, _wholesale, _minimum, _commission, _cost, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Solo lo que cambió, o el motivo por el que no se puede enviar.
  (PriceValues?, String?) _changes() {
    Money? money(TextEditingController c) => Money.tryParseInput(c.text);
    final unit = money(_unit);
    final wholesale = money(_wholesale);
    final minimum = int.tryParse(_minimum.text);
    final commissionText = _commission.text.trim().replaceFirst(',', '.');
    final commission = commissionText.isEmpty ? null : double.tryParse(commissionText);
    final cost = _cost.text.trim().isEmpty ? null : money(_cost);

    if (unit == null || wholesale == null || minimum == null) {
      return (null, 'Completa precios y mínimo');
    }
    if (minimum < 2) return (null, 'El mínimo por mayor es desde 2 u.');
    if (unit.isZero || wholesale.isZero) return (null, 'El precio no puede ser cero');
    if (wholesale > unit) return (null, 'El mayorista no supera al minorista');
    if (commissionText.isNotEmpty &&
        (commission == null || commission < 0 || commission > 100)) {
      return (null, 'La comisión va de 0 a 100');
    }
    if (_cost.text.trim().isNotEmpty && cost == null) return (null, 'Revisa el costo');

    final changes = PriceValues(
      priceUnit: unit == _current.priceUnit ? null : unit,
      priceWholesale: wholesale == _current.priceWholesale ? null : wholesale,
      wholesaleMinQty: minimum == _current.wholesaleMinQty ? null : minimum,
      commissionPct: commission == _current.commissionPct ? null : commission,
      cost: cost == _current.cost ? null : cost,
    );
    final nothing = changes.priceUnit == null &&
        changes.priceWholesale == null &&
        changes.wholesaleMinQty == null &&
        changes.commissionPct == null &&
        changes.cost == null;
    return nothing ? (null, 'No hay cambios') : (changes, null);
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    bool decimals = true,
  }) =>
      LabeledField(
        label: label,
        controller: controller,
        mono: true,
        hint: hint,
        keyboardType: TextInputType.numberWithOptions(decimal: decimals),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(decimals ? r'[0-9.,]' : r'[0-9]')),
          LengthLimitingTextInputFormatter(10),
        ],
        onChanged: (_) => setState(() {}),
      );

  Widget _pair(Widget a, Widget b) => LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 300
            ? Column(children: [a, const SizedBox(height: 10), b])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
              ),
      );

  Future<void> _send(PriceValues changes) async {
    final reason = _reason.text.trim();
    await runPanelAction(
      context,
      () => ref.read(adminRepositoryProvider).proposePrice(
            widget.sheet.productId,
            changes,
            reason: reason.isEmpty ? null : reason,
          ),
      success: 'Enviado a Dirección.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final (changes, blocked) = _changes();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pair(_field('Minorista (Bs)', _unit), _field('Mayorista (Bs)', _wholesale)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: HintText('Antes: ${_current.priceUnit?.formatInline() ?? '—'}')),
            const SizedBox(width: 12),
            Expanded(
              child: HintText('Antes: ${_current.priceWholesale?.formatInline() ?? '—'}'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _pair(
          _field('Mínimo mayorista (u.)', _minimum, decimals: false),
          _field('Comisión (%)', _commission, hint: 'Por definir'),
        ),
        const SizedBox(height: 10),
        _field('Costo (Bs)', _cost, hint: 'Solo Jime y Dirección'),
        const SizedBox(height: 10),
        LabeledField(
          label: 'Motivo (opcional)',
          controller: _reason,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(300)],
        ),
        const SizedBox(height: 12),
        ChamferBox(
          color: AppColors.alt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('QUÉ PASA AL ENVIAR', style: AppText.label()),
              const SizedBox(height: 4),
              Text(
                'El cambio espera a Dirección y queda con tu nombre y la hora. Las '
                'ventas ya registradas conservan su precio. Si defines la comisión, '
                'las ventas sin % de este producto que no se liquidaron la toman al '
                'aprobarse.',
                style: AppText.body(13.5, FontWeight.w400, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ActionButton(
          label: blocked ?? 'Enviar a Dirección',
          onPressed: changes == null ? null : () => _send(changes),
        ),
      ],
    );
  }
}
