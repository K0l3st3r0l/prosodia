import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/database/app_database.dart';
import 'core/network/api_client.dart';
import 'core/auth/auth_repository.dart';
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

  final db = AppDatabase();
  final apiClient = ApiClient();
  final authRepo = AuthRepository(apiClient);

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        useMaterial3: true,
      ),
      home: startLoggedIn ? const AssessmentScreen() : const LoginScreen(),
    );
  }
}
