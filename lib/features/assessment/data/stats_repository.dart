import '../../../core/network/api_client.dart';

const _velocidadOrder = [
  'Muy Lenta',
  'Lenta',
  'Medio Baja',
  'Medio Alta',
  'Rápida',
  'Muy Rápida',
];

class CourseStats {
  final int total;
  final double promedioPcpm;
  // Cantidad por categoría, en orden canónico de velocidad
  final Map<String, int> distribucionVelocidad;

  const CourseStats({
    required this.total,
    required this.promedioPcpm,
    required this.distribucionVelocidad,
  });

  factory CourseStats.fromJson(Map<String, dynamic> json) {
    final rawList = (json['distribucionVelocidad'] as List<dynamic>? ?? []);
    final dist = <String, int>{for (final c in _velocidadOrder) c: 0};
    for (final item in rawList) {
      final key = item['velocidad'] as String? ?? '';
      final val = item['cantidad'];
      dist[key] = (val is int ? val : int.tryParse(val.toString()) ?? 0);
    }
    return CourseStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      promedioPcpm: (json['promedioPcpm'] as num?)?.toDouble() ?? 0.0,
      distribucionVelocidad: dist,
    );
  }
}

class StudentHistory {
  final int id;
  final DateTime fecha;
  final double pcpm;
  final String velocidad;
  final String nivelLogro;
  final String calidad;
  final String prosodia;
  final int anio;

  const StudentHistory({
    required this.id,
    required this.fecha,
    required this.pcpm,
    required this.velocidad,
    required this.nivelLogro,
    required this.calidad,
    required this.prosodia,
    required this.anio,
  });

  factory StudentHistory.fromJson(Map<String, dynamic> json) {
    return StudentHistory(
      id: (json['id'] as num).toInt(),
      fecha: DateTime.parse(json['fecha'] as String),
      pcpm: (json['pcpm'] as num).toDouble(),
      velocidad: json['velocidad'] as String? ?? '',
      nivelLogro: json['nivel_logro_velocidad'] as String? ?? '',
      calidad: json['calidad'] as String? ?? '',
      prosodia: json['prosodia'] as String? ?? '',
      anio: (json['anio'] as num).toInt(),
    );
  }
}

class StatsRepository {
  final ApiClient _client;

  StatsRepository(this._client);

  Future<CourseStats> fetchCourseStats(String curso, int anio) async {
    final response = await _client.dio.get(
      '/utp/velocidad-lectora/stats',
      queryParameters: {'curso': curso, 'anio': anio},
    );
    return CourseStats.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<StudentHistory>> fetchStudentHistory(
    int studentId, {
    int? anio,
  }) async {
    final params = <String, dynamic>{};
    if (anio != null) params['anio'] = anio;

    final response = await _client.dio.get(
      '/utp/velocidad-lectora/student/$studentId',
      queryParameters: params.isEmpty ? null : params,
    );
    final list = response.data as List<dynamic>;
    return list
        .map((e) => StudentHistory.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
