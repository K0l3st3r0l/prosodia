import 'package:flutter/material.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_version_text.dart';
import '../../assessment/presentation/assessment_screen.dart';
import '../../auth/presentation/login_screen.dart';

/// Primera pantalla de la app: elegir entre el uso real y el modo prueba.
///
/// Va **antes** del login a propósito. «Iniciar Prueba» no pide credenciales,
/// así que se le puede mostrar la app a alguien —una apoderada, otro colegio,
/// un docente nuevo— sin crearle una cuenta ni tocar los datos reales.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key, required this.startLoggedIn});

  /// Si ya hay sesión, «Escuela Anahuac» salta el login y entra directo.
  final bool startLoggedIn;

  Future<void> _openSchool(BuildContext context) async {
    // Se revalida acá y no solo con el valor de arranque: entre el inicio de la
    // app y este toque pudo haberse cerrado la sesión desde otra pantalla.
    final loggedIn = await AuthRepository(ApiClient()).isLoggedIn();
    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            loggedIn ? const AssessmentScreen() : const LoginScreen(),
      ),
    );
  }

  void _openTrial(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AssessmentScreen(trial: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBackground,
      body: SafeArea(
        child: ResponsiveScope(
          builder: (context, r) {
            final theme = Theme.of(context);

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(r.spacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: AppLogo(size: r.isShortViewport ? 64 : 88),
                      ),
                      SizedBox(height: r.spacing.lg),
                      Text(
                        'ProsodIA',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: AppTheme.primary,
                        ),
                      ),
                      SizedBox(height: r.spacing.xs),
                      Text(
                        'Evaluación de fluidez lectora',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                        ),
                      ),
                      SizedBox(height: r.spacing.xl),
                      _ModeButton(
                        label: 'Escuela Anahuac',
                        description: 'Evaluar alumnos y guardar resultados',
                        icon: Icons.school_rounded,
                        primary: true,
                        onPressed: () => _openSchool(context),
                      ),
                      SizedBox(height: r.spacing.md),
                      _ModeButton(
                        label: 'Iniciar Prueba',
                        description: 'Probar la app sin guardar nada',
                        icon: Icons.play_circle_outline_rounded,
                        primary: false,
                        onPressed: () => _openTrial(context),
                      ),
                      SizedBox(height: r.spacing.xl),
                      const Center(child: AppVersionText()),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.description,
    required this.icon,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final String description;
  final IconData icon;

  /// El camino real va sólido y el de prueba delineado. La jerarquía visual
  /// tiene que empujar hacia el modo que guarda datos: entrar por error a la
  /// prueba y evaluar a un niño ahí significa perder esa evaluación.
  final bool primary;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final foreground = primary ? Colors.white : AppTheme.primary;

    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: r.spacing.sm),
      child: Row(
        children: [
          Icon(icon, size: r.type.iconLg, color: foreground),
          SizedBox(width: r.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: primary
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Altura mínima, no fija: con el texto del sistema escalado el botón crece
    // en vez de recortar su descripción.
    final constraints = BoxConstraints(minHeight: 64 * r.textScale);

    if (primary) {
      return ConstrainedBox(
        constraints: constraints,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: EdgeInsets.symmetric(horizontal: r.spacing.lg),
            alignment: Alignment.centerLeft,
          ),
          child: content,
        ),
      );
    }

    return ConstrainedBox(
      constraints: constraints,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.primary, width: 1.5),
          padding: EdgeInsets.symmetric(horizontal: r.spacing.lg),
          alignment: Alignment.centerLeft,
        ),
        child: content,
      ),
    );
  }
}
