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
    required this.onShowPending,
  });

  final SyncStatus status;
  final bool sessionExpired;

  /// Abre la lista de evaluaciones guardadas en la tablet.
  final VoidCallback? onShowPending;

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
    final showList = status.pending > 0 && !status.sending;

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
            if (action != null || showList) ...[
              SizedBox(height: r.spacing.sm),
              Wrap(
                spacing: r.spacing.sm,
                runSpacing: r.spacing.xs,
                children: [
                  if (action != null) action,
                  if (showList)
                    TextButton.icon(
                      onPressed: onShowPending,
                      icon: const Icon(Icons.list_alt_outlined),
                      label: const Text('Ver evaluaciones'),
                    ),
                ],
              ),
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

/// Estado del envío en el diálogo de resultado, arriba de los números.
///
/// Antes era una línea chica al final del diálogo y el docente no se enteraba
/// de si la evaluación había llegado a Anahuac. Ahora es lo primero que se ve:
/// verde cuando el servidor la confirmó, ámbar cuando quedó solo en la tablet.
///
/// Medidas fijas y no de `context.responsive`: vive dentro de un diálogo, que
/// es otra ruta y queda fuera del `ResponsiveScope` de la pantalla.
class SyncResultCard extends StatelessWidget {
  const SyncResultCard({
    super.key,
    required this.status,
    required this.sessionExpired,
    required this.trial,
  });

  final SyncStatus status;
  final bool sessionExpired;

  /// Modo prueba: no se guarda ni se envía nada. Sin esto la tarjeta decía
  /// "Guardada en Anahuac", porque el estado de envío queda en cero pendientes.
  final bool trial;

  static const _noRepetir = 'No hace falta repetir la lectura.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (
      IconData? icon,
      Color ink,
      Color surface,
      Color border,
      String title,
      String detail,
    ) = switch (status) {
      _ when trial => (
        Icons.science_outlined,
        AppTheme.muted,
        AppTheme.surfaceAlt,
        AppTheme.surfaceStrong,
        'Modo prueba',
        'Este resultado no se guarda ni se envía a Anahuac.',
      ),
      _ when sessionExpired => (
        Icons.lock_clock_outlined,
        AppTheme.warningInk,
        AppTheme.warningSurface,
        AppTheme.warningBorder,
        'Guardada solo en esta tablet',
        'Tu sesión venció. Se enviará cuando vuelvas a iniciar sesión. $_noRepetir',
      ),
      SyncStatus(sending: true) => (
        null,
        AppTheme.muted,
        AppTheme.surfaceAlt,
        AppTheme.surfaceStrong,
        'Enviando a Anahuac…',
        'Ya quedó guardada en esta tablet.',
      ),
      SyncStatus(pending: 0) => (
        Icons.check_circle_rounded,
        AppTheme.successInk,
        AppTheme.successSurface,
        AppTheme.successBorder,
        'Guardada en Anahuac',
        'Ya aparece en Velocidad Lectora de UTP.',
      ),
      _ => (
        Icons.cloud_off_outlined,
        AppTheme.warningInk,
        AppTheme.warningSurface,
        AppTheme.warningBorder,
        'Guardada solo en esta tablet',
        '${_motivo(status)} $_noRepetir',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: icon == null
                ? Padding(
                    padding: const EdgeInsets.all(4),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: ink,
                    ),
                  )
                : Icon(icon, size: 28, color: ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: theme.textTheme.bodyMedium?.copyWith(color: ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _motivo(SyncStatus status) => switch (status.failure) {
    SyncFailure.forbidden =>
      '${status.serverMessage ?? 'Tu cuenta no tiene permiso para registrar evaluaciones.'} '
          'Pide a UTP que revise tu usuario.',
    SyncFailure.rejected =>
      'El servidor la rechazó${status.serverMessage == null ? '.' : ': ${status.serverMessage}.'}',
    _ =>
      'No hay conexión con el servidor. Se enviará sola en el próximo intento.',
  };
}
