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
///
/// El control de tamaño del texto solo aparece en [EvalState.idle]. Cambiar el
/// tamaño con la grabación andando movería las condiciones de medición **en
/// medio de la medición**, y `readingCpl` guarda el último valor al cerrar la
/// sesión: la evaluación quedaría registrada con condiciones que solo
/// describen su tramo final.
class ReadingModeBar extends StatefulWidget implements PreferredSizeWidget {
  const ReadingModeBar({
    super.key,
    required this.height,
    required this.elapsed,
    required this.state,
    required this.onStart,
    required this.onStop,
    required this.onRepeat,
    required this.onChangeReading,
    this.sizePosition,
    this.onSizePositionChanged,
  });

  /// Posición actual del control de tamaño, o `null` si el docente todavía no
  /// lo ha tocado y el texto usa el tamaño nominal.
  final double? sizePosition;

  /// `null` oculta el control por completo. La pantalla lo pasa solo cuando ya
  /// midió el ancho útil del texto: sin ese ancho no hay con qué calcular los
  /// topes del rango legible.
  final ValueChanged<double>? onSizePositionChanged;

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
  State<ReadingModeBar> createState() => _ReadingModeBarState();
}

class _ReadingModeBarState extends State<ReadingModeBar> {
  /// La barra se transforma en el control en vez de abrir un menú flotante: un
  /// popover taparía el texto justo cuando hay que ver cómo queda al arrastrar.
  bool _adjusting = false;

  @override
  void didUpdateWidget(ReadingModeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Salir de `idle` cierra el control: no se ajusta el tamaño con la
    // grabación andando (ver la doc de la clase).
    if (widget.state != EvalState.idle && _adjusting) _adjusting = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final state = widget.state;
    final elapsed = widget.elapsed;
    final onChangeReading = widget.onChangeReading;
    final recording = state == EvalState.recording;
    final puedeAjustar =
        widget.onSizePositionChanged != null && state == EvalState.idle;

    return Material(
      color: recording ? AppTheme.dangerSurface : AppTheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: widget.height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.spacing.md),
            child: _adjusting
                ? _SizeControl(
                    position: widget.sizePosition ?? 0.5,
                    onChanged: widget.onSizePositionChanged!,
                    onDone: () => setState(() => _adjusting = false),
                  )
                : Row(
                    children: [
                      if (onChangeReading != null) ...[
                        IconButton(
                          onPressed: onChangeReading,
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AppTheme.muted,
                          tooltip: 'Cambiar lectura',
                          // La barra reemplaza al AppBar, así que esta es la única
                          // salida de la lectura: no puede quedar bajo el mínimo
                          // táctil aunque el alto esté apretado. Va primero en la
                          // fila —esquina izquierda, como el back estándar— porque
                          // ahí es donde se busca "volver"; un swap_horiz junto al
                          // cronómetro no se leía como salida.
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                        ),
                        SizedBox(width: r.spacing.sm),
                      ],
                      _Elapsed(elapsed: elapsed, recording: recording),
                      const Spacer(),
                      if (puedeAjustar) ...[
                        IconButton(
                          onPressed: () => setState(() => _adjusting = true),
                          icon: const Icon(Icons.format_size_rounded),
                          color: AppTheme.muted,
                          tooltip: 'Tamaño del texto',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                        ),
                        SizedBox(width: r.spacing.sm),
                      ],
                      _Action(
                        state: state,
                        onStart: widget.onStart,
                        onStop: widget.onStop,
                        onRepeat: widget.onRepeat,
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
              style: r.type.timerBar(theme.textTheme)?.copyWith(color: color),
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

/// El control de tamaño, ocupando la barra completa mientras está abierto.
///
/// El slider va sin divisiones: el rango útil es angosto —unos 11 sp en un
/// teléfono— y los pasos discretos harían perder el ajuste fino justo donde
/// importa. Los extremos ya están acotados al rango legible por
/// `AppTypeScale.readingSizeRange`, así que ninguna posición puede sacar al
/// texto de 45–75 cpl.
class _SizeControl extends StatelessWidget {
  const _SizeControl({
    required this.position,
    required this.onChanged,
    required this.onDone,
  });

  final double position;
  final ValueChanged<double> onChanged;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return Row(
      children: [
        Icon(
          Icons.text_fields_rounded,
          size: r.type.iconSm,
          color: AppTheme.muted,
        ),
        Expanded(
          child: Semantics(
            label: 'Tamaño del texto de lectura',
            child: Slider(
              value: position.clamp(0.0, 1.0),
              onChanged: onChanged,
            ),
          ),
        ),
        Icon(
          Icons.text_fields_rounded,
          size: r.type.iconLg,
          color: AppTheme.muted,
        ),
        SizedBox(width: r.spacing.md),
        TextButton(
          onPressed: onDone,
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 48),
            foregroundColor: AppTheme.primary,
          ),
          child: Text('Listo', style: theme.textTheme.labelLarge),
        ),
      ],
    );
  }
}
