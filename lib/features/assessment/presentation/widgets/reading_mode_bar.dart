import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../eval_state.dart';
import 'formatting.dart';

/// Barra del **modo foco** de teléfono: reemplaza a `AssessmentAppBar` mientras
/// hay una lectura abierta.
///
/// El logo, la versión, el estado y los tres botones de acción (actualizar,
/// sincronizar, salir) no sirven de nada mientras un niño lee en voz alta bajo
/// cronómetro, y en un teléfono en landscape cada dp de alto que ocupan se lo
/// quitan al texto. Esta barra deja solo las dos cosas que el docente sí usa en
/// ese momento —el tiempo y el control de grabación— y devuelve el resto de la
/// pantalla a la lectura.
///
/// El cronómetro sigue visible en la revisión: el docente necesita el tiempo
/// mientras ajusta palabras leídas y errores, porque de ahí sale el PCPM.
class ReadingModeBar extends StatelessWidget implements PreferredSizeWidget {
  const ReadingModeBar({
    super.key,
    required this.height,
    required this.elapsed,
    required this.state,
    required this.onStart,
    required this.onStop,
    required this.onRepeat,
    required this.onChangeReading,
  });

  /// Llega por parámetro y no desde `context.responsive` porque `Scaffold` lee
  /// [preferredSize] —un getter sin `BuildContext`— para reservar el espacio de
  /// la barra: si la altura declarada y la usada divergen, queda una franja
  /// vacía o el contenido se recorta. Mismo criterio que `AssessmentAppBar`.
  final double height;

  final Duration elapsed;
  final EvalState state;
  final VoidCallback onStart;
  final VoidCallback onStop;

  /// Vuelve a dejar la sesión en cero conservando alumno y lectura, para
  /// evaluar de nuevo al mismo niño con el mismo texto.
  final VoidCallback onRepeat;

  /// `null` deshabilita el cambio de lectura. Se corta fuera de `idle`: cambiar
  /// el texto con la grabación andando dejaría la medición sin referencia.
  final VoidCallback? onChangeReading;

  static const double compactHeight = 64;
  static const double regularHeight = 76;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final recording = state == EvalState.recording;

    return Material(
      color: recording ? AppTheme.dangerSurface : AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.spacing.md),
            child: Row(
              children: [
                _Elapsed(elapsed: elapsed, recording: recording),
                if (onChangeReading != null) ...[
                  SizedBox(width: r.spacing.sm),
                  IconButton(
                    onPressed: onChangeReading,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    color: AppTheme.muted,
                    tooltip: 'Cambiar lectura',
                    // La barra reemplaza al AppBar, así que esta es la única
                    // salida de la lectura: no puede quedar bajo el mínimo
                    // táctil aunque el alto esté apretado.
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ],
                const Spacer(),
                _Action(
                  state: state,
                  onStart: onStart,
                  onStop: onStop,
                  onRepeat: onRepeat,
                  textTheme: theme.textTheme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Elapsed extends StatelessWidget {
  const _Elapsed({required this.elapsed, required this.recording});

  final Duration elapsed;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final color = recording ? AppTheme.danger : AppTheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          recording ? Icons.fiber_manual_record_rounded : Icons.timer_outlined,
          size: r.type.iconMd,
          color: color,
        ),
        SizedBox(width: r.spacing.xs),
        Semantics(
          label: 'Tiempo transcurrido',
          value: formatElapsed(elapsed),
          child: ExcludeSemantics(
            child: Text(
              formatElapsed(elapsed),
              // `titleLarge` y no el rol del cronómetro grande: acá la cifra
              // comparte una franja de ~64 dp con el botón de acción, no tiene
              // una tarjeta para ella sola.
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.state,
    required this.onStart,
    required this.onStop,
    required this.onRepeat,
    required this.textTheme,
  });

  final EvalState state;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRepeat;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    if (state == EvalState.analyzing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: r.type.iconMd,
            height: r.type.iconMd,
            child: const CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: r.spacing.sm),
          Text('Analizando…', style: textTheme.labelLarge),
        ],
      );
    }

    final (label, icon, background) = switch (state) {
      EvalState.recording => (
        'Detener lectura',
        Icons.stop_rounded,
        AppTheme.danger,
      ),
      EvalState.reviewing => (
        'Repetir',
        Icons.replay_rounded,
        AppTheme.primary,
      ),
      _ => ('Iniciar evaluación', Icons.mic_rounded, AppTheme.tertiary),
    };

    final onPressed = switch (state) {
      EvalState.recording => onStop,
      EvalState.reviewing => onRepeat,
      _ => onStart,
    };

    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: r.type.iconMd),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: EdgeInsets.symmetric(horizontal: r.spacing.lg),
      ),
    );
  }
}
