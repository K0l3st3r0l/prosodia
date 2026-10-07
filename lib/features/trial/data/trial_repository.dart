import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/log_service.dart';
import '../../assessment/data/assessment_repository.dart';

/// Lo que entrega el servidor al entrar con correo + PIN.
///
/// Los alumnos son de otro colegio y **no** se escriben en la tabla
/// `Students`: esa tabla es el espejo de anahuac y se reemplaza en cada
/// sincronización. Viven solo en memoria mientras dura la prueba.
class TrialSession {
  const TrialSession({
    required this.token,
    required this.colegioId,
    required this.colegio,
    required this.correo,
    required this.students,
  });

  factory TrialSession.fromJson(Map<String, dynamic> json) {
    final colegio = json['colegio'] as Map;
    final usuario = json['usuario'] as Map;
    final now = DateTime.now();
    return TrialSession(
      token: json['token'] as String,
      colegioId: colegio['id'] as String,
      colegio: colegio['nombre'] as String,
      correo: usuario['correo'] as String,
      students: [
        for (final a in (json['alumnos'] as List? ?? const []))
          Student(
            id: (a as Map)['id'] as int,
            rut: '',
            nombreCompleto: a['nombre'] as String,
            curso: a['curso'] as String,
            activo: true,
            syncedAt: now,
          ),
      ],
    );
  }

  final String token;
  final String colegioId;
  final String colegio;
  final String correo;
  final List<Student> students;

  /// Sin listado cargado la prueba funciona como antes: curso y lectura, sin
  /// alumno. Sirve para una demostración rápida a un colegio que aún no manda
  /// su Excel.
  bool get hasRoster => students.isNotEmpty;
}

/// Una evaluación de un colegio de prueba, tal como se muestra en Resultados.
class TrialResult {
  const TrialResult({
    required this.id,
    required this.alumnoId,
    required this.alumno,
    required this.curso,
    required this.fecha,
    required this.lectura,
    required this.pcpm,
    required this.velocidad,
    required this.nivelLogro,
    required this.calidad,
    required this.prosodia,
    this.pending = false,
  });

  factory TrialResult.fromJson(
    Map<String, dynamic> json, {
    bool pending = false,
  }) => TrialResult(
    id: json['id'] as String,
    alumnoId: json['alumno_id'] as int?,
    alumno: json['alumno'] as String?,
    curso: json['curso'] as String? ?? '',
    fecha: DateTime.tryParse(json['fecha'] as String? ?? '') ?? DateTime(2000),
    lectura: json['lectura'] as String?,
    pcpm: (json['pcpm'] as num?)?.toDouble() ?? 0,
    velocidad: json['velocidad'] as String? ?? '',
    nivelLogro: json['nivel_logro'] as String? ?? '',
    calidad: json['calidad'] as String? ?? '',
    prosodia: json['prosodia'] as String? ?? '',
    pending: pending,
  );

  final String id;
  final int? alumnoId;
  final String? alumno;
  final String curso;
  final DateTime fecha;
  final String? lectura;
  final double pcpm;
  final String velocidad;
  final String nivelLogro;
  final String calidad;
  final String prosodia;

  /// Guardada en esta tablet, todavía sin llegar al servidor.
  final bool pending;
}

/// Lo que devuelve [TrialRepository.fetchResults]: las del servidor más las
/// que siguen en la tablet, y si el servidor no respondió, por qué.
class TrialResultsLoad {
  const TrialResultsLoad(this.results, {this.error});

  final List<TrialResult> results;

  /// `null` si el servidor respondió. Con error igual vienen las de la tablet.
  final String? error;
}

/// Por qué no se pudo entrar, dicho para quien está frente a la tablet.
class TrialLoginException implements Exception {
  const TrialLoginException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Entrada con correo + PIN y respaldo de resultados de los colegios de prueba.
///
/// Igual que con anahuac, la tablet guarda primero y envía después: la cola
/// vive en `SharedPreferences` y no en la base local porque
/// `AssessmentSessions.studentId` es una FK a `Students`, donde estos alumnos
/// no están.
class TrialRepository {
  TrialRepository({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: kTrialUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'X-API-Key': kWhisperApiKey},
            ),
          );

  final Dio _dio;

  static const _pendingKey = 'trial_pending_results';
  static const _lastCorreoKey = 'trial_last_correo';

  // Mismo motivo que en `AssessmentRepository`: dos envíos en paralelo leerían
  // el mismo pendiente y lo subirían dos veces. El servidor deduplica por id,
  // pero no hace falta llegar a eso.
  static Future<void> _queue = Future.value();

  Future<TrialSession> login(String correo, String pin) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/login',
        data: {'correo': correo.trim(), 'pin': pin.trim()},
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCorreoKey, correo.trim());
      return TrialSession.fromJson(res.data!);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final detail = _detail(e);
      throw TrialLoginException(switch (status) {
        null =>
          'No hay conexión con el servidor. Revisa el Wi-Fi e intenta de nuevo.',
        401 => 'Correo o PIN incorrectos.',
        429 => detail ?? 'Demasiados intentos. Espera 15 minutos.',
        >= 500 =>
          'El servidor no está respondiendo. Intenta de nuevo en unos minutos.',
        _ => detail ?? 'No se pudo entrar. Intenta de nuevo.',
      });
    }
  }

  /// El último correo con que se entró, para no escribirlo cada vez. El PIN
  /// no se guarda: la tablet puede ser compartida.
  Future<String?> lastCorreo() async =>
      (await SharedPreferences.getInstance()).getString(_lastCorreoKey);

  Future<void> saveLocal(
    TrialSession session,
    Map<String, dynamic> result,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = {
      'colegio_id': session.colegioId,
      'result': {...result, 'id': result['id'] ?? newResultId()},
    };
    await prefs.setString(
      _pendingKey,
      jsonEncode([..._read(prefs), entry]),
    );
  }

  Future<int> pendingCount(TrialSession session) async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs).where((e) => e['colegio_id'] == session.colegioId).length;
  }

  Future<SyncReport> syncPending(TrialSession session) {
    final run = _queue.then((_) => _syncPending(session));
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<SyncReport> _syncPending(TrialSession session) async {
    final prefs = await SharedPreferences.getInstance();
    // Solo las de este colegio: si la tablet pasó por otro colegio de prueba,
    // las suyas esperan a que alguien de allá vuelva a entrar.
    final pending = _read(
      prefs,
    ).where((e) => e['colegio_id'] == session.colegioId).toList();
    var sent = 0;
    SyncFailure? failure;
    String? serverMessage;

    for (final entry in pending) {
      final result = Map<String, dynamic>.from(entry['result'] as Map);
      try {
        await _dio.post(
          '/results',
          data: result,
          options: Options(
            headers: {'Authorization': 'Bearer ${session.token}'},
          ),
        );
        // Se relee la cola: entre el envío y ahora pudo guardarse otra.
        final remaining = _read(prefs)
          ..removeWhere((e) => (e['result'] as Map)['id'] == result['id']);
        await prefs.setString(_pendingKey, jsonEncode(remaining));
        sent++;
      } catch (e) {
        failure = classifySyncError(e);
        serverMessage = e is DioException ? _detail(e) : null;
        // El 401 acá es el token de la prueba, no la sesión de anahuac: se
        // informa como rechazo para que el aviso no ofrezca "Iniciar sesión".
        if (failure == SyncFailure.sessionExpired) {
          failure = SyncFailure.rejected;
          serverMessage = 'la sesión de prueba venció, vuelve a entrar con tu PIN';
        }
        log.warn(
          'Resultado de prueba ${result['id']} sin enviar (${failure.name})'
          '${serverMessage == null ? '' : ': $serverMessage'}',
        );
        if (classifySyncError(e) != SyncFailure.rejected) break;
      }
    }

    if (sent > 0) log.info('Resultados de prueba respaldados: $sent');
    return SyncReport(
      sent: sent,
      pending: pending.length - sent,
      failure: failure,
      serverMessage: serverMessage,
    );
  }

  /// Resultados del colegio con que se entró, del más reciente al más antiguo.
  ///
  /// Suma las que siguen en la tablet: una evaluación recién guardada sin red
  /// tiene que aparecer igual, o la profesora la repetiría.
  Future<TrialResultsLoad> fetchResults(TrialSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final local = [
      for (final e in _read(prefs))
        if (e['colegio_id'] == session.colegioId)
          TrialResult.fromJson(
            Map<String, dynamic>.from(e['result'] as Map),
            pending: true,
          ),
    ];

    List<TrialResult> remote = const [];
    String? error;
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/results',
        options: Options(
          headers: {'Authorization': 'Bearer ${session.token}'},
        ),
      );
      remote = [
        for (final r in (res.data!['resultados'] as List))
          TrialResult.fromJson(Map<String, dynamic>.from(r as Map)),
      ];
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      error = switch (status) {
        401 => 'La sesión de prueba venció. Sal y vuelve a entrar con tu PIN.',
        null || >= 500 =>
          'No hay conexión con el servidor. Se muestran solo las evaluaciones '
              'guardadas en esta tablet.',
        _ => 'No se pudieron cargar los resultados.',
      };
      log.warn('Resultados de prueba sin cargar ($status)');
    }

    // Una que se envió entre leer la cola y la respuesta vendría dos veces.
    final remoteIds = {for (final r in remote) r.id};
    final all = [
      ...local.where((r) => !remoteIds.contains(r.id)),
      ...remote,
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
    return TrialResultsLoad(all, error: error);
  }

  static List<Map<String, dynamic>> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      log.error('Cola de resultados de prueba ilegible', e);
      return [];
    }
  }

  static String? _detail(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    return null;
  }

  static final _random = Random.secure();

  /// Lo genera la tablet para que el servidor reconozca un reintento.
  static String newResultId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${_random.nextInt(1 << 32).toRadixString(36)}';
}
