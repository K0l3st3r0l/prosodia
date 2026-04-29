import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';

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
      synced: const Value(false),
    ));
  }

  Future<void> syncPending() async {
    final pending = await _db.getPendingSync();
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
        });
        await _db.markSynced(session.id);
      } catch (_) {
        // Queda pendiente para el próximo intento
      }
    }
  }
}
