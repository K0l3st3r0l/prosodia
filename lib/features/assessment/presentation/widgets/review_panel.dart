import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/stats_repository.dart';
import 'context_charts.dart';
import 'surfaces.dart';

/// Índice de palabra → tipo de error, a partir del detalle que devuelve Whisper.
Map<int, String> buildErrorMap(List<Map<String, dynamic>> erroresDetalle) => {
  for (final e in erroresDetalle)
    if (e['indice'] != null) (e['indice'] as int): (e['tipo'] as String),
};

/// Texto de la lectura con las palabras incorrectas u omitidas resaltadas.
class HighlightedReadingText extends StatelessWidget {
  const HighlightedReadingText({
    super.key,
    required this.text,
    required this.errorMap,
    required this.baseStyle,
  });

  final String text;
  final Map<int, String> errorMap;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final wordRegex = RegExp(r'[\p{L}\p{N}]+|[^\p{L}\p{N}]+', unicode: true);
    final isWordRegex = RegExp(r'^[\p{L}\p{N}]+$', unicode: true);
    final spans = <InlineSpan>[];
    var wordIdx = 0;

    for (final match in wordRegex.allMatches(text)) {
      final segment = match.group(0)!;
      if (isWordRegex.hasMatch(segment)) {
        final tipo = errorMap[wordIdx];
        final isError = tipo == 'sustitución' || tipo == 'omisión';
        spans.add(
          TextSpan(
            text: segment,
            style: baseStyle.copyWith(
              color: isError ? AppTheme.readingErrorInk : baseStyle.color,
              backgroundColor: isError
                  ? AppTheme.readingErrorSurface
                  : Colors.transparent,
            ),
          ),
        );
        wordIdx++;
      } else {
        spans.add(TextSpan(text: segment, style: baseStyle));
      }
    }

    return Text.rich(TextSpan(children: spans));
  }
}

/// Tarjeta con un texto de la comparación (el original o lo que oyó la IA).
class ReviewTextCard extends StatelessWidget {
  const ReviewTextCard({
    super.key,
    required this.label,
    required this.content,
    this.accentColor,
    this.totalWords,
    this.errorMap,
  });

  final String label;
  final String content;
  final Color? accentColor;
  final int? totalWords;
  final Map<int, String>? errorMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final accent = accentColor;
    final baseStyle = r.type.review(
      theme.textTheme,
      color: accent == null ? AppTheme.ink : AppTheme.primary,
    );
    final highlighted = errorMap != null && errorMap!.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(r.spacing.lg),
      decoration: BoxDecoration(
        color: accent == null ? Colors.white : accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(r.radii.card),
        border: Border.all(
          color: accent == null
              ? theme.colorScheme.outline
              : accent.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: r.spacing.sm,
            runSpacing: r.spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent ?? AppTheme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (totalWords != null)
                InfoPill(
                  label: '$totalWords palabras totales',
                  background: accent == null
                      ? AppTheme.surfaceAlt
                      : accent.withValues(alpha: 0.15),
                  foreground: accent ?? AppTheme.primary,
                ),
            ],
          ),
          if (highlighted) ...[
            SizedBox(height: r.spacing.sm),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.readingErrorSurface,
                    border: Border.all(color: AppTheme.readingErrorInk),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: r.spacing.xs),
                Flexible(
                  child: Text(
                    'palabra incorrecta u omitida',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: r.spacing.md),
          if (highlighted)
            HighlightedReadingText(
              text: content,
              errorMap: errorMap!,
              baseStyle: baseStyle,
            )
          else
            Text(content, style: baseStyle),
        ],
      ),
    );
  }
}

/// Área de trabajo durante la revisión: comparación de textos + contexto.
class ReviewPanel extends StatelessWidget {
  const ReviewPanel({
    super.key,
    required this.whisperFailed,
    required this.originalText,
    required this.totalWords,
    required this.transcript,
    required this.errorMap,
    required this.resultsKey,
    required this.pcpm,
    required this.velocidad,
    required this.nivelLogro,
    required this.calidad,
    required this.prosodia,
    required this.courseStats,
    required this.studentHistory,
    required this.loadingContext,
    required this.suggestions,
    required this.scrollController,
    required this.fillHeight,
  });

  final bool whisperFailed;
  final String originalText;
  final int? totalWords;
  final String? transcript;
  final Map<int, String> errorMap;
  final Key resultsKey;

  final double pcpm;
  final String velocidad;
  final String nivelLogro;
  final String calidad;
  final String prosodia;

  final CourseStats? courseStats;
  final List<StudentHistory> studentHistory;
  final bool loadingContext;
  final List<String> suggestions;

  final ScrollController? scrollController;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    final content = LayoutBuilder(
      builder: (context, constraints) {
        // Dos textos de lectura lado a lado necesitan ~360 dp cada uno para no
        // quedar por debajo de la medida mínima legible.
        final sideBySide = transcript != null && constraints.maxWidth >= 720;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sideBySide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ReviewTextCard(
                        label: 'Texto original',
                        content: originalText,
                        totalWords: totalWords,
                        errorMap: errorMap.isNotEmpty ? errorMap : null,
                      ),
                    ),
                    SizedBox(width: r.spacing.lg),
                    Expanded(
                      child: ReviewTextCard(
                        label: 'Lo que escuchó la IA',
                        content: transcript!,
                        accentColor: AppTheme.secondary,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              if (transcript != null) ...[
                ReviewTextCard(
                  label: 'Lo que escuchó la IA',
                  content: transcript!,
                  accentColor: AppTheme.secondary,
                ),
                SizedBox(height: r.spacing.lg),
              ],
              ReviewTextCard(
                label: 'Texto original',
                content: originalText,
                totalWords: totalWords,
                errorMap: errorMap.isNotEmpty ? errorMap : null,
              ),
            ],
            SizedBox(height: r.spacing.xl),
            const Divider(),
            SizedBox(height: r.spacing.lg),
            ResultsCard(
              cardKey: resultsKey,
              pcpm: pcpm,
              velocidad: velocidad,
              nivelLogro: nivelLogro,
              calidad: calidad,
              prosodia: prosodia,
            ),
            SizedBox(height: r.spacing.lg),
            CourseDistributionChart(
              stats: courseStats,
              currentCategory: velocidad,
              loading: loadingContext,
            ),
            SizedBox(height: r.spacing.lg),
            StudentProgressionChart(
              history: studentHistory,
              currentPcpm: pcpm,
              courseAverage: courseStats?.promedioPcpm,
              loading: loadingContext,
            ),
            SizedBox(height: r.spacing.lg),
            SuggestionsCard(suggestions: suggestions),
          ],
        );
      },
    );

    return Column(
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WhisperBanner(failed: whisperFailed),
        SizedBox(height: r.spacing.lg),
        if (fillHeight)
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: content,
            ),
          )
        else
          content,
      ],
    );
  }
}

class _WhisperBanner extends StatelessWidget {
  const _WhisperBanner({required this.failed});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final diameter = r.isShortViewport ? 32.0 : 40.0;

    return Container(
      padding: EdgeInsets.all(r.spacing.lg),
      decoration: BoxDecoration(
        color: failed ? AppTheme.warningSurface : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(r.radii.card),
        border: Border.all(
          color: failed ? AppTheme.warningBorder : AppTheme.surfaceStrong,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              color: failed ? const Color(0xFFFFE1B3) : AppTheme.surfaceStrong,
              shape: BoxShape.circle,
            ),
            child: Icon(
              failed ? Icons.warning_amber_rounded : Icons.auto_awesome_rounded,
              size: r.type.iconMd,
              color: failed ? AppTheme.warningIcon : AppTheme.primary,
            ),
          ),
          SizedBox(width: r.spacing.md),
          Expanded(
            child: Text(
              failed
                  ? 'Análisis no disponible. Ajusta los datos manualmente '
                        'antes de guardar.'
                  : 'La IA preparó una transcripción preliminar. Revísala y '
                        'corrige si hace falta.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: failed ? AppTheme.warningInk : AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
