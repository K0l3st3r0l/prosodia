import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// Escala de espaciado sobre grilla de 4 dp, con una tabla explícita por clase
/// de dispositivo.
///
/// Se usan tablas y no un multiplicador porque un factor tipo `0.75` produce
/// valores fuera de grilla (12 → 9) que luego hay que redondear a mano en cada
/// llamada: eso es exactamente el "número mágico suelto" que esta capa existe
/// para eliminar.
@immutable
class AppSpacing {
  const AppSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.gutter,
    required this.paneGap,
  });

  /// Separación mínima entre elementos hermanos de una misma unidad.
  final double xs;

  /// Separación dentro de un grupo (icono ↔ etiqueta, chip ↔ chip).
  final double sm;

  /// Separación entre campos de un formulario.
  final double md;

  /// Padding interno de tarjetas y separación entre bloques relacionados.
  final double lg;

  /// Separación entre secciones.
  final double xl;

  /// Separación entre zonas mayores de la pantalla.
  final double xxl;

  /// Padding del borde de la página.
  final double gutter;

  /// Separación entre el panel de control y el área de trabajo.
  final double paneGap;

  static const AppSpacing _phone = AppSpacing(
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 20,
    xxl: 28,
    gutter: 12,
    paneGap: 8,
  );

  static const AppSpacing _tablet = AppSpacing(
    xs: 4,
    sm: 8,
    md: 12,
    lg: 18,
    xl: 24,
    xxl: 32,
    gutter: 16,
    paneGap: 12,
  );

  static const AppSpacing _tabletLarge = AppSpacing(
    xs: 6,
    sm: 10,
    md: 16,
    lg: 22,
    xl: 30,
    xxl: 40,
    gutter: 20,
    paneGap: 16,
  );

  /// Variante comprimida para viewports bajos (teléfono en landscape).
  ///
  /// Solo se recortan los pasos grandes: `xs`/`sm` sostienen la legibilidad de
  /// los grupos y comprimirlos rompe la agrupación visual sin ganar altura útil.
  AppSpacing get compressed => AppSpacing(
    xs: xs,
    sm: sm,
    md: md - 2,
    lg: lg - 6,
    xl: xl - 8,
    xxl: xxl - 12,
    gutter: gutter - 4,
    paneGap: paneGap,
  );

  static AppSpacing forBreakpoint(
    AppBreakpoint breakpoint, {
    bool short = false,
  }) {
    final base = breakpoint.select(
      phone: _phone,
      tablet: _tablet,
      tabletLarge: _tabletLarge,
    );
    return short ? base.compressed : base;
  }
}

/// Radios de esquina por rol. La app usa hoy nueve radios distintos entre 16 y
/// 999; esta tabla los reduce a cinco con un significado cada uno.
@immutable
class AppRadii {
  const AppRadii({
    required this.control,
    required this.card,
    required this.panel,
    required this.surface,
  });

  /// Botones, campos, contadores.
  final double control;

  /// Tarjetas internas y bloques dentro de una tarjeta.
  final double card;

  /// Tarjetas de sección.
  final double panel;

  /// Contenedores de nivel superior (paneles flotantes).
  final double surface;

  /// Pastillas y chips: siempre cápsula completa.
  static const double pill = 999;

  static const AppRadii _compact = AppRadii(
    control: 16,
    card: 20,
    panel: 24,
    surface: 28,
  );

  static const AppRadii _regular = AppRadii(
    control: 18,
    card: 22,
    panel: 26,
    surface: 32,
  );

  static AppRadii forBreakpoint(AppBreakpoint breakpoint) =>
      breakpoint.isPhone ? _compact : _regular;
}
