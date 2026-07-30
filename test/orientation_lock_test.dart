import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prosodia/core/responsive/orientation_lock.dart';

/// La orientación no es preferencia estética en esta app: la superficie de
/// lectura es el instrumento de medición y su geometría afecta el PCPM.
///
/// `setPreferredOrientations` viaja por `SystemChannels.platform`, así que
/// estos tests interceptan el canal y verifican el payload real que se le
/// manda al sistema, no una abstracción intermedia.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<List<String>> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        calls.add(List<String>.from(call.arguments as List));
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Fija el tamaño físico de la vista para que `platformBreakpoint()` resuelva
  /// la clase de dispositivo buscada.
  void useDevice(Size logicalSize) {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.devicePixelRatio = 1.0;
    view.physicalSize = logicalSize;
    addTearDown(view.reset);
  }

  const landscapeOnly = [
    'DeviceOrientation.landscapeLeft',
    'DeviceOrientation.landscapeRight',
  ];

  group('Orientaciones por defecto', () {
    test('la tablet queda forzada a landscape', () async {
      useDevice(const Size(1280, 800));
      await applyDefaultOrientations();
      expect(calls.single, landscapeOnly);
    });

    test('el teléfono queda libre de rotar', () async {
      useDevice(const Size(360, 640));
      await applyDefaultOrientations();
      expect(calls.single, isEmpty);
    });

    test('la clase se resuelve por shortestSide, no por orientación actual',
        () async {
      // Misma tablet, sostenida en portrait: sigue siendo clase tablet.
      useDevice(const Size(800, 1280));
      await applyDefaultOrientations();
      expect(calls.single, landscapeOnly);
    });
  });

  group('Superficie de lectura', () {
    test('fuerza landscape también en teléfono', () async {
      useDevice(const Size(360, 640));
      await lockLandscapeForReading();
      expect(
        calls.single,
        landscapeOnly,
        reason: 'el texto que el niño lee no debe rotar a portrait en ningún '
            'dispositivo: en portrait el contenedor se angosta y el cpl cae '
            'fuera del rango legible',
      );
    });

    test('soltar la lectura devuelve al teléfono su libertad de rotar',
        () async {
      useDevice(const Size(360, 640));
      await lockLandscapeForReading();
      await applyDefaultOrientations();
      expect(calls, [landscapeOnly, isEmpty]);
    });

    test('soltar la lectura deja la tablet en landscape', () async {
      useDevice(const Size(1280, 800));
      await lockLandscapeForReading();
      await applyDefaultOrientations();
      expect(calls, [landscapeOnly, landscapeOnly]);
    });
  });
}
