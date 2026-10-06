import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prosodia/core/theme/app_theme.dart';
import 'package:prosodia/features/assessment/data/assessment_repository.dart';
import 'package:prosodia/features/trial/data/trial_repository.dart';
import 'package:prosodia/features/trial/presentation/trial_login_screen.dart';

/// Colegios de prueba: correo + PIN, listado propio y respaldo de resultados
/// fuera de Anahuac. Lo que se fija acá es que un resultado guardado en la
/// tablet no se pierda ni se duplique, y que no termine en otro colegio.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Map<String, dynamic> loginBody({List<Map<String, dynamic>>? alumnos}) => {
    'token': 'tok',
    'colegio': {'id': 'san-jose', 'nombre': 'Colegio San José'},
    'usuario': {'correo': 'profe@sj.cl', 'nombre': 'Ana'},
    'alumnos':
        alumnos ??
        [
          {'id': 1, 'nombre': 'Pérez Soto Ana', 'curso': '2°A'},
          {'id': 2, 'nombre': 'Rojas Luis', 'curso': '2°B'},
        ],
  };

  late _FakeAdapter adapter;
  late TrialRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adapter = _FakeAdapter();
    repo = TrialRepository(dio: Dio()..httpClientAdapter = adapter);
  });

  TrialSession session([String colegioId = 'san-jose']) => TrialSession(
    token: 'tok',
    colegioId: colegioId,
    colegio: 'Colegio',
    correo: 'profe@sj.cl',
    students: const [],
  );

  group('TrialSession', () {
    test('trae los alumnos del listado, sin RUT', () {
      final s = TrialSession.fromJson(loginBody());
      expect(s.colegio, 'Colegio San José');
      expect(s.hasRoster, isTrue);
      expect(s.students.map((a) => a.curso), ['2°A', '2°B']);
      expect(s.students.first.rut, isEmpty);
    });

    test('sin listado se evalúa sin alumno', () {
      expect(TrialSession.fromJson(loginBody(alumnos: [])).hasRoster, isFalse);
    });
  });

  group('login', () {
    test('recuerda el correo pero no el PIN', () async {
      adapter.respond = (_) => (200, loginBody());
      await repo.login('  profe@sj.cl ', '123456');
      expect(await repo.lastCorreo(), 'profe@sj.cl');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().map(prefs.get).join(),
        isNot(contains('123456')),
      );
    });

    test('mensajes según el motivo', () async {
      Future<String> messageOf() async {
        try {
          await repo.login('a@b.cl', '1');
        } on TrialLoginException catch (e) {
          return e.message;
        }
        fail('debió fallar');
      }

      adapter.respond = (_) => (401, {'detail': 'x'});
      expect(await messageOf(), 'Correo o PIN incorrectos.');

      adapter.respond = (_) => (429, {'detail': 'Demasiados intentos.'});
      expect(await messageOf(), 'Demasiados intentos.');

      adapter.offline = true;
      expect(await messageOf(), contains('Wi-Fi'));
    });
  });

  group('respaldo de resultados', () {
    test('se envía y sale de la cola', () async {
      adapter.respond = (_) => (200, {'ok': true});
      await repo.saveLocal(session(), {'id': 'r1', 'pcpm': 70});
      final report = await repo.syncPending(session());
      expect(report.sent, 1);
      expect(await repo.pendingCount(session()), 0);
      expect(adapter.lastAuth, 'Bearer tok');
      expect(adapter.lastBody?['id'], 'r1');
    });

    test('sin red queda en la tablet', () async {
      adapter.offline = true;
      await repo.saveLocal(session(), {'id': 'r1'});
      final report = await repo.syncPending(session());
      expect(report.failure, SyncFailure.unreachable);
      expect(await repo.pendingCount(session()), 1);
    });

    test('token vencido: no ofrece el login de Anahuac', () async {
      adapter.respond = (_) => (401, {'detail': 'venció'});
      await repo.saveLocal(session(), {'id': 'r1'});
      await repo.saveLocal(session(), {'id': 'r2'});
      final report = await repo.syncPending(session());
      expect(report.failure, SyncFailure.rejected);
      expect(report.serverMessage, contains('PIN'));
      expect(adapter.posts, 1, reason: 'Con el token malo las demás fallarían igual.');
      expect(await repo.pendingCount(session()), 2);
    });

    test('solo envía las del colegio con que se entró', () async {
      adapter.respond = (_) => (200, {'ok': true});
      await repo.saveLocal(session('otro'), {'id': 'ajeno'});
      await repo.saveLocal(session(), {'id': 'propio'});
      final report = await repo.syncPending(session());
      expect(report.sent, 1);
      expect(adapter.lastBody?['id'], 'propio');
      expect(await repo.pendingCount(session('otro')), 1);
    });

    test('dos envíos simultáneos no suben dos veces lo mismo', () async {
      adapter.respond = (_) => (200, {'ok': true});
      await repo.saveLocal(session(), {'id': 'r1'});
      await Future.wait([
        repo.syncPending(session()),
        repo.syncPending(session()),
      ]);
      expect(adapter.posts, 1);
    });

    test('lo guardado mientras se envía no se pierde', () async {
      adapter.respond = (_) => (200, {'ok': true});
      await repo.saveLocal(session(), {'id': 'r1'});
      adapter.onPost = () => repo.saveLocal(session(), {'id': 'r2'});
      await repo.syncPending(session());
      adapter.onPost = null;
      expect(await repo.pendingCount(session()), 1);
    });
  });

  group('Pantalla de PIN', () {
    Widget screen() => MaterialApp(
      theme: AppTheme.light,
      home: TrialLoginScreen(repository: repo),
    );

    testWidgets('el botón espera correo y PIN; el PIN acepta solo 6 dígitos', (
      tester,
    ) async {
      await tester.pumpWidget(screen());
      await tester.pump();

      FilledButton button() => tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Entrar a la prueba'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );

      expect(button().onPressed, isNull);
      await tester.enterText(find.byType(TextField).first, 'profe@sj.cl');
      await tester.pump();
      expect(button().onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, '12ab345678');
      await tester.pump();
      final pin = tester.widget<TextField>(find.byType(TextField).last);
      expect(pin.controller!.text, '123456');
      expect(button().onPressed, isNotNull);
    });

    testWidgets('un PIN malo muestra el motivo y borra el PIN', (tester) async {
      adapter.respond = (_) => (401, {'detail': 'x'});
      await tester.pumpWidget(screen());
      await tester.enterText(find.byType(TextField).first, 'profe@sj.cl');
      await tester.enterText(find.byType(TextField).last, '000000');
      await tester.pump();
      await tester.tap(find.text('Entrar a la prueba'));
      await tester.pumpAndSettle();

      expect(find.text('Correo o PIN incorrectos.'), findsOneWidget);
      final pin = tester.widget<TextField>(find.byType(TextField).last);
      expect(pin.controller!.text, isEmpty);
    });

    testWidgets('propone el último correo usado', (tester) async {
      SharedPreferences.setMockInitialValues({
        'trial_last_correo': 'profe@sj.cl',
      });
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text('profe@sj.cl'), findsOneWidget);
    });
  });
}

class _FakeAdapter implements HttpClientAdapter {
  (int, Map<String, dynamic>) Function(RequestOptions) respond = (_) =>
      (500, {});
  int posts = 0;
  bool offline = false;
  String? lastAuth;
  Map<String, dynamic>? lastBody;
  Future<void> Function()? onPost;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST') {
      posts++;
      lastAuth = options.headers['Authorization'] as String?;
      lastBody = options.data is Map
          ? Map<String, dynamic>.from(options.data as Map)
          : null;
      await onPost?.call();
    }
    if (offline) throw const SocketException('Network is unreachable');
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
