import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_version_text.dart';
import '../../assessment/presentation/assessment_screen.dart';

final _authRepoProvider = Provider((ref) => AuthRepository(ApiClient()));

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(_authRepoProvider);
      await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AssessmentScreen()),
      );
    } catch (e) {
      setState(() => _error = 'Credenciales inválidas. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSubmit =
        !_loading &&
        _emailCtrl.text.trim().isNotEmpty &&
        _passCtrl.text.isNotEmpty;

    return Scaffold(
      body: ColoredBox(
        color: AppTheme.appBackground,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: -120,
                top: -80,
                child: _buildBackdropOrb(
                  size: 360,
                  color: AppTheme.secondary.withValues(alpha: 0.16),
                ),
              ),
              Positioned(
                right: -80,
                top: 36,
                child: _buildBackdropOrb(
                  size: 280,
                  color: AppTheme.tertiary.withValues(alpha: 0.14),
                ),
              ),
              Positioned(
                right: 180,
                bottom: -120,
                child: _buildBackdropOrb(
                  size: 420,
                  color: AppTheme.primary.withValues(alpha: 0.12),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 980;
                  final maxWidth = isCompact ? 760.0 : 1240.0;
                  final panelSpacing = isCompact ? 20.0 : 28.0;

                  final heroPanel = _buildHeroPanel(context, isCompact);
                  final loginPanel = Container(
                    width: isCompact ? double.infinity : 440,
                    padding: EdgeInsets.all(isCompact ? 24 : 32),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 16,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Acceso institucional',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Iniciar sesión',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Accede con tu cuenta para sincronizar cursos, evaluar lecturas y revisar resultados en una experiencia preparada para tablets.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.muted,
                            ),
                          ),
                          const SizedBox(height: 28),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'Correo electrónico',
                              hintText: 'nombre@institucion.cl',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              hintText: 'Ingresa tu contraseña',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) {
                              if (canSubmit) _login();
                            },
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _error == null
                                ? const SizedBox(height: 20)
                                : Container(
                                    key: const ValueKey('login-error'),
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(top: 20),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFCE7F3),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0xFFFBB6CE),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Color(0xFFE53E3E),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: const Color(0xFF9B2335),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          SizedBox(height: _error == null ? 4 : 20),
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: FilledButton(
                              onPressed: canSubmit ? _login : null,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: _loading
                                    ? const SizedBox(
                                        key: ValueKey('login-loading'),
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        key: const ValueKey('login-label'),
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.login_rounded),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Ingresar a ProsodIA',
                                            style: theme.textTheme.labelLarge,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.surfaceAlt),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.tablet_mac_outlined,
                                  color: AppTheme.secondary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Interfaz optimizada para sesiones de evaluación en tablets, con lectura cómoda y controles rápidos para la revisión.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: AppVersionText(
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.muted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: isCompact
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  heroPanel,
                                  SizedBox(height: panelSpacing),
                                  loginPanel,
                                ],
                              )
                            : IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: heroPanel),
                                    SizedBox(width: panelSpacing),
                                    loginPanel,
                                  ],
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPanel(BuildContext context, bool isCompact) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(isCompact ? 24 : 36),
      decoration: BoxDecoration(
        color: AppTheme.headerBackground,
        borderRadius: BorderRadius.circular(36),
        boxShadow: AppTheme.softShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -32,
            top: -20,
            child: Container(
              width: isCompact ? 160 : 220,
              height: isCompact ? 160 : 220,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 40,
            bottom: -70,
            child: Container(
              width: isCompact ? 180 : 260,
              height: isCompact ? 180 : 260,
              decoration: BoxDecoration(
                color: AppTheme.tertiary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppLogo(size: 82, heroTag: 'prosodia-logo'),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            'Plataforma de evaluación lectora',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ProsodIA',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Evalúa lectura oral con una experiencia clara, rápida y atractiva para docentes y equipos de apoyo.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 24 : 36),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _HeroPill(
                    icon: Icons.offline_bolt_outlined,
                    label: 'Operación offline-first',
                  ),
                  _HeroPill(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Apoyo con IA para revisión',
                  ),
                  _HeroPill(
                    icon: Icons.screen_rotation_alt_outlined,
                    label: 'Diseñada para tablets',
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 24 : 36),
              Container(
                padding: EdgeInsets.all(isCompact ? 18 : 22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: isCompact
                    ? const Column(
                        children: [
                          _HeroMetric(
                            icon: Icons.library_books_outlined,
                            title: 'Selección guiada',
                            subtitle: 'Curso, estudiante y lectura en un flujo claro.',
                          ),
                          SizedBox(height: 14),
                          _HeroMetric(
                            icon: Icons.graphic_eq_rounded,
                            title: 'Registro y análisis',
                            subtitle: 'Grabación, transcripción y revisión manual asistida.',
                          ),
                          SizedBox(height: 14),
                          _HeroMetric(
                            icon: Icons.insights_outlined,
                            title: 'Resultados inmediatos',
                            subtitle: 'PCPM, velocidad y calidad listos para guardar.',
                          ),
                        ],
                      )
                    : const Row(
                        children: [
                          Expanded(
                            child: _HeroMetric(
                              icon: Icons.library_books_outlined,
                              title: 'Selección guiada',
                              subtitle: 'Curso, estudiante y lectura en un flujo claro.',
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: _HeroMetric(
                              icon: Icons.graphic_eq_rounded,
                              title: 'Registro y análisis',
                              subtitle: 'Grabación, transcripción y revisión manual asistida.',
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: _HeroMetric(
                              icon: Icons.insights_outlined,
                              title: 'Resultados inmediatos',
                              subtitle: 'PCPM, velocidad y calidad listos para guardar.',
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackdropOrb({required double size, required Color color}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.76),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
