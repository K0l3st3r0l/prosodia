import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// Control de orientación de la app.
///
/// Hay dos reglas distintas y conviene no confundirlas:
///
/// - **Por defecto** ([applyDefaultOrientations]): las tablets van forzadas a
///   landscape porque es el uso real del producto; los teléfonos rotan libres.
/// - **Superficie de lectura** ([lockLandscapeForReading]): landscape SIEMPRE,
///   sin importar la clase de dispositivo.
///
/// La segunda existe porque el texto que el niño lee en voz alta no es una
/// pantalla más: es el instrumento de medición. En portrait el contenedor se
/// angosta y las dos salidas posibles son malas — achicar la fuente perjudica a
/// un niño de básica, y dejar el tamaño nominal produce ~29 cpl, lo que
/// multiplica las vueltas de renglón, que es justo donde el niño pierde la
/// línea y se le penaliza el PCPM. El problema es la geometría, no el tamaño,
/// así que la lectura se mantiene en la geometría en que el instrumento fue
/// validado y el resto de la app (login, selección, resultados) rota libre.
///
/// `setPreferredOrientations` es una *preferencia*: en multiventana o pantalla
/// dividida el sistema puede entregar igual un contenedor angosto. Por eso
/// `AppTypeScale.readingSizeFor` sigue actuando como red de seguridad.
const List<DeviceOrientation> _landscapeOnly = [
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Clase de dispositivo resuelta sin `BuildContext`.
///
/// Se usa antes de que exista `MediaQuery` (en `main()`), así que sale de
/// `PlatformDispatcher` con el mismo criterio de `shortestSide` que
/// [AppBreakpoint].
AppBreakpoint platformBreakpoint() {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final logicalSize = view.physicalSize / view.devicePixelRatio;
  return AppBreakpoint.fromShortestSide(logicalSize.shortestSide);
}

/// Orientaciones por defecto: landscape en tablets, libre en teléfonos.
///
/// En Android `main()` corre antes del primer layout de la vista, así que en
/// ese momento `physicalSize` suele ser cero. Resolver con tamaño cero da
/// `phone` y dejaba la tablet rotando libre hasta salir por primera vez de la
/// evaluación: el login aparecía en portrait. Si todavía no hay tamaño, se
/// espera la primera métrica real antes de decidir.
Future<void> applyDefaultOrientations() {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  if (view.physicalSize.isEmpty) {
    WidgetsBinding.instance.addObserver(_DeferredDefaultOrientations());
    return Future.value();
  }
  return SystemChrome.setPreferredOrientations(
    platformBreakpoint().isTabletClass ? _landscapeOnly : const [],
  );
}

/// Aplica la orientación por defecto una sola vez, apenas la vista tiene
/// tamaño. Una sola vez porque, después, re-aplicarla en cada cambio de
/// métricas pisaría el lock de la superficie de lectura al rotar.
class _DeferredDefaultOrientations with WidgetsBindingObserver {
  @override
  void didChangeMetrics() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    if (view.physicalSize.isEmpty) return;
    WidgetsBinding.instance.removeObserver(this);
    applyDefaultOrientations();
  }
}

/// Landscape forzado mientras el texto de lectura está en pantalla.
Future<void> lockLandscapeForReading() =>
    SystemChrome.setPreferredOrientations(_landscapeOnly);
