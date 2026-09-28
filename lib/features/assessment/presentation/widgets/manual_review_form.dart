import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import 'formatting.dart';
import 'surfaces.dart';

/// Reproductor de la grabación recién tomada.
///
/// Recibe el estado ya resuelto en vez del `AudioPlayer`: así el widget es puro
/// y se puede montar en un test de layout sin plugins nativos.
class AudioPlayerBar extends StatelessWidget {
  const AudioPlayerBar({
    super.key,
    required this.playing,
    required this.position,
    required this.total,
    required this.onToggle,
  });

  final bool playing;
  final Duration position;
  final Duration total;
  final VoidCallback onToggle;

  static const Color _surface = Color(0xFFF4F9FA);
  static const Color _border = Color(0xFFDCEDEF);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return LayoutBuilder(
      builder: (context, constraints) {
        // La pastilla de estado es lo primero que cede: el botón y el tiempo
        // son la función, la etiqueta es confirmación redundante.
        final showStatus = constraints.maxWidth >= 320;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.spacing.md,
            vertical: r.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(r.radii.card),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: onToggle,
                tooltip: playing ? 'Pausar' : 'Escuchar grabación',
                constraints: const BoxConstraints(
                  minWidth: kMinTapTarget,
                  minHeight: kMinTapTarget,
                ),
                icon: Icon(
                  playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: r.type.iconLg,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.surfaceStrong,
                  foregroundColor: AppTheme.primary,
                ),
              ),
              SizedBox(width: r.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Escuchar grabación',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: r.spacing.xs),
                    Text(
                      '${formatElapsed(position)} / ${formatElapsed(total)}',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (showStatus) ...[
                SizedBox(width: r.spacing.sm),
                Flexible(
                  child: InfoPill(
                    icon: Icons.graphic_eq_rounded,
                    label: playing ? 'Reproduciendo' : 'Pausado',
                    foreground: AppTheme.secondary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Contador con `−` / valor / `+` para corregir lo que detectó la IA.
class CounterRow extends StatelessWidget {
  const CounterRow({
    super.key,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    required this.decrementTooltip,
    required this.incrementTooltip,
  });

  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final String decrementTooltip;
  final String incrementTooltip;

  static const Color _decrementSurface = Color(0xFFFCE7F3);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onDecrement,
          tooltip: decrementTooltip,
          constraints: const BoxConstraints(
            minWidth: kMinTapTarget,
            minHeight: kMinTapTarget,
          ),
          icon: const Icon(Icons.remove_rounded),
          style: IconButton.styleFrom(
            backgroundColor: _decrementSurface,
            foregroundColor: AppTheme.danger,
          ),
        ),
        SizedBox(width: r.spacing.md),
        Expanded(
          child: Container(
            constraints: BoxConstraints(minHeight: tappableHeight(context)),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(vertical: r.spacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(r.radii.control),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: r.type.counterValue(theme.textTheme),
            ),
          ),
        ),
        SizedBox(width: r.spacing.md),
        IconButton.filledTonal(
          onPressed: onIncrement,
          tooltip: incrementTooltip,
          constraints: const BoxConstraints(
            minWidth: kMinTapTarget,
            minHeight: kMinTapTarget,
          ),
          icon: const Icon(Icons.add_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.surfaceAlt,
            foregroundColor: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}

/// Selector de opción única (calidad de lectura, prosodia).
///
/// El tamaño de la etiqueta lo pone `chipTheme` del tema: antes venía clavado a
/// `fontSize: 11`, fuera de toda escala tipográfica.
class ChoiceChipSelector extends StatelessWidget {
  const ChoiceChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.sizingOptions,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  /// Opciones con que se decide el número de columnas; por defecto, las
  /// propias. Calidad y prosodia se miden juntas: son el mismo control uno
  /// debajo del otro, y con medidas separadas una quedaba en una columna y la
  /// otra en dos.
  final List<String>? sizingOptions;

  /// Lo que el chip suma alrededor de la etiqueta: `padding` del `chipTheme`
  /// (14 × 2), `labelPadding` de Material (8 × 2), el check que aparece al
  /// seleccionar y el borde.
  static const double _chipChrome = 72;

  /// Grilla de columnas de igual ancho y no un `Wrap` libre: cada chip medía
  /// lo que su texto, y en el panel de una tablet de 960 dp quedaban en
  /// escalera — «Silábica» sola, «Palabra a palabra» sola, los otros dos
  /// juntos. Las columnas salen del texto más largo medido con la escala del
  /// sistema, no de un ancho fijo.
  @override
  Widget build(BuildContext context) {
    final gap = context.responsive.spacing.sm;
    final labelStyle =
        ChipTheme.of(context).labelStyle ??
        Theme.of(context).textTheme.labelMedium;
    final scaler = MediaQuery.textScalerOf(context);

    var widest = 0.0;
    for (final option in sizingOptions ?? options) {
      final painter = TextPainter(
        text: TextSpan(text: formatChoiceLabel(option), style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final fits =
            ((constraints.maxWidth + gap) / (widest + _chipChrome + gap))
                .floor();
        final columns = fits.clamp(1, 2);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final option in options)
              SizedBox(
                width: width,
                child: ChoiceChip(
                  label: SizedBox(
                    width: double.infinity,
                    child: Text(
                      formatChoiceLabel(option),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  selected: selected == option,
                  onSelected: (_) => onSelected(option),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// De dónde salen los valores del formulario: la IA o el docente.
class _ReviewSourceNote extends StatelessWidget {
  const _ReviewSourceNote({required this.whisperAnalyzed});

  final bool whisperAnalyzed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final foreground = whisperAnalyzed ? AppTheme.primary : AppTheme.warningInk;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.spacing.md,
        vertical: r.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: whisperAnalyzed ? AppTheme.surfaceAlt : AppTheme.warningSurface,
        borderRadius: BorderRadius.circular(r.radii.control),
        border: Border.all(
          color: whisperAnalyzed
              ? theme.colorScheme.outline
              : AppTheme.warningBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            whisperAnalyzed
                ? Icons.auto_awesome_rounded
                : Icons.edit_note_rounded,
            size: r.type.iconSm,
            color: foreground,
          ),
          SizedBox(width: r.spacing.sm),
          Expanded(
            child: Text(
              whisperAnalyzed
                  ? 'Valores detectados por la IA — puedes corregirlos'
                  : 'Sin análisis IA — ingresa los valores manualmente',
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formulario de revisión manual: corrige lo que detectó la IA y guarda.
class ManualReviewForm extends StatelessWidget {
  const ManualReviewForm({
    super.key,
    required this.whisperAnalyzed,
    required this.palabrasLeidas,
    required this.errores,
    required this.totalPalabras,
    required this.pcpm,
    required this.calidad,
    required this.prosodia,
    required this.audioPlayer,
    required this.onPalabrasChanged,
    required this.onErroresChanged,
    required this.onCalidadChanged,
    required this.onProsodiaChanged,
    required this.onSave,
    required this.onDiscard,
  });

  final bool whisperAnalyzed;
  final int palabrasLeidas;
  final int errores;
  final int? totalPalabras;
  final double pcpm;
  final String calidad;
  final String prosodia;

  /// Barra de reproducción ya construida por la pantalla, que es quien conoce
  /// los streams del `AudioPlayer`.
  final Widget audioPlayer;

  final ValueChanged<int> onPalabrasChanged;
  final ValueChanged<int> onErroresChanged;
  final ValueChanged<String> onCalidadChanged;
  final ValueChanged<String> onProsodiaChanged;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  static const List<String> calidadOptions = [
    'silábica',
    'palabra_a_palabra',
    'unidades_cortas',
    'fluida',
  ];

  static const List<String> prosodiaOptions = [
    'inadecuada',
    'básica',
    'adecuada',
    'expresiva',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return SectionCard(
      title: 'Revisión manual',
      subtitle: 'Ajusta los datos y guarda la evaluación final.',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          audioPlayer,
          SizedBox(height: r.spacing.md),
          // Nota a ancho completo y no `InfoPill`: la pastilla es de una línea
          // con elipsis, y en el panel de una tablet de 960 dp la frase quedaba
          // en «Sin análisis IA — ingresa los valo…».
          _ReviewSourceNote(whisperAnalyzed: whisperAnalyzed),
          SizedBox(height: r.spacing.md),
          Wrap(
            spacing: r.spacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Palabras leídas', style: theme.textTheme.titleSmall),
              if (totalPalabras != null)
                Text(
                  'de $totalPalabras totales',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                  ),
                ),
            ],
          ),
          SizedBox(height: r.spacing.sm),
          CounterRow(
            value: palabrasLeidas,
            decrementTooltip: 'Quitar una palabra leída',
            incrementTooltip: 'Agregar una palabra leída',
            onDecrement: () =>
                onPalabrasChanged(palabrasLeidas > 0 ? palabrasLeidas - 1 : 0),
            onIncrement: () => onPalabrasChanged(palabrasLeidas + 1),
          ),
          SizedBox(height: r.spacing.md),
          Text('Errores', style: theme.textTheme.titleSmall),
          SizedBox(height: r.spacing.sm),
          CounterRow(
            value: errores,
            decrementTooltip: 'Quitar un error',
            incrementTooltip: 'Agregar un error',
            onDecrement: () => onErroresChanged(errores > 0 ? errores - 1 : 0),
            onIncrement: () => onErroresChanged(errores + 1),
          ),
          SizedBox(height: r.spacing.md),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.spacing.md,
              vertical: r.spacing.md,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(r.radii.control),
              border: Border.all(color: AppTheme.surfaceStrong),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'PCPM calculado',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: r.spacing.sm),
                Text(
                  pcpm.toStringAsFixed(1),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.spacing.md),
          Text('Calidad de lectura', style: theme.textTheme.titleSmall),
          SizedBox(height: r.spacing.sm),
          ChoiceChipSelector(
            options: calidadOptions,
            sizingOptions: const [...calidadOptions, ...prosodiaOptions],
            selected: calidad,
            onSelected: onCalidadChanged,
          ),
          SizedBox(height: r.spacing.md),
          Text('Prosodia', style: theme.textTheme.titleSmall),
          SizedBox(height: r.spacing.sm),
          ChoiceChipSelector(
            options: prosodiaOptions,
            sizingOptions: const [...calidadOptions, ...prosodiaOptions],
            selected: prosodia,
            onSelected: onProsodiaChanged,
          ),
          SizedBox(height: r.spacing.md),
          FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar evaluación'),
            onPressed: onSave,
          ),
          SizedBox(height: r.spacing.sm),
          OutlinedButton.icon(
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Cancelar y regrabar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: Color(0xFFFFCDD2)),
            ),
            onPressed: onDiscard,
          ),
        ],
      ),
    );
  }
}
