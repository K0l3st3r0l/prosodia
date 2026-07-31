import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de tamaño del texto de lectura, como **posición relativa** dentro
/// del rango legible (0 = la letra más chica permitida, 1 = la más grande).
///
/// Se guarda la posición y no el `sp` a propósito. El mismo tamaño absoluto da
/// caracteres por línea distintos en cada pantalla: 24 sp son holgados en un
/// teléfono de 640 dp y quedan chicos en uno de 891. Lo que el docente quiere
/// expresar —«grande dentro de lo que se puede»— sí transfiere entre
/// dispositivos y orientaciones; un número de puntos, no.
///
/// `null` significa **sin preferencia**, y ahí el texto usa la ruta nominal de
/// siempre. Es deliberado: hasta que alguien toque el control, la app se ve
/// exactamente igual que antes de que el control existiera.
class ReadingSizePreference {
  static const String _key = 'reading_size_position';

  Future<double?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getDouble(_key);
    if (value == null) return null;
    return value.clamp(0.0, 1.0);
  }

  Future<void> write(double position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, position.clamp(0.0, 1.0));
  }
}
