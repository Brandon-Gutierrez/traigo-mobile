import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'error_panel.dart';
import 'refreshable_page.dart';
import 'skeleton_block.dart';

/// Una pantalla que carga datos de [provider]: los muestra, permite
/// actualizar deslizando y, si fallan, ofrece reintentar.
class AsyncPage<T> extends ConsumerWidget {
  const AsyncPage({
    super.key,
    required this.provider,
    required this.builder,
    this.header = const [],
  });

  final FutureProvider<T> provider;

  /// Lo que se ve aunque todavía esté cargando (volver y título).
  final List<Widget> header;
  final List<Widget> Function(BuildContext context, WidgetRef ref, T data) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(provider);
    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(provider);
        return ref.read(provider.future);
      },
      children: [
        ...header,
        ...value.when(
          // Al actualizar no se borra lo que ya estaba (ni lo escrito).
          skipLoadingOnRefresh: true,
          data: (data) => builder(context, ref, data),
          loading: () => const [
            SizedBox(height: 8),
            SkeletonBlock(height: 110),
            SizedBox(height: 12),
            SkeletonBlock(height: 160),
          ],
          error: (error, _) => [
            const SizedBox(height: 8),
            ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(provider),
            ),
          ],
        ),
      ],
    );
  }
}

/// El título de una pantalla y, debajo, su línea en letra de máquina.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle, this.size = 30});

  final String title;
  final String? subtitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppText.display(size, height: 1.15)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle.toUpperCase(), style: AppText.mono(12, color: AppColors.muted)),
        ],
      ],
    );
  }
}
