import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/log_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../data/assessment_repository.dart';
import 'widgets/formatting.dart';

/// Evaluaciones guardadas en esta tablet que todavía no llegan a anahuac.
///
/// Existe para que el docente vea que la lectura no se perdió. Antes, una
/// evaluación sin enviar no aparecía en ninguna parte, y lo natural era pedirle
/// al niño que leyera de nuevo.
class PendingEvaluationsScreen extends StatefulWidget {
  const PendingEvaluationsScreen({super.key, required this.db});

  final AppDatabase db;

  @override
  State<PendingEvaluationsScreen> createState() =>
      _PendingEvaluationsScreenState();
}

class _PendingEvaluationsScreenState extends State<PendingEvaluationsScreen> {
  static final _fecha = DateFormat('dd/MM/yyyy HH:mm');

  List<(AssessmentSession, Student?)>? _rows;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.db.getPendingWithStudent();
    if (mounted) setState(() => _rows = rows);
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    String message;
    try {
      final report = await AssessmentRepository(
        widget.db,
        ApiClient(),
      ).syncPending();
      message = _describe(report);
    } catch (e) {
      log.error('Error enviando evaluaciones', e);
      message = 'No se pudieron enviar. Siguen guardadas en esta tablet.';
    }
    await _load();
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _describe(SyncReport report) {
    final quedan = report.pending == 0
        ? ''
        : ' Las que faltan siguen guardadas en esta tablet.';
    return switch (report.failure) {
      null =>
        report.sent == 1
            ? 'Se envió 1 evaluación.'
            : 'Se enviaron ${report.sent} evaluaciones.',
      SyncFailure.sessionExpired =>
        'Tu sesión venció: vuelve a iniciar sesión para enviarlas.$quedan',
      SyncFailure.forbidden =>
        '${report.serverMessage ?? 'Tu cuenta no tiene permiso para registrar evaluaciones.'}$quedan',
      SyncFailure.rejected =>
        'El servidor rechazó una evaluación'
            '${report.serverMessage == null ? '' : ': ${report.serverMessage}'}.$quedan',
      SyncFailure.unreachable => 'No hay conexión con el servidor.$quedan',
    };
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;

    return Scaffold(
      backgroundColor: AppTheme.appBackground,
      appBar: AppBar(
        title: const Text('Evaluaciones sin enviar'),
        backgroundColor: AppTheme.headerBackground,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ResponsiveScope(
          builder: (context, r) {
            if (rows == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: EdgeInsets.all(r.spacing.lg),
                  children: [
                    _Header(
                      count: rows.length,
                      sending: _sending,
                      onSend: _send,
                    ),
                    SizedBox(height: r.spacing.lg),
                    for (final (session, student) in rows) ...[
                      _PendingTile(
                        session: session,
                        student: student,
                        fecha: _fecha.format(session.fecha),
                      ),
                      SizedBox(height: r.spacing.sm),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.sending,
    required this.onSend,
  });

  final int count;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    if (count == 0) {
      return Text(
        'No hay evaluaciones pendientes: todo lo evaluado en esta tablet ya '
        'está en Anahuac.',
        style: theme.textTheme.bodyLarge?.copyWith(color: AppTheme.ink),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: ApiClient.sessionExpired,
      builder: (context, expired, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Están guardadas en esta tablet y no se pierden al cerrar la app ni '
            'la sesión. Se envían solas al abrir la evaluación con la sesión '
            'iniciada; no hace falta que el estudiante vuelva a leer.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.ink),
          ),
          SizedBox(height: r.spacing.md),
          if (expired)
            Text(
              'Tu sesión venció: vuelve a iniciar sesión para enviarlas.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.warningInk,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            FilledButton.icon(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(sending ? 'Enviando…' : 'Enviar ahora'),
            ),
        ],
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({
    required this.session,
    required this.student,
    required this.fecha,
  });

  final AssessmentSession session;
  final Student? student;
  final String fecha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final nombre =
        student?.nombreCompleto ?? 'Estudiante #${session.studentId}';
    final curso = student?.curso;

    return Container(
      padding: EdgeInsets.all(r.spacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.radii.card),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nombre,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: r.spacing.xs),
          Text(
            [if (curso != null) curso, fecha].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
          ),
          SizedBox(height: r.spacing.xs),
          Text(
            'PCPM ${session.pcpm.toStringAsFixed(1)} · '
            '${formatChoiceLabel(session.velocidad)} · '
            'Calidad ${formatChoiceLabel(session.calidad).toLowerCase()} · '
            'Prosodia ${formatChoiceLabel(session.prosodia).toLowerCase()}',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.ink),
          ),
        ],
      ),
    );
  }
}
