import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/dialogs.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../application/control_providers.dart';
import '../domain/admin.dart';
import 'panel_widgets.dart';

/// Para quien olvidó su PIN o perdió el celular. Solo las cuentas del equipo:
/// las de Jime y Dirección las cambia quien administra el servidor.
class AccessScreen extends StatelessWidget {
  const AccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: teamAccountsProvider,
      header: [
        BackLink('Más', onTap: () => context.go(AppRoutes.more)),
        const PageTitle('Accesos del equipo', size: 28),
        const SizedBox(height: 4),
        const HintText('PIN nuevo si alguien lo olvidó; cerrar sesiones si perdió el celular.'),
        const SizedBox(height: 10),
      ],
      builder: (context, ref, accounts) => [
        for (final account in accounts) _Account(account),
        const SizedBox(height: 8),
        const HintText(
          'Los accesos de Jime y Dirección los cambia quien administra el servidor.',
        ),
      ],
    );
  }
}

class _Account extends ConsumerWidget {
  const _Account(this.account);

  final TeamAccount account;

  Future<void> _newPin(BuildContext context, WidgetRef ref) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => _PinDialog(account.name),
    );
    if (pin == null || !context.mounted) return;
    await runPanelAction(
      context,
      () => ref.read(adminRepositoryProvider).resetPin(account.id, pin),
      success: 'PIN actualizado. Dáselo en persona.',
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      title: '¿Cerrar las sesiones de ${account.name}?',
      body: 'En todos sus celulares tendrá que ingresar otra vez con su código y PIN.',
      action: 'Cerrar sesiones',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runPanelAction(
      context,
      () => ref.read(adminRepositoryProvider).revokeSessions(account.id),
      success: 'Sesiones de ${account.name} cerradas.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: ValueKey('account-${account.id}'),
      padding: const EdgeInsets.only(top: 9, bottom: 2),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(account.name, style: AppText.display(18)),
          Text(
            '${account.code} · ${account.title}',
            style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted),
          ),
          Wrap(
            spacing: 18,
            children: [
              TextLink('Nuevo PIN', onTap: () => _newPin(context, ref)),
              TextLink(
                'Cerrar sesiones',
                color: AppColors.ink,
                onTap: () => _revoke(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// El PIN se escribe dos veces para no dejarlo mal.
class _PinDialog extends StatefulWidget {
  const _PinDialog(this.name);

  final String name;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _pin = TextEditingController();
  final _repeat = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Widget _field(String label, TextEditingController controller) => Labeled(
        label,
        child: Semantics(
          label: label,
          child: TextField(
            key: ValueKey('field-$label'),
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            enableSuggestions: false,
            autocorrect: false,
            style: AppText.mono(20, weight: FontWeight.w700),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            onChanged: (_) => setState(() {}),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final complete = _pin.text.length == 4 && _repeat.text.length == 4;
    final matches = complete && _pin.text == _repeat.text;
    return AlertDialog(
      title: Text('PIN nuevo para ${widget.name}'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Se cierran sus sesiones. Díselo en persona, no por mensaje.'),
          const SizedBox(height: 12),
          _field('PIN nuevo (4 dígitos)', _pin),
          const SizedBox(height: 10),
          _field('Repite el PIN', _repeat),
          if (complete && !matches) ...[
            const SizedBox(height: 6),
            Text(
              'No coinciden.',
              style: AppText.body(13, FontWeight.w600, color: AppColors.alert),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Volver')),
        TextButton(
          onPressed: matches ? () => Navigator.pop(context, _pin.text) : null,
          child: const Text('Cambiar PIN'),
        ),
      ],
    );
  }
}
