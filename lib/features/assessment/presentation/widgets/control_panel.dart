import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../eval_state.dart';
import 'formatting.dart';
import 'surfaces.dart';

/// Panel de control de la evaluación: preparación, lectura activa, cronómetro,
/// botón de grabación y —cuando corresponde— el formulario de revisión.
class AssessmentControlPanel extends StatelessWidget {
  const AssessmentControlPanel({
    super.key,
    required this.state,
    required this.cursos,
    required this.selectedCurso,
    required this.onCursoChanged,
    required this.studentsInCurso,
    required this.selectedStudent,
    required this.onStudentChanged,
    required this.selectedTexto,
    required this.elapsed,
    required this.timerKey,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.manualReview,
    required this.scrollController,
    required this.scrollable,
  });

  final EvalState state;

  final List<String> cursos;
  final String? selectedCurso;
  final ValueChanged<String?>? onCursoChanged;

  final List<Student> studentsInCurso;
  final Student? selectedStudent;
  final ValueChanged<Student?>? onStudentChanged;

  final ReadingText? selectedTexto;
  final Duration elapsed;
  final Key timerKey;

  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  /// Formulario de revisión manual, construido por la pantalla. `null` fuera del
  /// estado [EvalState.reviewing].
  final Widget? manualReview;

  final ScrollController? scrollController;

  /// `true` cuando el panel tiene altura acotada y hace scroll por su cuenta.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _WorkflowHeader(
          hasCurso: selectedCurso != null,
          hasStudent: selectedStudent != null,
          hasReading: selectedTexto != null,
        ),
        SizedBox(height: r.spacing.md),
        _PreparationCard(
          cursos: cursos,
          selectedCurso: selectedCurso,
          onCursoChanged: onCursoChanged,
          studentsInCurso: studentsInCurso,
          selectedStudent: selectedStudent,
          onStudentChanged: onStudentChanged,
        ),
        if (selectedTexto != null) ...[
          SizedBox(height: r.spacing.md),
          _SelectedReadingCard(
            text: selectedTexto!,
            cursoLabel: selectedCurso ?? '',
          ),
        ],
        SizedBox(height: r.spacing.xl),
        _TimerCard(cardKey: timerKey, elapsed: elapsed, state: state),
        SizedBox(height: r.spacing.md),
        if (state == EvalState.analyzing)
          const _ProcessingCard()
        else if (state != EvalState.reviewing)
          _RecordButton(
            state: state,
            onStart: onStartRecording,
            onStop: onStopRecording,
            enabled: selectedStudent != null && selectedTexto != null,
          ),
        if (manualReview != null) ...[
          SizedBox(height: r.spacing.xl),
          manualReview!,
        ],
      ],
    );

    if (!scrollable) return content;
    return SingleChildScrollView(controller: scrollController, child: content);
  }
}

class _WorkflowHeader extends StatelessWidget {
  const _WorkflowHeader({
    required this.hasCurso,
    required this.hasStudent,
    required this.hasReading,
  });

  final bool hasCurso;
  final bool hasStudent;
  final bool hasReading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final diameter = r.isShortViewport ? 32.0 : 40.0;

    return Container(
      padding: EdgeInsets.all(r.spacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(r.radii.surface),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: diameter,
                height: diameter,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceStrong,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.track_changes_rounded,
                  size: r.type.iconMd,
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(width: r.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Flujo de evaluación',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!r.isShortViewport) ...[
                      SizedBox(height: r.spacing.xs),
                      Text(
                        'Mantén el orden recomendado para una sesión rápida y '
                        'consistente.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r.spacing.lg),
          WorkflowChips(
            hasCurso: hasCurso,
            hasStudent: hasStudent,
            hasReading: hasReading,
          ),
        ],
      ),
    );
  }
}

class _PreparationCard extends StatelessWidget {
  const _PreparationCard({
    required this.cursos,
    required this.selectedCurso,
    required this.onCursoChanged,
    required this.studentsInCurso,
    required this.selectedStudent,
    required this.onStudentChanged,
  });

  final List<String> cursos;
  final String? selectedCurso;
  final ValueChanged<String?>? onCursoChanged;
  final List<Student> studentsInCurso;
  final Student? selectedStudent;
  final ValueChanged<Student?>? onStudentChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return SectionCard(
      title: 'Preparación',
      subtitle: 'Selecciona curso y estudiante antes de elegir la lectura.',
      icon: Icons.how_to_reg_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Curso', style: theme.textTheme.titleSmall),
          SizedBox(height: r.spacing.sm),
          DropdownButtonFormField<String>(
            value: selectedCurso,
            isExpanded: true,
            decoration: const InputDecoration(hintText: 'Seleccionar curso'),
            items: [
              for (final curso in cursos)
                DropdownMenuItem(
                  value: curso,
                  child: Text(curso, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onCursoChanged,
          ),
          SizedBox(height: r.spacing.md),
          Text('Estudiante', style: theme.textTheme.titleSmall),
          SizedBox(height: r.spacing.sm),
          DropdownButtonFormField<Student>(
            value: selectedStudent,
            isExpanded: true,
            decoration: const InputDecoration(
              hintText: 'Seleccionar estudiante',
            ),
            items: [
              for (final student in studentsInCurso)
                DropdownMenuItem(
                  value: student,
                  child: Text(
                    student.nombreCompleto,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onStudentChanged,
          ),
        ],
      ),
    );
  }
}

class _SelectedReadingCard extends StatelessWidget {
  const _SelectedReadingCard({required this.text, required this.cursoLabel});

  final ReadingText text;
  final String cursoLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return SectionCard(
      title: 'Lectura seleccionada',
      subtitle: 'Este texto queda activo para la evaluación actual.',
      icon: Icons.menu_book_rounded,
      backgroundColor: AppTheme.surface,
      child: Container(
        padding: EdgeInsets.all(r.spacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r.radii.card),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text.titulo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: r.spacing.sm),
            Wrap(
              spacing: r.spacing.sm,
              runSpacing: r.spacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InfoPill(
                  label: '${text.totalPalabras} palabras',
                  background: AppTheme.surfaceAlt,
                ),
                Text(
                  'Curso $cursoLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.cardKey,
    required this.elapsed,
    required this.state,
  });

  final Key cardKey;
  final Duration elapsed;
  final EvalState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final recording = state == EvalState.recording;
    final diameter = r.isShortViewport ? 36.0 : 48.0;

    return SizedBox(
      key: cardKey,
      child: SectionCard(
        title: 'Cronómetro',
        subtitle: 'Controla la duración total de la lectura.',
        icon: recording
            ? Icons.fiber_manual_record_rounded
            : Icons.timer_outlined,
        backgroundColor: recording ? AppTheme.dangerSurface : AppTheme.surface,
        child: Container(
          padding: EdgeInsets.all(r.spacing.xl),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r.radii.card),
            border: Border.all(
              color: recording
                  ? AppTheme.dangerBorder
                  : theme.colorScheme.outline,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  color: recording ? AppTheme.dangerHalo : AppTheme.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  recording
                      ? Icons.fiber_manual_record_rounded
                      : Icons.timer_outlined,
                  size: r.type.iconMd,
                  color: recording ? AppTheme.danger : AppTheme.primary,
                ),
              ),
              SizedBox(height: r.spacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatElapsed(elapsed),
                  style: r.type
                      .timer(theme.textTheme)
                      ?.copyWith(
                        color: recording ? AppTheme.danger : AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessingCard extends StatelessWidget {
  const _ProcessingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return SectionCard(
      title: 'Procesando audio',
      subtitle: 'Espera unos segundos mientras se completa el análisis.',
      icon: Icons.auto_awesome_rounded,
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          SizedBox(width: r.spacing.md),
          Expanded(
            child: Text(
              'Analizando lectura...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.state,
    required this.onStart,
    required this.onStop,
    required this.enabled,
  });

  final EvalState state;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final recording = state == EvalState.recording;
    // Altura mínima, no fija: con el texto escalado el botón crece en vez de
    // recortar su etiqueta.
    final minHeight = r.pick(phone: 48.0, tablet: 56.0) * r.textScale;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: recording ? AppTheme.danger : AppTheme.tertiary,
        ),
        icon: Icon(
          recording ? Icons.stop_rounded : Icons.mic_rounded,
          size: r.type.iconLg,
        ),
        label: Text(
          recording ? 'Detener lectura' : 'Iniciar evaluación',
          textAlign: TextAlign.center,
        ),
        onPressed: recording ? onStop : (enabled ? onStart : null),
      ),
    );
  }
}
