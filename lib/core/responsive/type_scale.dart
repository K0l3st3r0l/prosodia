import 'package:flutter/material.dart' show TextTheme;
import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import 'breakpoints.dart';

/// Escala tipográfica de la app.
///
/// No redefine familias ni pesos: esos viven en `AppTheme.light` y siguen
/// siendo la única fuente. Esta capa resuelve los **roles que el `TextTheme` de
/// Material no puede conocer** — el tamaño del texto de lectura, la medida de
/// línea, el tamaño del cronómetro — y elige, para el resto, qué rol del
/// `TextTheme` corresponde a cada clase de dispositivo.
@immutable
class AppTypeScale {
  const AppTypeScale({
    required this.readingSize,
    required this.readingHeight,
    required this.reviewSize,
    required this.chartLabelSize,
    required this.iconSm,
    required this.iconMd,
    required this.iconLg,
    required this.timerRole,
  });

  /// Tamaño del texto que **lee el niño en voz alta**. Es el token tipográfico
  /// más cargado de significado del producto: de él dependen la medida de línea
  /// y, por tanto, cuántas veces el estudiante pierde el renglón bajo cronómetro.
  final double readingSize;

  /// Interlineado del texto de lectura. Sube con el tamaño porque líneas más
  /// largas necesitan más separación para no saltar de renglón.
  final double readingHeight;

  /// Texto de lectura secundario (comparación original ↔ transcripción de la IA).
  final double reviewSize;

  /// Etiquetas de eje en los gráficos. Nunca baja de 10: el código anterior
  /// usaba 8 y 9, ilegibles y fuera de cualquier escala.
  final double chartLabelSize;

  final double iconSm;
  final double iconMd;
  final double iconLg;

  /// Rol del `TextTheme` que usa el cronómetro.
  final TimerRole timerRole;

  /// Ancho máximo del bloque de lectura, en dp.
  ///
  /// Source Serif 4 tiene un avance medio ≈ `0.5 × fontSize`, así que
  /// `fontSize × 32` ≈ **64 caracteres por línea**, dentro del rango legible de
  /// 45–75 cpl para lectura sostenida. Sin este tope, una tablet de 1200 dp
  /// produce líneas de ~95 cpl.
  double get readingMaxWidth => readingSize * 32;

  /// Ancho de la cifra `MM:SS` del cronómetro, como múltiplo del `fontSize`.
  ///
  /// Con `tabularFigures` los cuatro dígitos de Nunito comparten avance
  /// (≈ 0.60 em, redondeado hacia arriba) y los dos puntos miden ≈ 0.32 em:
  /// `4 × 0.60 + 0.32 = 2.72`.
  ///
  /// Es una constante documentada y no una medición porque `flutter_test` usa
  /// una fuente donde cada glifo mide un em completo — casi el doble que
  /// Nunito—, así que medir glifos en test no dice nada del dispositivo. Mismo
  /// criterio que [readingMaxWidth], que asume ≈ 0.5 em para Source Serif 4.
  static const double timerAdvanceMMSS = 2.72;

  /// Piso de caracteres por línea para lectura sostenida (ver rango legible
  /// 45–75 cpl documentado junto a [readingMaxWidth]).
  static const double _minReadableCpl = 45;

  /// Bajo este tamaño el texto deja de ser cómodo para lectura sostenida,
  /// aunque eso implique quedar bajo [_minReadableCpl] en un contenedor muy
  /// angosto (p. ej. 316 dp de ancho útil en un teléfono portrait de 360 dp).
  static const double _minReadingSize = 14;

  /// Tamaño nominal de lectura en **modo foco** (teléfono, sin cromo alrededor).
  ///
  /// Sube un tercio sobre el nominal porque el texto pasa a tener la pantalla
  /// completa: con el nominal, el bloque queda topado en [readingMaxWidth] y
  /// desperdicia ancho real. En un teléfono de 640 dp en landscape, 24 sp llenan
  /// el ancho disponible y dejan ~50 cpl, dentro del rango legible de 45–75.
  double get readingFocusSize => readingSize * 4 / 3;

  /// Tamaño de fuente de lectura para un ancho de render dado.
  ///
  /// [readingSize] asume un ancho de al menos [readingMaxWidth] — el caso de
  /// diseño, tablet en landscape. Cuando el contenedor real es más angosto
  /// (teléfono en portrait, o tablet en portrait donde el panel de control le
  /// resta ancho al área de trabajo) el tamaño nominal produce menos de 45
  /// cpl. Se reduce hasta sostener el piso, sin bajar de [_minReadingSize].
  /// [nominal] permite pasar un techo distinto de [readingSize] — lo usa el modo
  /// foco con [readingFocusSize]. El piso de cpl y el de legibilidad se aplican
  /// igual, así que subir el nominal nunca puede sacar al texto del rango.
  double readingSizeFor(double renderedWidth, {double? nominal}) {
    final sizeForFloor = renderedWidth / (_minReadableCpl * 0.5);
    return sizeForFloor.clamp(_minReadingSize, nominal ?? readingSize);
  }

  /// Caracteres por línea **efectivos** para un ancho y tamaño de fuente de
  /// render dados. Con el tamaño de [readingSizeFor] el resultado converge a
  /// 45–75 cpl incluso cuando el contenedor real es más angosto que
  /// [readingMaxWidth]; con el [readingSize] nominal, es la cifra teórica
  /// (~64) que asume que siempre hay ancho de sobra.
  double effectiveCplFor(double renderedWidth, {double? fontSize}) =>
      renderedWidth / ((fontSize ?? readingSize) * 0.5);

  TextStyle reading(
    TextTheme textTheme, {
    Color color = AppTheme.ink,
    double? fontSize,
  }) => AppTheme.readingTextStyle(
    textTheme,
    fontSize: fontSize ?? readingSize,
    height: readingHeight,
    color: color,
  );

  TextStyle review(TextTheme textTheme, {Color color = AppTheme.ink}) =>
      AppTheme.readingTextStyle(
        textTheme,
        fontSize: reviewSize,
        height: 1.75,
        color: color,
      );

  /// Estilo del cronómetro.
  ///
  /// Ya no reutiliza un rol del `TextTheme`: desde que el cronómetro dejó de
  /// compartir caja con un ícono y ocupa su tarjeta completa, funciona como
  /// cifra de display y necesita su propia escala. Los roles generales
  /// (`headlineMedium` 30, `displaySmall` 36) quedan chicos para una caja
  /// dedicada de 320–460 dp de ancho.
  ///
  /// `tabularFigures` es lo que impide que la cifra baile: con avances
  /// proporcionales los dígitos de Nunito tienen anchos distintos y el texto se
  /// corre lateralmente en cada segundo, justo mientras el docente lo mira.
  /// `letterSpacing: 0` revierte el tracking negativo de los roles de display,
  /// que a este tamaño junta demasiado los dígitos.
  TextStyle? timer(TextTheme textTheme) {
    // Ver [timerAdvanceMMSS] para el tope de ancho que respetan estos tamaños.
    final size = switch (timerRole) {
      // `compact` optimiza altura, no llenado horizontal: en un viewport bajo
      // (teléfono en landscape) el panel de control ya viene apretado de alto y
      // cada dp que gane el cronómetro se lo quita a los controles.
      TimerRole.compact => 48.0,
      TimerRole.regular => 56.0,
      TimerRole.large => 80.0,
    };
    return textTheme.displaySmall?.copyWith(
      fontSize: size,
      height: 1.0,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Cronómetro de `ReadingModeBar`.
  ///
  /// Más chico que [timer] —esa cifra tiene una tarjeta para ella sola— pero
  /// bastante más grande que un rol de título: comparte la franja con un botón
  /// de 48 dp de alto, y con un rol de 20 sp al lado de ese botón el tiempo se
  /// leía como un detalle en vez de como el dato principal de la barra.
  TextStyle? timerBar(TextTheme textTheme) {
    final size = switch (timerRole) {
      TimerRole.compact => 32.0,
      TimerRole.regular => 36.0,
      TimerRole.large => 40.0,
    };
    return textTheme.displaySmall?.copyWith(
      fontSize: size,
      height: 1.0,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Valor de los contadores de la revisión manual (palabras leídas, errores).
  TextStyle? counterValue(TextTheme textTheme) => textTheme.headlineSmall;

  static const AppTypeScale _phone = AppTypeScale(
    readingSize: 18,
    readingHeight: 1.75,
    reviewSize: 15,
    chartLabelSize: 10,
    iconSm: 14,
    iconMd: 18,
    iconLg: 22,
    timerRole: TimerRole.regular,
  );

  static const AppTypeScale _tablet = AppTypeScale(
    readingSize: 22,
    readingHeight: 1.9,
    reviewSize: 17,
    chartLabelSize: 11,
    iconSm: 16,
    iconMd: 20,
    iconLg: 24,
    timerRole: TimerRole.large,
  );

  static const AppTypeScale _tabletLarge = AppTypeScale(
    readingSize: 26,
    readingHeight: 2.0,
    reviewSize: 18,
    chartLabelSize: 12,
    iconSm: 18,
    iconMd: 22,
    iconLg: 26,
    timerRole: TimerRole.large,
  );

  /// Variante para viewports bajos: baja lectura e iconos, y devuelve el
  /// cronómetro a un rol compacto para que no coma la altura del panel.
  AppTypeScale get compressed => AppTypeScale(
    readingSize: readingSize - 2,
    readingHeight: 1.7,
    reviewSize: reviewSize - 1,
    chartLabelSize: chartLabelSize,
    iconSm: iconSm,
    iconMd: iconMd - 2,
    iconLg: iconLg - 4,
    timerRole: TimerRole.compact,
  );

  static AppTypeScale forBreakpoint(
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

enum TimerRole { compact, regular, large }
