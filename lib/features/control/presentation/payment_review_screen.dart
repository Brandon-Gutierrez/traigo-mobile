import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/dialogs.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../orders/domain/orders.dart';
import '../../team/presentation/week_widgets.dart'
    show SideNote, attachmentImage, attachmentName;
import '../application/control_providers.dart';
import '../domain/review.dart';
import 'panel_widgets.dart';

/// Conciliar un comprobante: monto, referencia y cuenta destino.
class PaymentReviewScreen extends StatelessWidget {
  const PaymentReviewScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: paymentReviewProvider(paymentId),
      header: [BackLink('Pendientes', onTap: () => context.go(AppRoutes.pending))],
      builder: (context, ref, payment) => [
        _PaymentBody(payment, key: ValueKey(payment.id)),
      ],
    );
  }
}

class _PaymentBody extends ConsumerStatefulWidget {
  const _PaymentBody(this.payment, {super.key});

  final PaymentReview payment;

  @override
  ConsumerState<_PaymentBody> createState() => _PaymentBodyState();
}

class _PaymentBodyState extends ConsumerState<_PaymentBody> {
  bool _amountMatches = false;
  bool _destinationOk = false;

  PaymentReview get _payment => widget.payment;

  Future<void> _confirm() async {
    final payment = _payment;
    final ok = await runPanelAction(
      context,
      () => ref.read(reviewRepositoryProvider).confirmPayment(
            payment.id,
            amountMatches: _amountMatches,
            destinationOk: _destinationOk,
          ),
      success: 'Pago de ${payment.orderNumber} confirmado.',
    );
    if (ok && mounted) context.go(AppRoutes.pending);
  }

  Future<void> _reject() async {
    final reason = await askReason(
      context,
      title: '¿Rechazar el comprobante?',
      body: 'El pedido vuelve a «Por pagar» y quien vende ve el motivo.',
      label: 'Motivo',
      action: 'Rechazar',
      destructive: true,
    );
    if (reason == null || !mounted) return;
    final ok = await runPanelAction(
      context,
      () => ref.read(reviewRepositoryProvider).rejectPayment(_payment.id, reason: reason),
      success: 'Comprobante rechazado.',
    );
    if (ok && mounted) context.go(AppRoutes.pending);
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;
    final now = ref.watch(nowProvider)();
    final reference = payment.reference;
    final submitted = payment.submittedAt;
    final waiting = payment.status == PaymentStatus.submitted;
    final seller = payment.sellerName == null ? 'Tienda web' : 'Vende ${payment.sellerName}';

    final String? blocked;
    if (!payment.referenceUnique) {
      blocked = 'La referencia ya se usó';
    } else if (!_amountMatches || !_destinationOk) {
      blocked = 'Marca el monto y la cuenta';
    } else {
      blocked = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          [payment.orderNumber, if (submitted != null) timeAgo(submitted, now)]
              .join(' · ')
              .toUpperCase(),
          style: AppText.mono(12, color: AppColors.muted),
        ),
        Text(payment.customerName, style: AppText.display(26, height: 1.15)),
        const SizedBox(height: 2),
        Text(
          '$seller · ${payment.itemsLabel}',
          style: AppText.body(14, FontWeight.w400, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        _Proof(payment.proofUrl),
        if (payment.proofUrl case final url? when attachmentImage(url) != null) ...[
          const SizedBox(height: 4),
          const HintText('Toca la foto para ampliarla.'),
        ],
        const SizedBox(height: 10),
        CheckRow(
          label: 'Referencia',
          value: reference ?? 'Sin número',
          mark: StatusMark(
            reference == null
                ? MarkKind.pending
                : (payment.referenceUnique ? MarkKind.ok : MarkKind.bad),
            reference == null
                ? 'Revísala en la foto'
                : (payment.referenceUnique ? 'No se repite' : 'Ya se usó'),
          ),
        ),
        _TickRow(
          checked: _amountMatches,
          title: 'El monto es ${payment.orderTotal.formatInline()}',
          detail: 'El comprobante coincide con el pedido (${payment.method.label}).',
          onChanged: waiting ? (v) => setState(() => _amountMatches = v) : null,
        ),
        _TickRow(
          checked: _destinationOk,
          title: 'Llegó a la cuenta de ${payment.destinationAccount ?? 'Traigo'}',
          detail: 'La cuenta destino es la correcta.',
          onChanged: waiting ? (v) => setState(() => _destinationOk = v) : null,
        ),
        const SizedBox(height: 8),
        const HintText(
          'Solo se confirma un cobro con respaldo. Al confirmar, el pedido pasa a '
          '«Pagado» y cuenta para el bono de la semana.',
        ),
        const SizedBox(height: 10),
        if (waiting) ...[
          ActionButton(
            label: blocked ?? 'Confirmar pago',
            onPressed: blocked == null ? _confirm : null,
          ),
          Center(
            child: TextLink('Rechazar comprobante…', color: AppColors.ink, onTap: _reject),
          ),
        ] else
          SideNote(
            payment.status == PaymentStatus.rejected
                ? 'Rechazado: ${payment.rejectReason}'
                : 'Este pago ya se revisó.',
            alert: payment.status == PaymentStatus.rejected,
          ),
      ],
    );
  }
}

class _TickRow extends StatelessWidget {
  const _TickRow({
    required this.checked,
    required this.title,
    required this.detail,
    required this.onChanged,
  });

  final bool checked;
  final String title;
  final String detail;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
      ),
      child: Row(
        children: [
          SquareCheck(checked: checked, onChanged: onChanged, label: title),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(15, FontWeight.w600, height: 1.2)),
                Text(detail, style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La foto del comprobante; al tocarla se ve grande.
class _Proof extends StatelessWidget {
  const _Proof(this.url);

  final String? url;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url == null) return const SideNote('Este pago no tiene comprobante.', alert: true);
    final image = attachmentImage(url);
    final placeholder = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.image_outlined, size: 40, color: AppColors.muted),
        const SizedBox(height: 6),
        Text(attachmentName(url), style: AppText.mono(12, color: AppColors.muted)),
      ],
    );
    return ChamferBox(
      color: AppColors.alt,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 190,
        child: image == null
            ? placeholder
            : InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    insetPadding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: InteractiveViewer(child: Image(image: image))),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  ),
                ),
                child: Semantics(
                  button: true,
                  label: 'Ver el comprobante en grande',
                  child: Image(
                    image: image,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => placeholder,
                  ),
                ),
              ),
      ),
    );
  }
}
