import 'dart:convert';
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
      final exp = now.add(AuthRepository.sessionMargin - const Duration(minutes: 1));
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
      adapter.respond =
          (_) => (403, {'error': 'Sin permiso para realizar esta acción'});

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

    test('dos envíos simultáneos no suben dos veces la misma', () async {
      final repo = await withPending([1, 2]);
      adapter.respond = (_) => (201, {'message': 'ok'});

      await Future.wait([repo.syncPending(), repo.syncPending()]);

      expect(adapter.posts, 2);
      expect(await repo.pendingCount(), 0);
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
        banner(
          const SyncStatus(pending: 2, failure: SyncFailure.unreachable),
        ),
      );
      expect(find.text('2 evaluaciones sin enviar'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}

class _FakeAdapter implements HttpClientAdapter {
  (int, Map<String, dynamic>) Function(RequestOptions) respond =
      (_) => (500, {});
  int posts = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST') posts++;
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
