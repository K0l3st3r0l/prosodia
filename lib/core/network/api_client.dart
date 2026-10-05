import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class ApiClient {
  /// Se enciende cuando anahuac responde 401: el token guardado ya no sirve.
  ///
  /// Es global porque el 401 puede llegar desde cualquier llamada —alumnos,
  /// estadísticas, envío de evaluaciones— y la pantalla tiene que enterarse sin
  /// que cada repositorio lo propague. Solo lo apaga un login exitoso.
  static final ValueNotifier<bool> sessionExpired = ValueNotifier(false);

  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (_isExpiredSession(error)) {
          // Sin token, la próxima apertura pide login en vez de entrar directo
          // a evaluar con una sesión que ya no sirve.
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('jwt_token');
          sessionExpired.value = true;
        }
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  /// Un 401 del propio login son credenciales malas, no una sesión vencida. El
  /// host se compara porque la verificación OTA usa este mismo `Dio` contra
  /// otro servidor.
  static bool _isExpiredSession(DioException error) {
    final request = error.requestOptions;
    return error.response?.statusCode == 401 &&
        request.uri.host == Uri.parse(kBaseUrl).host &&
        !request.path.endsWith('/users/login');
  }
}
