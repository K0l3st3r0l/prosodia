// Formateadores compartidos por los widgets de la pantalla de evaluación.

String formatElapsed(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:'
    '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// `unidades_cortas` → `Unidades Cortas`
String formatChoiceLabel(String value) {
  final words = value.split('_').where((word) => word.isNotEmpty);
  return words
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
