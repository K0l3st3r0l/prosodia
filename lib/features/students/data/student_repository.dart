import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_client.dart';

class StudentRepository {
  final AppDatabase _db;
  final ApiClient _client;

  StudentRepository(this._db, this._client);

  Future<void> syncFromServer() async {
    final response = await _client.dio.get('/students', queryParameters: {'activo': true});
    final List data = response.data as List;
    final rows = data.map((s) {
      final nombre1 = (s['nombre1'] as String? ?? '').trim();
      final ap = (s['apellido_paterno'] as String? ?? '').trim();
      return StudentsCompanion(
        id: Value(s['id'] as int),
        rut: Value(s['rut']?.toString() ?? ''),
        nombreCompleto: Value('$ap $nombre1'.trim()),
        curso: Value(s['curso']?.toString() ?? ''),
        activo: Value((s['activo'] as bool?) ?? true),
        syncedAt: Value(DateTime.now()),
      );
    }).toList();
    await _db.upsertStudents(rows);
  }

  Future<List<Student>> getAll() => _db.getAllStudents();

  Future<List<Student>> getByCurso(String curso) => _db.getStudentsByCurso(curso);
}
