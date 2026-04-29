class AssessmentResult {
  final double pcpm;
  final String velocidad;
  final String nivelLogroVelocidad;

  const AssessmentResult({
    required this.pcpm,
    required this.velocidad,
    required this.nivelLogroVelocidad,
  });
}

class AssessmentCalculator {
  static double calcularPcpm(int palabrasLeidas, int errores, double segundos) {
    final palabrasCorrectas = palabrasLeidas - errores;
    if (palabrasCorrectas <= 0 || segundos <= 0) return 0;
    return (palabrasCorrectas / segundos) * 60;
  }

  static double calcularPrecision(int palabrasLeidas, int errores) {
    if (palabrasLeidas <= 0) return 0;
    final pctErrores = (errores / palabrasLeidas) * 100;
    return (100 - pctErrores).clamp(0, 100);
  }

  static String clasificarVelocidad(double pcpm, String curso) {
    final rangos = _rangosPorCurso[curso] ?? _rangosPorCurso['default']!;
    if (pcpm < rangos[0]) return 'Muy Lenta';
    if (pcpm < rangos[1]) return 'Lenta';
    if (pcpm < rangos[2]) return 'Medio Baja';
    if (pcpm < rangos[3]) return 'Medio Alta';
    if (pcpm < rangos[4]) return 'Rápida';
    return 'Muy Rápida';
  }

  static String clasificarNivelLogro(double pcpm, String curso) {
    final rangos = _rangosPorCurso[curso] ?? _rangosPorCurso['default']!;
    if (pcpm < rangos[1]) return 'Muy Bajo lo Esperado';
    if (pcpm < rangos[2]) return 'Bajo lo Esperado';
    return 'Lo Esperado';
  }

  // PCPM esperado por curso según estándares Mineduc Chile
  // [muy_lenta, lenta, medio_baja, medio_alta, rapida]
  static const Map<String, List<double>> _rangosPorCurso = {
    '1°': [0, 30, 50, 70, 90],
    '2°': [0, 50, 70, 90, 110],
    '3°': [0, 65, 85, 105, 125],
    '4°': [0, 80, 100, 120, 140],
    '5°': [0, 90, 110, 130, 150],
    '6°': [0, 100, 120, 140, 160],
    '7°': [0, 110, 130, 150, 170],
    '8°': [0, 120, 140, 160, 180],
    'default': [0, 80, 100, 120, 140],
  };
}
