import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/log_service.dart';
import '../../../core/network/api_client.dart';

/// Por qué quedaron evaluaciones sin enviar en el último intento.
enum SyncFailure {
  /// 401: el token venció o no hay sesión. Nada sale hasta volver a entrar.
  sessionExpired,

  /// 403: la cuenta no tiene permiso para registrar evaluaciones, o está
  /// inactiva. Lo arregla alguien en anahuac, no el docente reintentando.
  forbidden,

  /// Otro 4xx: el servidor rechazó esa evaluación en particular (ej: alumno
  /// retirado entre la evaluación y el envío).
  rejected,

  /// Sin respuesta (Wi-Fi, timeout) o 5xx: se arregla solo al reintentar.
  unreachable,
}

SyncFailure classifySyncError(Object error) {
  if (error is! DioException) return SyncFailure.unreachable;
  final status = error.response?.statusCode;
  if (status == null || status >= 500) return SyncFailure.unreachable;
  if (status == 401) return SyncFailure.sessionExpired;
  if (status == 403) return SyncFailure.forbidden;
  return SyncFailure.rejected;
}

class SyncReport {
  const SyncReport({
    required this.sent,
    required this.pending,
    this.failure,
    this.serverMessage,
  });

  final int sent;

  /// Las que siguen solo en la tablet después de este intento.
  final int pending;

  final SyncFailure? failure;

  /// El campo `error` que devolvió anahuac, para mostrarlo tal cual.
  final String? serverMessage;
}

class AssessmentRepository {
  final AppDatabase _db;
  final ApiClient _client;

  AssessmentRepository(this._db, this._client);

  Future<int> saveLocal({
    required int studentId,
    required DateTime fecha,
    required double pcpm,
    required String velocidad,
    required String nivelLogro,
    required String calidad,
    required String nivelLogroCalidad,
    required String prosodia,
    String? audioPath,
    int? appBuild,
    double? readingCpl,
  }) {
    return _db.insertAssessment(AssessmentSessionsCompanion(
      studentId: Value(studentId),
      fecha: Value(fecha),
      pcpm: Value(pcpm),
      velocidad: Value(velocidad),
      nivelLogro: Value(nivelLogro),
      calidad: Value(calidad),
      nivelLogroCalidad: Value(nivelLogroCalidad),
      prosodia: Value(prosodia),
      audioPath: Value(audioPath),
      appBuild: Value(appBuild),
      readingCpl: Value(readingCpl),
      synced: const Value(false),
    ));
  }

  // Serializa los envíos. Se disparan al abrir la pantalla, tras cada guardado
  // y desde el botón de reintentar; dos corridas en paralelo leerían la misma
  // fila pendiente y la subirían dos veces, duplicándola en anahuac.
  static Future<void> _queue = Future.value();

  /// Envía las evaluaciones pendientes y dice cómo terminó.
  ///
  /// Antes los errores se descartaban en silencio: el 2026-10-05 una evaluación
  /// de 1° quedó en la tablet por una sesión vencida y la docente no tenía cómo
  /// saberlo.
  Future<SyncReport> syncPending() {
    final run = _queue.then((_) => _syncPending());
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<int> pendingCount() async => (await _db.getPendingSync()).length;

  Future<SyncReport> _syncPending() async {
    final pending = await _db.getPendingSync();
    var sent = 0;
    SyncFailure? failure;
    String? serverMessage;

    for (final session in pending) {
      try {
        await _client.dio.post('/utp/velocidad-lectora', data: {
          'student_id': session.studentId,
          'pcpm': session.pcpm,
          'velocidad': session.velocidad,
          'nivel_logro_velocidad': session.nivelLogro,
          'calidad': session.calidad,
          'nivel_logro_calidad': session.nivelLogroCalidad,
          'prosodia': session.prosodia,
          'fecha': session.fecha.toIso8601String().split('T')[0],
          'semestre': session.fecha.month <= 7 ? 1 : 2,
          'app_build': session.appBuild,
          'reading_cpl': session.readingCpl,
        });
        await _db.markSynced(session.id);
        sent++;
      } catch (e) {
        failure = classifySyncError(e);
        serverMessage = _serverMessage(e);
        log.warn(
          'Evaluación ${session.id} sin enviar (${failure.name})'
          '${serverMessage == null ? '' : ': $serverMessage'}',
        );
        // Un rechazo puntual no impide enviar las demás. Sin sesión, sin
        // permiso o sin red, las que siguen fallarían igual, y cada una
        // esperaría su propio timeout.
        if (failure != SyncFailure.rejected) break;
      }
    }

    if (sent > 0) log.info('Evaluaciones enviadas: $sent');
    return SyncReport(
      sent: sent,
      pending: pending.length - sent,
      failure: failure,
      serverMessage: serverMessage,
    );
  }

  static String? _serverMessage(Object error) {
    if (error is! DioException) return null;
    final data = error.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    return null;
  }
}
