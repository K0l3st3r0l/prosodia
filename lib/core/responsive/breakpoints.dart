import 'package:flutter/widgets.dart';

/// Clase de dispositivo, derivada del **lado corto** de la pantalla.
///
/// Se usa `shortestSide` y no `width` porque es invariante a la rotación: una
/// tablet de 800x1280 debe comportarse como la misma tablet en portrait y en
/// landscape. Con `width` la app cambiaría de clase al rotar y la densidad de
/// información saltaría sin motivo.
enum AppBreakpoint {
  /// `shortestSide < 600`. Frontera canónica `sw600dp` de Android: el propio
  /// sistema conmuta ahí sus recursos, así que alinearse evita que la app
  /// cambie de personalidad en un punto distinto al del SO.
  ///
  /// En términos de contenido: bajo 600 dp de lado corto no caben a la vez un
  /// panel de control usable (~320 dp para dropdowns con nombres completos) y
  /// una medida de lectura legible (≥45 caracteres ≈ 340 dp a 18 sp).
  phone,

  /// `600 <= shortestSide <= 1024`. Objetivo principal del producto.
  tablet,

  /// `shortestSide > 1024` — `sw1024dp`, tablets de 10″ o más. Hay presupuesto
  /// para la tercera columna de la galería y para subir la lectura a 26 sp
  /// manteniendo la medida acotada.
  tabletLarge;

  static AppBreakpoint fromShortestSide(double shortestSide) {
    if (shortestSide < phoneMax) return AppBreakpoint.phone;
    if (shortestSide <= tabletMax) return AppBreakpoint.tablet;
    return AppBreakpoint.tabletLarge;
  }

  static const double phoneMax = 600;
  static const double tabletMax = 1024;

  bool get isPhone => this == AppBreakpoint.phone;
  bool get isTablet => this == AppBreakpoint.tablet;
  bool get isTabletLarge => this == AppBreakpoint.tabletLarge;

  /// `true` para cualquier tablet, chica o grande.
  bool get isTabletClass => this != AppBreakpoint.phone;

  T select<T>({required T phone, required T tablet, T? tabletLarge}) {
    switch (this) {
      case AppBreakpoint.phone:
        return phone;
      case AppBreakpoint.tablet:
        return tablet;
      case AppBreakpoint.tabletLarge:
        return tabletLarge ?? tablet;
    }
  }
}

/// Cómo se compone el área de trabajo. Eje independiente de [AppBreakpoint]
/// porque el ancho útil del cuerpo no es el ancho de la pantalla: hay padding,
/// insets del sistema y, eventualmente, otros paneles.
enum PaneStrategy {
  /// Una sola columna scrolleable: preparación → cronómetro → lectura → revisión.
  stacked,

  /// Panel de control fijo + área de trabajo.
  dual;

  /// 320 (panel mínimo utilizable) + 12 (gap) + 340 (medida de lectura mínima
  /// legible) + 48 (paddings) = 720. Corte derivado del contenido.
  static const double dualMinWidth = 720;

  static PaneStrategy fromWidth(double availableWidth) =>
      availableWidth >= dualMinWidth ? PaneStrategy.dual : PaneStrategy.stacked;

  bool get isDual => this == PaneStrategy.dual;
  bool get isStacked => this == PaneStrategy.stacked;
}

/// Altura disponible bajo la cual el ritmo vertical se comprime y los
/// subtítulos secundarios se ocultan.
///
/// Se evalúa contra las `BoxConstraints` del cuerpo y no contra
/// `MediaQuery.size`, para que el teclado en pantalla no lo dispare en falso.
const double kShortViewportHeight = 480;

/// Mínimo de área táctil (Material 3 / WCAG 2.5.5 AAA).
const double kMinTapTarget = 48;

/// Altura mínima de una fila táctil respetando el escalado de texto del sistema.
double tappableHeight(BuildContext context, {double base = kMinTapTarget}) {
  final scaled = MediaQuery.textScalerOf(context).scale(base);
  return scaled > base ? scaled : base;
}
