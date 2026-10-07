import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../assessment/presentation/widgets/formatting.dart';
import '../data/trial_repository.dart';

/// Resultados del colegio de prueba con que se entró, curso por curso.
///
/// Solo se llega desde la evaluación en modo prueba, o sea, después de entrar
/// con correo + PIN; el servidor entrega únicamente los del colegio del token.
/// Muestra también a los alumnos del listado que aún no tienen evaluación: en
/// una prueba lo primero que se quiere saber es a quién falta evaluar.
class TrialResultsScreen extends StatefulWidget {
  const TrialResultsScreen({
    super.key,
    required this.session,
    this.initialCurso,
    this.repository,
  });

  final TrialSession session;

  /// El curso que estaba elegido en la evaluación, para abrir directo en él.
  final String? initialCurso;

  /// Inyectable para pruebas.
  final TrialRepository? repository;

  @override
  State<TrialResultsScreen> createState() => _TrialResultsScreenState();
}

class _TrialResultsScreenState extends State<TrialResultsScreen> {
  late final TrialRepository _repo = widget.repository ?? TrialRepository();
  TrialResultsLoad? _data;
  String? _curso;

  @override
  void initState() {
    super.initState();
    _curso = widget.initialCurso;
    _refresh();
  }

  Future<void> _refresh() async {
    final data = await _repo.fetchResults(widget.session);
    if (mounted) setState(() => _data = data);
  }

  List<String> _cursos(List<TrialResult> results) => {
    ...widget.session.students.map((s) => s.curso),
    ...results.map((r) => r.curso),
  }.where((c) => c.isNotEmpty).toList()..sort();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _data;

    return Scaffold(
      backgroundColor: AppTheme.appBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.headerBackground,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Resultados'),
            Text(
              widget.session.colegio,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ResponsiveScope(
          builder: (context, r) {
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final cursos = _cursos(data.results);
            final curso = cursos.contains(_curso)
                ? _curso
                : (cursos.isEmpty ? null : cursos.first);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: EdgeInsets.all(r.spacing.lg),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (data.error != null) ...[
                            _Notice(message: data.error!),
                            SizedBox(height: r.spacing.md),
                          ],
                          if (curso == null)
                            Text(
                              'Todavía no hay evaluaciones guardadas.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppTheme.ink,
                              ),
                            )
                          else ...[
                            Wrap(
                              spacing: r.spacing.sm,
                              runSpacing: r.spacing.sm,
                              children: [
                                for (final c in cursos)
                                  ChoiceChip(
                                    label: Text(c),
                                    selected: c == curso,
                                    onSelected: (_) =>
                                        setState(() => _curso = c),
                                  ),
                              ],
                            ),
                            SizedBox(height: r.spacing.lg),
                            _CursoResults(
                              results: data.results
                                  .where((x) => x.curso == curso)
                                  .toList(),
                              roster: widget.session.students
                                  .where((s) => s.curso == curso)
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CursoResults extends StatelessWidget {
  const _CursoResults({required this.results, required this.roster});

  final List<TrialResult> results;
  final List<Student> roster;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    // Agrupa por alumno conservando el orden de llegada (más reciente primero).
    final porAlumno = <int?, List<TrialResult>>{};
    for (final x in results) {
      porAlumno.putIfAbsent(x.alumnoId, () => []).add(x);
    }
    final nombres = {for (final s in roster) s.id: s.nombreCompleto};
    String nombre(int? id) =>
        nombres[id] ??
        porAlumno[id]!.first.alumno ??
        (id == null ? 'Sin alumno asignado' : 'Alumno #$id');

    final evaluados = porAlumno.keys.whereType<int>().toList()
      ..sort((a, b) => nombre(a).compareTo(nombre(b)));
    final sinEvaluar = roster
        .where((s) => !porAlumno.containsKey(s.id))
        .map((s) => s.nombreCompleto)
        .toList();

    final resumen = [
      results.length == 1 ? '1 evaluación' : '${results.length} evaluaciones',
      if (roster.isNotEmpty)
        '${roster.length - sinEvaluar.length} de ${roster.length} alumnos '
            'evaluados',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          resumen,
          style: theme.textTheme.titleSmall?.copyWith(color: AppTheme.muted),
        ),
        SizedBox(height: r.spacing.md),
        for (final id in evaluados) ...[
          _StudentCard(name: nombre(id), results: porAlumno[id]!),
          SizedBox(height: r.spacing.sm),
        ],
        if (porAlumno.containsKey(null)) ...[
          _StudentCard(name: nombre(null), results: porAlumno[null]!),
          SizedBox(height: r.spacing.sm),
        ],
        if (sinEvaluar.isNotEmpty) ...[
          SizedBox(height: r.spacing.sm),
          _NotEvaluatedCard(names: sinEvaluar),
        ],
      ],
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.name, required this.results});

  final String name;
  final List<TrialResult> results;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.spacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.radii.card),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (results.length > 1)
                Text(
                  '${results.length} lecturas',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                  ),
                ),
            ],
          ),
          for (final (i, x) in results.indexed) ...[
            if (i > 0) Divider(height: r.spacing.lg),
            SizedBox(height: i == 0 ? r.spacing.sm : 0),
            _ResultLine(result: x),
          ],
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.result});

  static final _fecha = DateFormat('dd/MM/yyyy HH:mm');

  final TrialResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final x = result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [_fecha.format(x.fecha), if (x.lectura != null) x.lectura!].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
        ),
        SizedBox(height: r.spacing.xs),
        Wrap(
          spacing: r.spacing.sm,
          runSpacing: r.spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'PCPM ${x.pcpm.toStringAsFixed(1)}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            _LevelBadge(level: x.nivelLogro),
            if (x.pending)
              const _Badge(
                label: 'Sin respaldar',
                ink: AppTheme.warningInk,
                surface: AppTheme.warningSurface,
              ),
          ],
        ),
        SizedBox(height: r.spacing.xs),
        Text(
          '${formatChoiceLabel(x.velocidad)} · '
          'Calidad ${formatChoiceLabel(x.calidad).toLowerCase()} · '
          'Prosodia ${formatChoiceLabel(x.prosodia).toLowerCase()}',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.ink),
        ),
      ],
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final (ink, surface) = switch (level) {
      'Lo Esperado' => (AppTheme.successInk, AppTheme.successSurface),
      'Bajo lo Esperado' => (AppTheme.warningInk, AppTheme.warningSurface),
      'Muy Bajo lo Esperado' => (
        AppTheme.readingErrorInk,
        AppTheme.readingErrorSurface,
      ),
      _ => (AppTheme.muted, AppTheme.surfaceAlt),
    };
    return _Badge(label: level, ink: ink, surface: surface);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.ink, required this.surface});

  final String label;
  final Color ink;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.spacing.sm,
        vertical: r.spacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NotEvaluatedCard extends StatelessWidget {
  const _NotEvaluatedCard({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(r.radii.card),
        border: Border.all(color: AppTheme.surfaceStrong),
      ),
      child: Theme(
        // Sin las líneas que `ExpansionTile` dibuja al abrirse.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            'Sin evaluar (${names.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            r.spacing.md,
            0,
            r.spacing.md,
            r.spacing.md,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final n in names)
              Padding(
                padding: EdgeInsets.symmetric(vertical: r.spacing.xs / 2),
                child: Text(
                  n,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.spacing.md),
      decoration: BoxDecoration(
        color: AppTheme.warningSurface,
        borderRadius: BorderRadius.circular(r.radii.control),
        border: Border.all(color: AppTheme.warningBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: r.type.iconSm,
            color: AppTheme.warningIcon,
          ),
          SizedBox(width: r.spacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.warningInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
