import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/database/app_database.dart';
import 'core/network/api_client.dart';
import 'core/auth/auth_repository.dart';
import 'core/reading_texts_seed.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/assessment/presentation/assessment_screen.dart';
import 'features/ota_update/ota_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forzar modo landscape en tablets
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Pintar las barras del sistema en navy para que se camuflen con el AppBar
  // y el splash. Iconos en blanco para contrastar con fondo oscuro.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppTheme.primary,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppTheme.primary,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: AppTheme.primary,
  ));

  final db = AppDatabase();
  final apiClient = ApiClient();
  final authRepo = AuthRepository(apiClient);

  await seedReadingTexts(db);

  // Verificar actualización OTA en background (no bloquea el inicio)
  OtaService(apiClient.dio).checkAndUpdate();

  final isLoggedIn = await authRepo.isLoggedIn();

  runApp(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
      ],
      child: ProsodIAApp(startLoggedIn: isLoggedIn),
    ),
  );
}

class ProsodIAApp extends StatelessWidget {
  final bool startLoggedIn;

  const ProsodIAApp({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProsodIA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: startLoggedIn ? const AssessmentScreen() : const LoginScreen(),
    );
  }
}
