import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/assessment_repository.dart';

/// Estado del envío de evaluaciones a anahuac, tal como lo ve el docente.
@immutable
class SyncStatus {
  const SyncStatus({
    this.pending = 0,
    this.sending = false,
    this.failure,
    this.serverMessage,
  });

  final int pending;
  final bool sending;
  final SyncFailure? failure;
  final String? serverMessage;

  SyncStatus copyWith({bool? sending}) => SyncStatus(
    pending: pending,
    sending: sending ?? this.sending,
    failure: failure,
    serverMessage: serverMessage,
  );
}

String _evaluaciones(int n) => n == 1 ? '1 evaluación' : '$n evaluaciones';

/// Aviso de evaluaciones sin enviar, arriba del panel de control.
///
/// Existe porque el envío corre en segundo plano y antes fallaba en silencio:
/// una sesión vencida dejaba las evaluaciones en la tablet sin ninguna señal.
/// No se muestra nada mientras todo esté enviado y la sesión siga vigente.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({
    super.key,
    required this.status,
    required this.sessionExpired,
    required this.onRetry,
    required this.onLogin,
  });

  final SyncStatus status;
  final bool sessionExpired;

  /// `null` deshabilita el botón (ej: con una evaluación en curso).
  final VoidCallback? onRetry;
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    final content = _content();
    if (content == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final r = context.responsive;
    final (title, body, action) = content;

    return Padding(
      padding: EdgeInsets.only(bottom: r.spacing.md),
      child: Container(
        padding: EdgeInsets.all(r.spacing.md),
        decoration: BoxDecoration(
          color: AppTheme.warningSurface,
          borderRadius: BorderRadius.circular(r.radii.control),
          border: Border.all(color: AppTheme.warningBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (status.sending && !sessionExpired)
                  SizedBox(
                    width: r.type.iconSm,
                    height: r.type.iconSm,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.warningIcon,
                    ),
                  )
                else
                  Icon(
                    sessionExpired
                        ? Icons.lock_clock_outlined
                        : Icons.cloud_off_outlined,
                    size: r.type.iconSm,
                    color: AppTheme.warningIcon,
                  ),
                SizedBox(width: r.spacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.warningInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (body != null) ...[
              SizedBox(height: r.spacing.xs),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.warningInk,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: r.spacing.sm),
              Align(alignment: Alignment.centerLeft, child: action),
            ],
          ],
        ),
      ),
    );
  }

  (String, String?, Widget?)? _content() {
    final n = status.pending;

    if (sessionExpired) {
      return (
        'Tu sesión venció',
        n > 0
            ? 'Hay ${_evaluaciones(n)} guardada${n == 1 ? '' : 's'} en esta '
                  'tablet sin enviar. Inicia sesión de nuevo para enviarla${n == 1 ? '' : 's'}.'
            : 'Las evaluaciones se guardan en esta tablet, pero no se envían '
                  'hasta que vuelvas a iniciar sesión.',
        FilledButton.icon(
          onPressed: onLogin,
          icon: const Icon(Icons.login),
          label: const Text('Iniciar sesión'),
        ),
      );
    }

    if (n == 0) return null;

    if (status.sending) return ('Enviando ${_evaluaciones(n)}…', null, null);

    final retry = OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Reintentar'),
    );
    final titulo = '${_evaluaciones(n)} sin enviar';

    return switch (status.failure) {
      SyncFailure.forbidden => (
        titulo,
        '${status.serverMessage ?? 'Tu cuenta no tiene permiso para registrar evaluaciones.'} '
            'Pide a UTP que revise los permisos de tu usuario. Mientras tanto '
            'quedan guardadas en esta tablet.',
        retry,
      ),
      SyncFailure.rejected => (
        titulo,
        'El servidor la${n == 1 ? '' : 's'} rechazó'
            '${status.serverMessage == null ? '.' : ': ${status.serverMessage}.'} '
            'Quedan guardadas en esta tablet.',
        retry,
      ),
      _ => (
        titulo,
        'No hay conexión con el servidor. Quedan guardadas en esta tablet y '
            'se envían en el próximo intento.',
        retry,
      ),
    };
  }
}

/// Línea del diálogo de resultado que dice si la evaluación llegó a anahuac.
///
/// "Evaluación guardada" era cierto solo para la tablet; el docente lo leía
/// como "ya está en el sistema".
///
/// Medidas fijas y no de `context.responsive`: vive dentro de un diálogo, que
/// es otra ruta y queda fuera del `ResponsiveScope` de la pantalla.
class SyncResultLine extends StatelessWidget {
  const SyncResultLine({
    super.key,
    required this.status,
    required this.sessionExpired,
  });

  final SyncStatus status;
  final bool sessionExpired;

  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (IconData? icon, Color color, String text) = switch (status) {
      _ when sessionExpired => (
        Icons.lock_clock_outlined,
        AppTheme.warningInk,
        'Guardada en esta tablet, sin enviar: tu sesión venció.',
      ),
      SyncStatus(sending: true) => (
        null,
        AppTheme.muted,
        'Enviando a Anahuac…',
      ),
      SyncStatus(pending: 0) => (
        Icons.cloud_done_outlined,
        AppTheme.tertiary,
        'Enviada a Anahuac.',
      ),
      _ => (
        Icons.cloud_off_outlined,
        AppTheme.warningInk,
        'Guardada en esta tablet, sin enviar. Revisa el aviso en el panel.',
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (icon == null)
            SizedBox(
              width: _iconSize,
              height: _iconSize,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: _iconSize, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
