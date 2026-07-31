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
    this.focus = false,
    this.sizePosition,
    this.onReadingCplMeasured,
    this.onSizeControlReady,
  });

  /// Posición del control de tamaño (0 = letra más chica del rango legible,
  /// 1 = más grande). `null` mantiene el comportamiento nominal de siempre:
  /// mientras el docente no toque el control, el texto se ve exactamente igual
  /// que antes de que el control existiera.
  final double? sizePosition;

  /// Modo foco de teléfono: sin encabezado, sin tarjeta y con el nominal de
  /// lectura subido, porque el texto tiene la pantalla completa. La salida
  /// ([onChangeReading]) vive entonces en `ReadingModeBar`, no acá.
  final bool focus;

  /// Posición del control de tamaño equivalente al tamaño **nominal**, medida
  /// sobre el ancho útil real.
  ///
  /// Va hacia arriba porque el control vive en `ReadingModeBar`, pero tanto el
  /// ancho como la escala tipográfica correcta solo se conocen acá. Se reporta
  /// ya resuelta —y no el ancho crudo— para que nadie tenga que reproducir el
  /// cálculo de layout afuera, que es justo lo que se desincroniza.
  ///
  /// Que llegue no nulo es además la señal de que el control se puede ofrecer:
  /// sin una medición real no hay con qué acotar el rango legible.
  final ValueChanged<double>? onSizeControlReady;

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
        if (!focus) ...[
          _ReadingHeader(
            text: text,
            cursoLabel: cursoLabel,
            studentName: studentName,
            onChangeReading: onChangeReading,
          ),
          SizedBox(height: r.spacing.lg),
        ],
        _ReadingBody(
          text: text,
          focus: focus,
          sizePosition: sizePosition,
          onCplMeasured: onReadingCplMeasured,
          onSizeControlReady: onSizeControlReady,
        ),
      ],
    );

    return fillHeight ? SingleChildScrollView(child: content) : content;
  }
}

class _ReadingBody extends StatelessWidget {
  const _ReadingBody({
    required this.text,
    required this.focus,
    this.sizePosition,
    this.onCplMeasured,
    this.onSizeControlReady,
  });

  final ReadingText text;
  final bool focus;
  final double? sizePosition;
  final ValueChanged<double>? onCplMeasured;
  final ValueChanged<double>? onSizeControlReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    // En modo foco el bloque no es una tarjeta dentro de un panel: es la
    // pantalla. Sin borde ni radio, y con el nominal subido, porque ya no hay
    // cromo con el que competir.
    final nominal = focus ? r.type.readingFocusSize : r.type.readingSize;

    // El tope de ancho existe para que la línea no se estire más allá del rango
    // legible con el tamaño nominal. Cuando el tamaño lo fija el control, esa
    // garantía ya la da `readingSizeAtPosition`, y mantener el tope derivado del
    // nominal volvería circular el cálculo: el ancho acotaría el tamaño que a su
    // vez debería definir el ancho.
    final maxWidth = sizePosition == null ? nominal * 32 : double.infinity;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        focus
            ? r.spacing.md
            : r.pick(phone: 18.0, tablet: 24.0, tabletLarge: 28.0),
      ),
      decoration: focus
          ? null
          : BoxDecoration(
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
            final effectiveWidth = constraints.maxWidth < maxWidth
                ? constraints.maxWidth
                : maxWidth;
            // El tamaño nominal por breakpoint asume ancho de sobra. Un
            // contenedor más angosto (teléfono portrait, tablet portrait con
            // panel de control) lo reduce para sostener el piso de 45 cpl.
            // Con preferencia guardada el tamaño sale del control, ya acotado
            // al rango legible por `readingSizeAtPosition`. Sin ella, la ruta
            // de siempre.
            final posicion = sizePosition;
            final renderedSize = posicion == null
                ? r.type.readingSizeFor(effectiveWidth, nominal: nominal)
                : r.type.readingSizeAtPosition(effectiveWidth, posicion);

            onSizeControlReady?.call(
              r.type.readingPositionOf(
                effectiveWidth,
                r.type.readingSizeFor(effectiveWidth, nominal: nominal),
              ),
            );
            onCplMeasured?.call(
              r.type.effectiveCplFor(effectiveWidth, fontSize: renderedSize),
            );

            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
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
