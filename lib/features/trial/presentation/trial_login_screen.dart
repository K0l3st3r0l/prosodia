import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../assessment/presentation/assessment_screen.dart';
import '../data/trial_repository.dart';

/// Entrada a la prueba con correo + PIN.
///
/// El PIN identifica al colegio de prueba y trae su listado de alumnos; los
/// entrega un administrador con `whisper/trial_admin.py`. No hay "olvidé mi
/// PIN": se pide uno nuevo a quien lo entregó.
class TrialLoginScreen extends StatefulWidget {
  const TrialLoginScreen({super.key, this.repository});

  /// Inyectable para pruebas.
  final TrialRepository? repository;

  @override
  State<TrialLoginScreen> createState() => _TrialLoginScreenState();
}

class _TrialLoginScreenState extends State<TrialLoginScreen> {
  late final TrialRepository _repo = widget.repository ?? TrialRepository();
  final _correoCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _pinFocus = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo.lastCorreo().then((correo) {
      if (!mounted || correo == null || _correoCtrl.text.isNotEmpty) return;
      setState(() => _correoCtrl.text = correo);
      _pinFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _correoCtrl.dispose();
    _pinCtrl.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_loading &&
      _correoCtrl.text.trim().isNotEmpty &&
      _pinCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await _repo.login(_correoCtrl.text, _pinCtrl.text);
      if (!mounted) return;
      // Reemplaza y no apila: al salir de la prueba se vuelve al inicio, no a
      // un formulario con el PIN todavía escrito.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AssessmentScreen(trialSession: session),
        ),
      );
    } on TrialLoginException catch (e) {
      setState(() {
        _error = e.message;
        _pinCtrl.clear();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.primary,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveScope(
          builder: (context, r) {
            final theme = Theme.of(context);

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  r.spacing.xl,
                  0,
                  r.spacing.xl,
                  r.spacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AutofillGroup(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!r.isShortViewport) ...[
                          const Center(
                            child: AppLogo(size: 64, heroTag: 'prosodia-logo'),
                          ),
                          SizedBox(height: r.spacing.lg),
                        ],
                        Text(
                          'Iniciar Prueba',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppTheme.primary,
                          ),
                        ),
                        SizedBox(height: r.spacing.xs),
                        Text(
                          'Ingresa con el correo y el PIN que te entregaron '
                          'para tu colegio.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.muted,
                          ),
                        ),
                        SizedBox(height: r.spacing.xl),
                        TextField(
                          controller: _correoCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            hintText: 'nombre@colegio.cl',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _pinFocus.requestFocus(),
                        ),
                        SizedBox(height: r.spacing.md),
                        TextField(
                          controller: _pinCtrl,
                          focusNode: _pinFocus,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'PIN',
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          SizedBox(height: r.spacing.lg),
                          _ErrorBox(message: _error!),
                        ],
                        SizedBox(height: r.spacing.xl),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: 56 * r.textScale,
                          ),
                          child: FilledButton.icon(
                            onPressed: _canSubmit ? _submit : null,
                            icon: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.play_arrow_rounded),
                            label: const Text('Entrar a la prueba'),
                          ),
                        ),
                      ],
                    ),
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.dangerSurface,
        borderRadius: BorderRadius.circular(r.radii.control),
        border: Border.all(color: AppTheme.dangerBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
