import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import 'jwt.dart';

class AuthRepository {
  final ApiClient _client;

  AuthRepository(this._client);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.dio.post('/users/login', data: {
      'email': email,
      'password': password,
    });
    final token = response.data['token'] as String;
    final user = response.data['user'] as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('user_email', email);
    ApiClient.sessionExpired.value = false;
    return user;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_email');
  }

  /// Hay sesión solo si el token existe **y no está por vencer**.
  ///
  /// Antes bastaba con que existiera: el JWT dura 24 h, así que una tablet que
  /// no se usaba desde el día anterior entraba directo con un token que el
  /// servidor rechazaba, y las evaluaciones quedaban en la tablet sin que nadie
  /// se enterara. El margen evita entrar con una sesión que vence a mitad de
  /// la jornada de evaluación; el 401 de `ApiClient` cubre lo que igual se
  /// escape.
  Future<bool> isLoggedIn({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return false;

    final exp = jwtExpiry(token);
    final limite = (now ?? DateTime.now()).toUtc().add(sessionMargin);
    if (exp != null && !exp.isAfter(limite)) {
      await prefs.remove('jwt_token');
      return false;
    }
    return true;
  }

  static const Duration sessionMargin = Duration(minutes: 30);

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
}
