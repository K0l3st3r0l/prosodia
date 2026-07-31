import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import 'formatting.dart';
import 'surfaces.dart';

/// Envuelve en scroll solo cuando el widget es dueño de su altura.
class _MaybeScrollable extends StatelessWidget {
  const _MaybeScrollable({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      enabled ? SingleChildScrollView(child: child) : child;
}

/// Estado inicial: todavía no hay curso, estudiante o lectura elegidos.
///
/// Va dentro de un scroll: con `textScaler` a 1.3 el bloque pasa de ~300 a
/// ~380 dp y no cabe en el panel de un teléfono en landscape.
class AssessmentEmptyState extends StatelessWidget {
  const AssessmentEmptyState({
    super.key,
    required this.prompt,
    required this.hasCurso,
    required this.hasStudent,
    required this.hasReading,
    required this.fillHeight,
    this.showStudent = true,
  });

  final String prompt;
  final bool hasCurso;
  final bool hasStudent;
  final bool hasReading;

  /// El modo prueba no tiene paso de estudiante.
  final bool showStudent;

  /// `true` cuando el widget recibe altura acotada y hace scroll por su cuenta.
  /// En composición apilada el scroll lo pone el padre y anidar dos
  /// `SingleChildScrollView` en el mismo eje revienta el layout.
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return _MaybeScrollable(
      enabled: fillHeight,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.proseMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(size: r.isShortViewport ? 56 : 88),
              SizedBox(height: r.spacing.xl),
              Text(
                'Todo listo para comenzar',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(height: r.spacing.md),
              Text(
                prompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.muted,
                  height: 1.5,
                ),
              ),
              SizedBox(height: r.spacing.xl),
              WorkflowChips(
                hasCurso: hasCurso,
                hasStudent: hasStudent,
                hasReading: hasReading,
                showStudent: showStudent,
                alignment: WrapAlignment.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whisper está transcribiendo la grabación.
class AnalyzingPanel extends StatelessWidget {
  const AnalyzingPanel({
    super.key,
    required this.elapsed,
    required this.fillHeight,
  });

  final Duration elapsed;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final diameter = r.isShortViewport ? 64.0 : 92.0;

    return _MaybeScrollable(
      enabled: fillHeight,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.proseMaxWidth),
          child: SectionCard(
            title: 'Analizando lectura',
            subtitle:
                'Estamos procesando la grabación y estimando palabras leídas, '
                'errores y transcripción.',
            icon: Icons.auto_awesome_rounded,
            backgroundColor: AppTheme.surfaceAlt,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: diameter,
                  height: diameter,
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceStrong,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(diameter * 0.24),
                    child: const CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                    ),
                  ),
                ),
                SizedBox(height: r.spacing.lg),
                Text(
                  'Transcribiendo audio de ${formatElapsed(elapsed)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.primary,
                  ),
                ),
                SizedBox(height: r.spacing.sm),
                Text(
                  'Puedes continuar en cuanto termine el análisis.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
