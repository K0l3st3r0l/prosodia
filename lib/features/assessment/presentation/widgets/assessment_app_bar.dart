import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/app_version_text.dart';
import '../eval_state.dart';

/// Barra superior de la pantalla de evaluación.
///
/// El presupuesto horizontal está acotado explícitamente: los tres botones de
/// acción (48 dp cada uno) son funcionalidad núcleo y nunca se ocultan, así que
/// lo que cede bajo presión es el texto — primero el subtítulo, después la
/// versión, después la etiqueta del estado. La versión anterior sumaba título
/// (~200 dp) y acciones (~300 dp) sin ninguna cota y desbordaba bajo 520 dp.
class AssessmentAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AssessmentAppBar({
    super.key,
    required this.compact,
    required this.state,
    required this.syncing,
    required this.checkingUpdate,
    required this.onTitleTap,
    required this.onCheckUpdate,
    required this.onSync,
    required this.onLogout,
  });

  /// Viewport bajo. Llega por parámetro y no desde `context.responsive` porque
  /// `Scaffold` lee [preferredSize] —un getter sin `BuildContext`— para reservar
  /// el espacio de la barra: si la altura declarada y la usada divergen, queda
  /// una franja vacía o el contenido se recorta.
  final bool compact;

  final EvalState state;
  final bool syncing;
  final bool checkingUpdate;
  final VoidCallback onTitleTap;
  final VoidCallback onCheckUpdate;
  final VoidCallback onSync;
  final VoidCallback onLogout;

  static const double _compactHeight = 56;
  static const double _regularHeight = 86;

  @override
  Size get preferredSize =>
      Size.fromHeight(compact ? _compactHeight : _regularHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final short = compact;
    final width = r.available.width;

    // Bajo 600 dp el ancho solo alcanza para el estado como icono.
    final showStateLabel = width >= 600;
    final showVersion = width >= 900 && !short;
    final showSubtitle = !short && width >= 520;

    return AppBar(
      toolbarHeight: short ? _compactHeight : _regularHeight,
      titleSpacing: r.spacing.md,
      flexibleSpace: Container(color: AppTheme.headerBackground),
      title: GestureDetector(
        onTap: onTitleTap,
        behavior: HitTestBehavior.opaque,
        // El título es tocable (cinco toques abren el panel de logs). Con la
        // barra compacta el logo mide 30 dp y el área quedaba bajo el mínimo.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(
                size: short ? 30 : 42,
                heroTag: 'prosodia-logo',
                showShadow: false,
              ),
              SizedBox(width: r.spacing.md),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ProsodIA',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (showSubtitle)
                      Text(
                        'Evaluación de fluidez lectora',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        _StatePill(state: state, showLabel: showStateLabel),
        if (showVersion) ...[
          SizedBox(width: r.spacing.sm),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.spacing.md,
                vertical: r.spacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: AppVersionText(
                prefix: '',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
        SizedBox(width: r.spacing.sm),
        if (checkingUpdate)
          const _ActionSpinner()
        else
          _HeaderAction(
            icon: Icons.system_update_outlined,
            tooltip: 'Buscar actualización',
            onPressed: state == EvalState.idle ? onCheckUpdate : null,
          ),
        if (syncing)
          const _ActionSpinner()
        else
          _HeaderAction(
            icon: Icons.sync,
            tooltip: 'Sincronizar estudiantes',
            onPressed: state == EvalState.idle ? onSync : null,
          ),
        _HeaderAction(
          icon: Icons.logout,
          tooltip: 'Cerrar sesión',
          onPressed: state == EvalState.idle ? onLogout : null,
        ),
        SizedBox(width: r.spacing.sm),
      ],
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.state, required this.showLabel});

  final EvalState state;
  final bool showLabel;

  // Acentos propios del indicador de estado: no son roles reutilizables del
  // sistema, solo distinguen las cuatro etapas de un vistazo sobre el violeta.
  static const Color _idle = Color(0xFF9FE4D1);
  static const Color _recording = Color(0xFFFFC1BA);
  static const Color _analyzing = Color(0xFFFFD57A);
  static const Color _reviewing = Color(0xFFB7D8FF);

  String get _label => switch (state) {
    EvalState.idle => 'Lista para evaluar',
    EvalState.recording => 'Grabando lectura',
    EvalState.analyzing => 'Analizando audio',
    EvalState.reviewing => 'Revisión manual',
  };

  IconData get _icon => switch (state) {
    EvalState.idle => Icons.check_circle_outline_rounded,
    EvalState.recording => Icons.fiber_manual_record_rounded,
    EvalState.analyzing => Icons.auto_awesome_rounded,
    EvalState.reviewing => Icons.fact_check_outlined,
  };

  Color get _accent => switch (state) {
    EvalState.idle => _idle,
    EvalState.recording => _recording,
    EvalState.analyzing => _analyzing,
    EvalState.reviewing => _reviewing,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return Center(
      child: Tooltip(
        message: _label,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? r.spacing.md : r.spacing.sm,
            vertical: r.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: r.type.iconSm, color: _accent),
              if (showLabel) ...[
                SizedBox(width: r.spacing.xs),
                Flexible(
                  child: Text(
                    _label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        constraints: const BoxConstraints(
          minWidth: kMinTapTarget,
          minHeight: kMinTapTarget,
        ),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
          disabledForegroundColor: Colors.white54,
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _ActionSpinner extends StatelessWidget {
  const _ActionSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: kMinTapTarget,
      height: kMinTapTarget,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
    );
  }
}
