import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prosodia/core/auth/auth_repository.dart';
import 'package:prosodia/core/auth/jwt.dart';
import 'package:prosodia/core/database/app_database.dart';
import 'package:prosodia/core/network/api_client.dart';
import 'package:prosodia/core/responsive/responsive.dart';
import 'package:prosodia/core/theme/app_theme.dart';
import 'package:prosodia/features/assessment/data/assessment_repository.dart';
import 'package:prosodia/features/assessment/presentation/pending_evaluations_screen.dart';
import 'package:prosodia/features/assessment/presentation/widgets/sync_status_banner.dart';

/// Evaluaciones que no llegan a anahuac.
///
/// El 2026-10-05 una tablet entró con un JWT vencido hacía seis días: la app
/// solo revisaba que el token existiera, el servidor respondió 401 a cada
/// envío y el error se descartaba en silencio. Lo que se fija acá es que eso
/// ya no pueda pasar sin que el docente lo vea.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  String jwt(Map<String, dynamic> payload) {
    String part(Map<String, dynamic> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    return '${part({'alg': 'HS256'})}.${part(payload)}.firma';
  }

  int epoch(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  group('jwtExpiry', () {
    test('lee el claim exp', () {
      final exp = DateTime.utc(2026, 9, 30, 14, 1, 39);
      expect(jwtExpiry(jwt({'id': 7, 'exp': epoch(exp)})), exp);
    });

    test('null si no hay exp o el token no se puede leer', () {
      expect(jwtExpiry(jwt({'id': 7})), isNull);
      expect(jwtExpiry('no-es-un-jwt'), isNull);
      expect(jwtExpiry('a.%%%.c'), isNull);
    });
  });

  group('AuthRepository.isLoggedIn', () {
    final now = DateTime.utc(2026, 10, 5, 19, 0);

    test('un token vencido no cuenta como sesión y se borra', () async {
      final token = jwt({'exp': epoch(DateTime.utc(2026, 9, 30, 14, 1))});
      SharedPreferences.setMockInitialValues({'jwt_token': token});

      expect(await AuthRepository(ApiClient()).isLoggedIn(now: now), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('jwt_token'), isFalse);
    });

    test('un token que vence dentro del margen pide login de nuevo', () async {
      final exp = now.add(
        AuthRepository.sessionMargin - const Duration(minutes: 1),
      );
      SharedPreferences.setMockInitialValues({
        'jwt_token': jwt({'exp': epoch(exp)}),
      });

      expect(await AuthRepository(ApiClient()).isLoggedIn(now: now), isFalse);
    });

    test('un token vigente sí cuenta', () async {
      SharedPreferences.setMockInitialValues({
        'jwt_token': jwt({'exp': epoch(now.add(const Duration(hours: 20)))}),
      });

      expect(await AuthRepository(ApiClient()).isLoggedIn(now: now), isTrue);
    });

    test('sin exp legible decide el servidor', () async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'opaco'});

      expect(await AuthRepository(ApiClient()).isLoggedIn(now: now), isTrue);
    });
  });

  group('syncPending', () {
    late AppDatabase db;
    late ApiClient client;
    late _FakeAdapter adapter;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'jwt_token': 'token'});
      ApiClient.sessionExpired.value = false;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.upsertStudents([
        for (final id in [1, 2, 3])
          StudentsCompanion(
            id: Value(id),
            rut: Value('$id'),
            nombreCompleto: Value('Alumno $id'),
            curso: const Value('1°'),
          ),
      ]);
      client = ApiClient();
      adapter = _FakeAdapter();
      client.dio.httpClientAdapter = adapter;
    });

    tearDown(() => db.close());

    Future<AssessmentRepository> withPending(List<int> studentIds) async {
      final repo = AssessmentRepository(db, client);
      for (final id in studentIds) {
        await repo.saveLocal(
          studentId: id,
          fecha: DateTime(2026, 10, 5),
          pcpm: 42,
          velocidad: 'lenta',
          nivelLogro: 'inicial',
          calidad: 'fluida',
          nivelLogroCalidad: 'inicial',
          prosodia: 'adecuada',
        );
      }
      return repo;
    }

    test('todo enviado: nada pendiente y sin falla', () async {
      final repo = await withPending([1, 2]);
      adapter.respond = (_) => (201, {'message': 'ok'});

      final report = await repo.syncPending();

      expect(report.sent, 2);
      expect(report.pending, 0);
      expect(report.failure, isNull);
      expect(await repo.pendingCount(), 0);
    });

    test('401: avisa sesión vencida, borra el token y no insiste', () async {
      final repo = await withPending([1, 2, 3]);
      adapter.respond = (_) => (401, {'error': 'Token inválido o requerido'});

      final report = await repo.syncPending();

      expect(report.failure, SyncFailure.sessionExpired);
      expect(report.pending, 3);
      expect(adapter.posts, 1, reason: 'las demás fallarían igual');
      expect(ApiClient.sessionExpired.value, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('jwt_token'), isFalse);
    });

    test('403: falla de permiso con el mensaje del servidor', () async {
      final repo = await withPending([1]);
      adapter.respond = (_) =>
          (403, {'error': 'Sin permiso para realizar esta acción'});

      final report = await repo.syncPending();

      expect(report.failure, SyncFailure.forbidden);
      expect(report.serverMessage, 'Sin permiso para realizar esta acción');
      expect(ApiClient.sessionExpired.value, isFalse);
    });

    test('un rechazo puntual no frena a las demás', () async {
      final repo = await withPending([1, 2]);
      adapter.respond = (o) => (o.data as Map)['student_id'] == 1
          ? (404, {'error': 'Estudiante no encontrado o inactivo'})
          : (201, {'message': 'ok'});

      final report = await repo.syncPending();

      expect(report.sent, 1);
      expect(report.pending, 1);
      expect(report.failure, SyncFailure.rejected);
    });

    // Lo que pidió el usuario: pase lo que pase con el envío, la lectura del
    // niño queda en la tablet como pendiente y no hay que repetirla.
    for (final (label, status) in [
      ('400', 400),
      ('401', 401),
      ('403', 403),
      ('404', 404),
      ('409', 409),
      ('500', 500),
      ('sin red', null),
    ]) {
      test('ninguna falla borra la evaluación ($label)', () async {
        final repo = await withPending([2]);
        adapter.respond = (_) => (status ?? 0, {'error': 'x'});
        adapter.offline = status == null;

        for (var intento = 0; intento < 3; intento++) {
          final report = await repo.syncPending();
          expect(report.pending, 1);
          expect(report.failure, isNotNull);
        }

        final pendientes = await db.getPendingWithStudent();
        expect(pendientes, hasLength(1));
        final (session, student) = pendientes.single;
        expect(session.pcpm, 42);
        expect(session.synced, isFalse);
        expect(student?.nombreCompleto, 'Alumno 2');
      });
    }

    test('dos envíos simultáneos no suben dos veces la misma', () async {
      final repo = await withPending([1, 2]);
      adapter.respond = (_) => (201, {'message': 'ok'});

      await Future.wait([repo.syncPending(), repo.syncPending()]);

      expect(adapter.posts, 2);
      expect(await repo.pendingCount(), 0);
    });
  });

  group('PendingEvaluationsScreen', () {
    for (final (label, size, scale) in [
      ('tablet', const Size(1280, 800), 1.0),
      ('teléfono con texto grande', const Size(360, 640), 1.3),
    ]) {
      testWidgets('muestra la evaluación guardada ($label)', (tester) async {
        SharedPreferences.setMockInitialValues({});
        ApiClient.sessionExpired.value = false;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.upsertStudents([
          const StudentsCompanion(
            id: Value(399),
            rut: Value('1'),
            nombreCompleto: Value('Josefa Antonia Mardones Riquelme'),
            curso: Value('1°'),
          ),
        ]);
        await AssessmentRepository(db, ApiClient()).saveLocal(
          studentId: 399,
          fecha: DateTime(2026, 10, 5, 16, 12),
          pcpm: 38.5,
          velocidad: 'lenta',
          nivelLogro: 'inicial',
          calidad: 'palabra_a_palabra',
          nivelLogroCalidad: 'inicial',
          prosodia: 'adecuada',
        );

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: MaterialApp(
              theme: AppTheme.light,
              home: PendingEvaluationsScreen(db: db),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Josefa Antonia Mardones Riquelme'), findsOneWidget);
        expect(find.textContaining('05/10/2026 16:12'), findsOneWidget);
        expect(find.textContaining('PCPM 38.5'), findsOneWidget);
        expect(find.text('Enviar ahora'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('SyncResultCard', () {
    Widget card(
      SyncStatus status, {
      bool expired = false,
      SyncDestination destination = SyncDestination.anahuac,
    }) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SyncResultCard(
          status: status,
          sessionExpired: expired,
          destination: destination,
        ),
      ),
    );

    testWidgets('confirmada por el servidor', (tester) async {
      await tester.pumpWidget(card(const SyncStatus()));
      expect(find.text('Guardada en Anahuac'), findsOneWidget);
    });

    testWidgets('en curso', (tester) async {
      await tester.pumpWidget(
        card(const SyncStatus(pending: 1, sending: true)),
      );
      expect(find.text('Enviando a Anahuac…'), findsOneWidget);
    });

    testWidgets('sin red: queda en la tablet y no hay que repetir', (
      tester,
    ) async {
      await tester.pumpWidget(
        card(const SyncStatus(pending: 1, failure: SyncFailure.unreachable)),
      );
      expect(find.text('Guardada solo en esta tablet'), findsOneWidget);
      expect(find.textContaining('No hace falta repetir'), findsOneWidget);
    });

    testWidgets('sesión vencida gana aunque no queden pendientes', (
      tester,
    ) async {
      await tester.pumpWidget(card(const SyncStatus(), expired: true));
      expect(find.text('Guardada solo en esta tablet'), findsOneWidget);
      expect(find.textContaining('sesión venció'), findsOneWidget);
    });

    // v1.0.47 decía "Enviada a Anahuac" en modo prueba. Desde que la prueba
    // respalda resultados, la tarjeta dice dónde quedaron, y nunca Anahuac.
    testWidgets('colegio de prueba: respaldo propio, nunca Anahuac', (
      tester,
    ) async {
      final trial = SyncDestination.trial('Colegio San José');
      await tester.pumpWidget(card(const SyncStatus(), destination: trial));
      expect(find.text('Respaldada'), findsOneWidget);
      expect(find.textContaining('Colegio San José'), findsOneWidget);
      expect(find.textContaining('Anahuac'), findsNothing);

      await tester.pumpWidget(
        card(const SyncStatus(pending: 1, sending: true), destination: trial),
      );
      expect(find.text('Respaldando…'), findsOneWidget);
      expect(find.textContaining('Anahuac'), findsNothing);
    });
  });

  group('SyncStatusBanner', () {
    Widget banner(SyncStatus status, {bool sessionExpired = false}) =>
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ResponsiveScope(
              builder: (context, r) => SyncStatusBanner(
                status: status,
                sessionExpired: sessionExpired,
                onRetry: () {},
                onLogin: () {},
                onShowPending: () {},
              ),
            ),
          ),
        );

    testWidgets('no ocupa lugar si todo está enviado', (tester) async {
      await tester.pumpWidget(banner(const SyncStatus()));
      expect(
        find.descendant(
          of: find.byType(SyncStatusBanner),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    testWidgets('sesión vencida ofrece volver a entrar', (tester) async {
      await tester.pumpWidget(
        banner(const SyncStatus(pending: 1), sessionExpired: true),
      );
      expect(find.text('Tu sesión venció'), findsOneWidget);
      expect(find.textContaining('1 evaluación guardada'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });

    testWidgets('sin red muestra cuántas faltan y permite reintentar', (
      tester,
    ) async {
      await tester.pumpWidget(
        banner(const SyncStatus(pending: 2, failure: SyncFailure.unreachable)),
      );
      expect(find.text('2 evaluaciones sin enviar'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Ver evaluaciones'), findsOneWidget);
    });
  });
}

class _FakeAdapter implements HttpClientAdapter {
  (int, Map<String, dynamic>) Function(RequestOptions) respond = (_) =>
      (500, {});
  int posts = 0;
  bool offline = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST') posts++;
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
