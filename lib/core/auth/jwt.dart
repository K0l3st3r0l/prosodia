import 'dart:convert';

/// Vencimiento declarado en el claim `exp` de un JWT, sin verificar la firma.
///
/// Solo sirve para no entrar a evaluar con una sesión que el servidor ya va a
/// rechazar; quien decide sigue siendo el backend. `null` si el token no trae
/// `exp` o no se puede leer.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final exp = payload is Map ? payload['exp'] : null;
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}
