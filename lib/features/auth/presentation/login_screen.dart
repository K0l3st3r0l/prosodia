import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_version_text.dart';
import '../../assessment/presentation/assessment_screen.dart';

final _authRepoProvider = Provider((ref) => AuthRepository(ApiClient()));

/// Ancho desde el que la marca va en un panel lateral junto al formulario.
///
/// 340 (panel de marca mínimo) + 420 (formulario de 356 + padding de 32 por
/// lado) = 760. El diseño anterior cortaba en 980 y una tablet de 960 dp en
/// landscape caía en el apilado: el formulario quedaba entero bajo el pliegue.
const double _splitMinWidth = 760;

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

  bool get _canSubmit =>
      !_loading &&
      _emailCtrl.text.trim().isNotEmpty &&
      _passCtrl.text.isNotEmpty;

  Future<void> _login() async {
    if (!_canSubmit) return;

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
      setState(() => _error = _errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Sin red, el mensaje anterior decía «Credenciales inválidas» y el docente
  /// reintentaba la contraseña en vez de revisar el Wi-Fi.
  String _errorMessage(Object error) {
    if (error is! DioException) {
      return 'No se pudo iniciar sesión. Intenta de nuevo.';
    }
    final status = error.response?.statusCode;
    if (status == null) {
      return 'No hay conexión con el servidor. Revisa el Wi-Fi e intenta de nuevo.';
    }
    if (status >= 500) {
      return 'El servidor no está respondiendo. Intenta de nuevo en unos minutos.';
    }
    return 'Correo o contraseña incorrectos.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBackground,
      // El teclado se descuenta a mano solo en la columna del formulario: si
      // encogiera todo el cuerpo, el panel de marca se reacomodaría con cada
      // tecla que aparece y desaparece.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: ResponsiveScope(
          builder: (context, r) {
            // `isPortrait` sale del tamaño del dispositivo y no del cuerpo, así
            // que abrir el teclado no conmuta el layout: si lo hiciera, los
            // campos se re-montarían, perderían el foco y el teclado se cerraría.
            final split = !r.isPortrait && r.available.width >= _splitMinWidth;
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;
            final canPop = Navigator.of(context).canPop();

            final form = _LoginForm(
              emailCtrl: _emailCtrl,
              passCtrl: _passCtrl,
              loading: _loading,
              canSubmit: _canSubmit,
              error: _error,
              obscurePassword: _obscurePassword,
              onChanged: () => setState(() {}),
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              onSubmit: _login,
            );

            final Widget layout;
            if (split) {
              final brandWidth = (r.available.width * 0.42).clamp(340.0, 520.0);
              layout = Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: brandWidth,
                    child: _BrandPanel(showSteps: r.breakpoint.isTabletClass),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: AppTheme.surface,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: keyboard),
                        child: _Centered(
                          padding: EdgeInsets.all(r.spacing.xxl),
                          maxWidth: r.pick(
                            phone: 420.0,
                            tablet: 420.0,
                            tabletLarge: 480.0,
                          ),
                          child: form,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              layout = Padding(
                padding: EdgeInsets.only(bottom: keyboard),
                child: _Centered(
                  padding: EdgeInsets.fromLTRB(
                    r.spacing.xl,
                    canPop ? kMinTapTarget + r.spacing.sm : r.spacing.xl,
                    r.spacing.xl,
                    r.spacing.xl,
                  ),
                  maxWidth: 440,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CompactBrandHeader(r: r),
                      SizedBox(height: r.spacing.xl),
                      Container(
                        padding: EdgeInsets.all(
                          r.pick(phone: 20.0, tablet: 28.0),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(r.radii.surface),
                          border: Border.all(color: AppTheme.surfaceAlt),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: form,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!canPop) return layout;

            // Se llega desde la pantalla de modo. Android tiene gesto de volver,
            // pero en una tablet compartida no todos lo conocen, y quien entró
            // aquí buscando «Iniciar Prueba» no tiene otra salida visible.
            return Stack(
              children: [
                Positioned.fill(child: layout),
                Positioned(
                  left: r.spacing.sm,
                  top: r.spacing.sm,
                  child: IconButton(
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).maybePop(),
                    color: split ? Colors.white : AppTheme.primary,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Centra [child] cuando cabe y lo deja desplazarse cuando no.
class _Centered extends StatelessWidget {
  const _Centered({
    required this.padding,
    required this.maxWidth,
    required this.child,
  });

  final EdgeInsets padding;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - padding.vertical),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.emailCtrl,
    required this.passCtrl,
    required this.loading,
    required this.canSubmit,
    required this.error,
    required this.obscurePassword,
    required this.onChanged,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool loading;
  final bool canSubmit;
  final String? error;
  final bool obscurePassword;
  final VoidCallback onChanged;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  /// Al enfocar un campo con el teclado abierto, desplaza lo suficiente para
  /// que también quede a la vista el botón de ingresar, no solo el campo.
  static const _fieldScrollPadding = EdgeInsets.fromLTRB(20, 20, 20, 120);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Iniciar sesión',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.primary,
            ),
          ),
          SizedBox(height: r.spacing.xs),
          Text(
            'Usa el mismo correo y contraseña de la plataforma Anahuac.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
          ),
          SizedBox(height: r.spacing.xl),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.username],
            scrollPadding: _fieldScrollPadding,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'nombre@institucion.cl',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            onChanged: (_) => onChanged(),
          ),
          SizedBox(height: r.spacing.md),
          TextField(
            controller: passCtrl,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            scrollPadding: _fieldScrollPadding,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: obscurePassword
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                onPressed: onToggleObscure,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onSubmit(),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: error == null
                ? SizedBox(height: r.spacing.xl)
                : Padding(
                    key: const ValueKey('login-error'),
                    padding: EdgeInsets.symmetric(vertical: r.spacing.lg),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE7F3),
                        borderRadius: BorderRadius.circular(r.radii.control),
                        border: Border.all(color: const Color(0xFFFBB6CE)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              error!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF9B2335),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          // Altura mínima, no fija: con el texto del sistema escalado el botón
          // crece en vez de recortar su etiqueta.
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: 56 * r.textScale),
            child: FilledButton(
              onPressed: canSubmit ? onSubmit : null,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: loading
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.login_rounded),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Ingresar',
                              // Sin color propio: lo hereda del botón, que lo
                              // apaga cuando está deshabilitado.
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          SizedBox(height: r.spacing.xl),
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
    );
  }
}

/// Encabezado de marca para la columna única (portrait y pantallas angostas).
///
/// Repite la composición de la pantalla de modo —logo, nombre, bajada,
/// centrados— para que pasar de una a otra se sienta como la misma app y el
/// formulario quede a la vista sin desplazarse.
class _CompactBrandHeader extends StatelessWidget {
  const _CompactBrandHeader({required this.r});

  final Responsive r;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        AppLogo(
          size: r.pick(phone: 64.0, tablet: 80.0),
          heroTag: 'prosodia-logo',
        ),
        SizedBox(height: r.spacing.md),
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
          style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
        ),
      ],
    );
  }
}

/// Panel lateral de marca para landscape.
///
/// Ocupa el alto completo en vez de flotar como tarjeta: en una tablet
/// horizontal el formulario es corto y una tarjeta alta a su lado dejaba medio
/// panel vacío.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.showSteps});

  /// En teléfono landscape el alto no alcanza para los pasos y no aportan lo
  /// suficiente como para obligar a desplazar un panel decorativo.
  final bool showSteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final padding = r.pick(phone: 28.0, tablet: 44.0, tabletLarge: 56.0);

    return ColoredBox(
      color: AppTheme.headerBackground,
      child: ClipRect(
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _RingPainter())),
            ),
            _Centered(
              padding: EdgeInsets.symmetric(
                horizontal: padding,
                vertical: r.spacing.xxl,
              ),
              maxWidth: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppLogo(
                    size: r.pick(phone: 56.0, tablet: 72.0),
                    heroTag: 'prosodia-logo',
                    showShadow: false,
                  ),
                  SizedBox(height: r.spacing.xl),
                  Text(
                    'ProsodIA',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: r.spacing.xs),
                  Text(
                    'Evaluación de fluidez lectora',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.84),
                    ),
                  ),
                  if (showSteps) ...[
                    SizedBox(height: r.spacing.xxl),
                    const _Step(
                      number: 1,
                      title: 'Selección guiada',
                      subtitle: 'Curso, estudiante y lectura en un flujo claro.',
                    ),
                    SizedBox(height: r.spacing.lg),
                    const _Step(
                      number: 2,
                      title: 'Registro y análisis',
                      subtitle:
                          'Grabación, transcripción y revisión manual asistida.',
                    ),
                    SizedBox(height: r.spacing.lg),
                    const _Step(
                      number: 3,
                      title: 'Resultados inmediatos',
                      subtitle: 'PCPM, velocidad y calidad listos para guardar.',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paso numerado del recorrido. Número y no icono: lo que se comunica es el
/// orden de una evaluación, no tres funciones sueltas.
class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final int number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final badge = 32 * r.textScale;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: badge,
          height: badge,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          ),
          child: Text(
            '$number',
            style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
          ),
        ),
        SizedBox(width: r.spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.76),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Anillo de cronómetro del logo, en grande y a sangre en la esquina.
///
/// Solo en blanco: el arco naranja del logo repetido a esta escala competía con
/// el logo mismo y con el formulario. Trazos sólidos con alpha, sin degradados:
/// `LinearGradient` produce bandas en las GPU MediaTek de las tablets (ver
/// `AppTheme.appBackground`).
class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Arriba a la derecha: es la única esquina del panel donde no hay texto.
    final radius = size.shortestSide * 0.5;
    final center = Offset(size.width + radius * 0.08, -radius * 0.08);
    final stroke = radius * 0.1;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.08),
    );
    // El cuadrante visible va de π/2 (abajo) a π (izquierda).
    canvas.drawArc(
      rect,
      math.pi * 0.58,
      math.pi * 0.28,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => false;
}
