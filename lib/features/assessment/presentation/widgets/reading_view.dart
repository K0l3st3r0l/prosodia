import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import 'surfaces.dart';

/// El texto que el estudiante lee en voz alta, con su encabezado de contexto.
///
/// Es la superficie de mayor impacto pedagógico de la app: la medida de línea
/// determina cuántas veces el niño pierde el renglón mientras corre el
/// cronómetro, y eso se traduce directo en su PCPM.
class ReadingView extends StatelessWidget {
  const ReadingView({
    super.key,
    required this.text,
    required this.cursoLabel,
    required this.studentName,
    required this.onChangeReading,
    required this.fillHeight,
    this.onReadingCplMeasured,
  });

  final ReadingText text;
  final String cursoLabel;
  final String? studentName;
  final VoidCallback? onChangeReading;
  final bool fillHeight;

  /// Reporta los caracteres por línea **efectivos** del render real, cada vez
  /// que este widget se reconstruye. Quien escuche puede cachear el último
  /// valor y usarlo al guardar la sesión: la condición de render que importa
  /// es la de la lectura, no la del momento del guardado (la pantalla ya
  /// cambió a `analyzing`/`reviewing` para entonces).
  final ValueChanged<double>? onReadingCplMeasured;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    // Un solo scroll para encabezado y texto. Antes el encabezado era fijo y el
    // texto scrolleaba aparte: con el título en varias líneas y el texto del
    // sistema escalado, el encabezado por sí solo superaba la altura del panel
    // y no había forma de alcanzar el contenido.
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReadingHeader(
          text: text,
          cursoLabel: cursoLabel,
          studentName: studentName,
          onChangeReading: onChangeReading,
        ),
        SizedBox(height: r.spacing.lg),
        _ReadingBody(text: text, onCplMeasured: onReadingCplMeasured),
      ],
    );

    return fillHeight ? SingleChildScrollView(child: content) : content;
  }
}

class _ReadingBody extends StatelessWidget {
  const _ReadingBody({required this.text, this.onCplMeasured});

  final ReadingText text;
  final ValueChanged<double>? onCplMeasured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        r.pick(phone: 18.0, tablet: 24.0, tabletLarge: 28.0),
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(r.radii.surface),
        border: Border.all(color: AppTheme.surfaceStrong),
      ),
      // La medida se acota a ~64 caracteres por línea y el bloque se centra en
      // el espacio sobrante. Aprovechar el ancho de una tablet grande no
      // significa estirar el párrafo hasta 95 caracteres.
      child: Align(
        alignment: Alignment.topCenter,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // El ancho real disponible aquí ya descontó todos los paddings de
            // arriba: es el mismo número que ve el `ConstrainedBox`, solo que
            // medido antes de que él lo recorte a `readingMaxWidth`. Con eso
            // el cpl reportado refleja el render real, no el tope de diseño.
            final effectiveWidth = constraints.maxWidth < r.type.readingMaxWidth
                ? constraints.maxWidth
                : r.type.readingMaxWidth;
            // El tamaño nominal por breakpoint asume ancho de sobra. Un
            // contenedor más angosto (teléfono portrait, tablet portrait con
            // panel de control) lo reduce para sostener el piso de 45 cpl.
            final renderedSize = r.type.readingSizeFor(effectiveWidth);
            onCplMeasured?.call(
              r.type.effectiveCplFor(effectiveWidth, fontSize: renderedSize),
            );

            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: r.type.readingMaxWidth),
              child: Text(
                text.contenido,
                style: r.type.reading(theme.textTheme, fontSize: renderedSize),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReadingHeader extends StatelessWidget {
  const _ReadingHeader({
    required this.text,
    required this.cursoLabel,
    required this.studentName,
    required this.onChangeReading,
  });

  final ReadingText text;
  final String cursoLabel;
  final String? studentName;
  final VoidCallback? onChangeReading;

  static const Color _surface = Color(0xFFF4F8FC);
  static const Color _border = Color(0xFFE1EAF2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Bajo 520 dp el botón con etiqueta deja al título sin ancho utilizable.
        final compactAction = constraints.maxWidth < 520;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text.titulo,
              style:
                  (r.isShortViewport
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(color: AppTheme.primary),
            ),
            SizedBox(height: r.spacing.xs),
            Wrap(
              spacing: r.spacing.sm,
              runSpacing: r.spacing.sm,
              children: [
                InfoPill(label: '${text.totalPalabras} palabras'),
                InfoPill(
                  label: 'Curso $cursoLabel',
                  foreground: AppTheme.muted,
                ),
                if (studentName != null)
                  InfoPill(label: studentName!, foreground: AppTheme.muted),
              ],
            ),
          ],
        );

        return Container(
          padding: EdgeInsets.all(r.spacing.lg),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(r.radii.surface),
            border: Border.all(color: _border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              SizedBox(width: r.spacing.md),
              if (compactAction)
                IconButton.filledTonal(
                  onPressed: onChangeReading,
                  tooltip: 'Cambiar lectura',
                  constraints: const BoxConstraints(
                    minWidth: kMinTapTarget,
                    minHeight: kMinTapTarget,
                  ),
                  icon: const Icon(Icons.grid_view_rounded),
                )
              else
                OutlinedButton.icon(
                  onPressed: onChangeReading,
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text('Cambiar lectura'),
                ),
            ],
          ),
        );
      },
    );
  }
}
