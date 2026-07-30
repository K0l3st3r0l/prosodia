import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'breakpoints.dart';
import 'spacing.dart';
import 'type_scale.dart';

export 'breakpoints.dart';
export 'spacing.dart';
export 'type_scale.dart';

/// Contexto responsive resuelto una sola vez por pantalla.
///
/// Antes de esta capa la app calculaba `isPhoneLandscape` en tres lugares, dos
/// de ellos desde fuentes distintas (`MediaQuery.sizeOf` vs las `constraints`
/// del cuerpo), que divergen cuando aparece el teclado o cambian los insets del
/// sistema. Aquí se resuelve una vez y se propaga por el árbol.
@immutable
class Responsive {
  const Responsive({
    required this.breakpoint,
    required this.paneStrategy,
    required this.isShortViewport,
    required this.isPortrait,
    required this.available,
    required this.spacing,
    required this.radii,
    required this.type,
    required this.textScale,
  });

  /// Clase de dispositivo, desde el lado corto de la pantalla.
  final AppBreakpoint breakpoint;

  /// Composición del área de trabajo, desde el ancho realmente disponible.
  final PaneStrategy paneStrategy;

  /// Altura disponible por debajo de [kShortViewportHeight].
  final bool isShortViewport;

  final bool isPortrait;

  /// Espacio realmente disponible para el cuerpo, ya descontados los insets.
  final Size available;

  final AppSpacing spacing;
  final AppRadii radii;
  final AppTypeScale type;

  /// Factor de escalado de texto del sistema, ya aplicado a un tamaño de
  /// referencia. Sirve para dimensionar cajas que deben crecer con el texto.
  final double textScale;

  factory Responsive.resolve({
    required Size deviceSize,
    required BoxConstraints constraints,
    required double textScale,
  }) {
    final breakpoint = AppBreakpoint.fromShortestSide(deviceSize.shortestSide);
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : deviceSize.width;
    final height = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : deviceSize.height;
    final short = height < kShortViewportHeight;

    return Responsive(
      breakpoint: breakpoint,
      paneStrategy: PaneStrategy.fromWidth(width),
      isShortViewport: short,
      isPortrait: deviceSize.height >= deviceSize.width,
      available: Size(width, height),
      spacing: AppSpacing.forBreakpoint(breakpoint, short: short),
      radii: AppRadii.forBreakpoint(breakpoint),
      type: AppTypeScale.forBreakpoint(breakpoint, short: short),
      textScale: textScale,
    );
  }

  // ── Métricas de layout ────────────────────────────────────────────────────

  /// Ancho del panel de control en composición [PaneStrategy.dual].
  ///
  /// Proporcional con topes: bajo 320 dp los dropdowns con nombre completo
  /// dejan de ser usables; sobre 420 dp el panel domina la pantalla y le roba
  /// ancho al texto de lectura, que es lo que el niño necesita ver.
  double get controlPanelWidth {
    final proportional = available.width * 0.32;
    final maxWidth = breakpoint.isTabletLarge ? 460.0 : 420.0;
    return proportional.clamp(320.0, maxWidth);
  }

  /// Altura de la portada de una lectura en la galería.
  double get coverHeight {
    if (isShortViewport) return 96;
    return breakpoint.select(phone: 140.0, tablet: 176.0, tabletLarge: 200.0);
  }

  /// Ancho mínimo por tarjeta de la galería. Bajo esto el título se parte en
  /// tres líneas y la tarjeta deja de ser escaneable de un vistazo.
  double get galleryMinCardWidth =>
      breakpoint.select(phone: 260.0, tablet: 280.0, tabletLarge: 300.0);

  /// Columnas de la galería, derivadas del ancho real y no de umbrales fijos.
  int galleryColumns(double width) {
    final fits = (width / galleryMinCardWidth).floor();
    return fits.clamp(1, 3);
  }

  /// Altura **mínima** —no fija— de una tarjeta de la galería.
  ///
  /// La tarjeta puede crecer: con `textScaler` alto o títulos de dos líneas el
  /// contenido no cabe en una caja rígida, y ese era el desbordamiento más
  /// probable de la pantalla anterior.
  double get galleryCardMinHeight {
    final content = isShortViewport ? 92.0 : 150.0;
    return coverHeight + content * math.max(1.0, textScale);
  }

  /// Altura de los gráficos de contexto. Crece con el texto para que las
  /// etiquetas de eje no se recorten.
  double get chartHeight {
    final base = breakpoint.select(
      phone: 140.0,
      tablet: 160.0,
      tabletLarge: 180.0,
    );
    return base * math.max(1.0, textScale);
  }

  /// Ancho máximo de un bloque de texto corrido centrado (estados vacíos,
  /// mensajes de proceso).
  double get proseMaxWidth =>
      breakpoint.select(phone: 380.0, tablet: 460.0, tabletLarge: 520.0);

  /// Elige un valor según la clase de dispositivo.
  T pick<T>({required T phone, required T tablet, T? tabletLarge}) =>
      breakpoint.select(phone: phone, tablet: tablet, tabletLarge: tabletLarge);

  @override
  bool operator ==(Object other) =>
      other is Responsive &&
      other.breakpoint == breakpoint &&
      other.paneStrategy == paneStrategy &&
      other.isShortViewport == isShortViewport &&
      other.isPortrait == isPortrait &&
      other.available == available &&
      other.textScale == textScale;

  @override
  int get hashCode => Object.hash(
    breakpoint,
    paneStrategy,
    isShortViewport,
    isPortrait,
    available,
    textScale,
  );
}

/// Resuelve el [Responsive] de una superficie y lo propaga por el árbol.
///
/// Se coloca una sola vez por pantalla, dentro del `body` del `Scaffold`, para
/// que las `constraints` correspondan al espacio real del cuerpo.
class ResponsiveScope extends StatelessWidget {
  const ResponsiveScope({super.key, required this.builder});

  final Widget Function(BuildContext context, Responsive responsive) builder;

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.sizeOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = Responsive.resolve(
          deviceSize: deviceSize,
          constraints: constraints,
          textScale: textScale,
        );
        return _ResponsiveProvider(
          responsive: responsive,
          child: Builder(builder: (context) => builder(context, responsive)),
        );
      },
    );
  }
}

class _ResponsiveProvider extends InheritedWidget {
  const _ResponsiveProvider({required this.responsive, required super.child});

  final Responsive responsive;

  @override
  bool updateShouldNotify(_ResponsiveProvider oldWidget) =>
      oldWidget.responsive != responsive;
}

extension ResponsiveContext on BuildContext {
  /// [Responsive] de la superficie actual.
  ///
  /// Lanza si no hay [ResponsiveScope] arriba: es un error de programación, no
  /// un caso a degradar en silencio con valores por defecto que nadie diseñó.
  Responsive get responsive {
    final provider = dependOnInheritedWidgetOfExactType<_ResponsiveProvider>();
    assert(
      provider != null,
      'No hay ResponsiveScope en el árbol. Envuelve el body de la pantalla '
      'en un ResponsiveScope antes de usar context.responsive.',
    );
    return provider!.responsive;
  }
}
