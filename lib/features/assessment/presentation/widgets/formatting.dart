// Formateadores compartidos por los widgets de la pantalla de evaluación.

String formatElapsed(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:'
    '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// `unidades_cortas` → `Unidades cortas`
///
/// Mayúscula solo inicial, como se escribe en español: con mayúscula en cada
/// palabra salía «Palabra A Palabra».
String formatChoiceLabel(String value) {
  final text = value.split('_').where((word) => word.isNotEmpty).join(' ');
  if (text.isEmpty) return text;
  return '${text[0].toUpperCase()}${text.substring(1)}';
}
