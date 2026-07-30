import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/stats_repository.dart';

/// Fila etiqueta/valor de los resultados.
///
/// Ambos lados son flexibles. `'Nivel de logro: Muy Bajo lo Esperado'` son ~35
/// caracteres, y con el texto del sistema escalado la etiqueta sola puede
/// agotar el ancho de un diálogo sobre 360 dp: dejarla rígida hace que el
/// `Expanded` del valor reciba cero y la fila desborde.
class ResultRow extends StatelessWidget {
  const ResultRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Flexible(child: Text(value)),
        ],
      ),
    );
  }
}

/// Contenedor común de las tarjetas de contexto post-análisis.
class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.title,
    required this.child,
    this.loading = false,
    this.cardKey,
  });

  final String title;
  final Widget child;
  final bool loading;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return Container(
      key: cardKey,
      padding: EdgeInsets.all(r.spacing.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(r.radii.card),
        border: Border.all(color: AppTheme.surfaceStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              if (loading) ...[
                SizedBox(width: r.spacing.sm),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ],
            ],
          ),
          SizedBox(height: r.spacing.md),
          child,
        ],
      ),
    );
  }
}

/// Resultado calculado de la evaluación en curso.
class ResultsCard extends StatelessWidget {
  const ResultsCard({
    super.key,
    required this.pcpm,
    required this.velocidad,
    required this.nivelLogro,
    required this.calidad,
    required this.prosodia,
    this.cardKey,
  });

  final double pcpm;
  final String velocidad;
  final String nivelLogro;
  final String calidad;
  final String prosodia;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    return _ContextCard(
      cardKey: cardKey,
      title: 'Resultado actual',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ResultRow(label: 'PCPM', value: pcpm.toStringAsFixed(1)),
          ResultRow(label: 'Velocidad', value: velocidad),
          ResultRow(label: 'Nivel de logro', value: nivelLogro),
          ResultRow(label: 'Calidad', value: calidad),
          ResultRow(label: 'Prosodia', value: prosodia),
        ],
      ),
    );
  }
}

/// Distribución de velocidades del curso, con la categoría del estudiante
/// actual resaltada.
class CourseDistributionChart extends StatelessWidget {
  const CourseDistributionChart({
    super.key,
    required this.stats,
    required this.currentCategory,
    required this.loading,
  });

  final CourseStats? stats;
  final String? currentCategory;
  final bool loading;

  static const List<String> categories = [
    'Muy Lenta',
    'Lenta',
    'Medio Baja',
    'Medio Alta',
    'Rápida',
    'Muy Rápida',
  ];

  static const List<String> shortLabels = [
    'M.Lenta',
    'Lenta',
    'M.Baja',
    'M.Alta',
    'Rápida',
    'M.Rápida',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final data = stats;

    if (data == null) {
      return _ContextCard(
        title: 'Distribución del curso',
        loading: loading,
        child: Text(
          loading ? 'Cargando datos del curso…' : 'Sin datos del servidor',
          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
        ),
      );
    }

    return _ContextCard(
      title: 'Distribución del curso',
      loading: loading,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // El ancho de barra sale del espacio real: clavarlo en 18 dp hacía
          // que en paneles angostos las barras se pisaran con sus etiquetas.
          final barWidth = (constraints.maxWidth / categories.length * 0.45)
              .clamp(8.0, 24.0);

          return SizedBox(
            height: r.chartHeight,
            child: BarChart(
              BarChartData(
                barGroups: [
                  for (final entry in categories.asMap().entries)
                    BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: (data.distribucionVelocidad[entry.value] ?? 0)
                              .toDouble(),
                          color: entry.value == currentCategory
                              ? AppTheme.primary
                              : AppTheme.surfaceStrong,
                          width: barWidth,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30 * r.textScale,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= shortLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            shortLabels[idx],
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              fontSize: r.type.chartLabelSize,
                              color: AppTheme.muted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Progresión histórica del estudiante, con la evaluación actual como último
/// punto y el promedio del curso como referencia.
class StudentProgressionChart extends StatelessWidget {
  const StudentProgressionChart({
    super.key,
    required this.history,
    required this.currentPcpm,
    required this.courseAverage,
    required this.loading,
  });

  final List<StudentHistory> history;
  final double currentPcpm;
  final double? courseAverage;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    final ascending = [...history]..sort((a, b) => a.fecha.compareTo(b.fecha));

    if (ascending.isEmpty) {
      return _ContextCard(
        title: 'Progresión del alumno',
        loading: loading,
        child: Text(
          'Primera evaluación registrada — PCPM: '
          '${currentPcpm.toStringAsFixed(1)}',
          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
        ),
      );
    }

    final values = [...ascending.map((h) => h.pcpm), currentPcpm];
    final spots = [
      for (final entry in values.asMap().entries)
        FlSpot(entry.key.toDouble(), entry.value),
    ];

    return _ContextCard(
      title: 'Progresión del alumno',
      loading: loading,
      child: SizedBox(
        height: r.chartHeight,
        child: LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppTheme.primary,
                barWidth: 2,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) {
                    final isCurrent = index == spots.length - 1;
                    return FlDotCirclePainter(
                      radius: isCurrent ? 6 : 4,
                      color: isCurrent ? AppTheme.secondary : AppTheme.primary,
                      strokeWidth: 0,
                      strokeColor: Colors.transparent,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppTheme.primary.withValues(alpha: 0.08),
                ),
              ),
            ],
            extraLinesData: courseAverage == null
                ? ExtraLinesData()
                : ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: courseAverage!,
                        color: AppTheme.secondary.withValues(alpha: 0.6),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: TextStyle(
                            fontSize: r.type.chartLabelSize,
                            color: AppTheme.secondary,
                          ),
                          labelResolver: (line) =>
                              'Prom. ${line.y.toStringAsFixed(0)}',
                        ),
                      ),
                    ],
                  ),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
          ),
        ),
      ),
    );
  }
}

/// Sugerencias pedagógicas derivadas del resultado.
class SuggestionsCard extends StatelessWidget {
  const SuggestionsCard({super.key, required this.suggestions});

  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return _ContextCard(
      title: 'Sugerencias',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final suggestion in suggestions.take(4))
            Padding(
              padding: EdgeInsets.only(bottom: r.spacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: r.type.iconSm,
                    color: AppTheme.secondary,
                  ),
                  SizedBox(width: r.spacing.sm),
                  Expanded(
                    child: Text(suggestion, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Reglas de sugerencia, trasladadas sin cambios desde la pantalla.
List<String> buildSuggestions({
  required String nivelLogro,
  required String calidad,
  required String prosodia,
}) {
  final suggestions = <String>[];

  if (nivelLogro == 'Muy Bajo lo Esperado') {
    suggestions.add(
      'Practicar lectura oral diaria con textos de nivel inferior al del curso.',
    );
    suggestions.add(
      'Usar la técnica de lectura repetida del mismo texto hasta alcanzar '
      'fluidez básica.',
    );
  } else if (nivelLogro == 'Bajo lo Esperado') {
    suggestions.add(
      'Incrementar tiempo de lectura oral con textos adecuados al nivel del '
      'curso.',
    );
  }
  if (calidad == 'silabeando' || calidad == 'unidades_cortas') {
    suggestions.add(
      'Trabajar reconocimiento de palabras completas para reducir la silabación.',
    );
  }
  if (prosodia == 'inadecuada' || prosodia == 'básica') {
    suggestions.add(
      'Modelar lectura expresiva con textos que tengan diálogos o poemas.',
    );
  }
  if (suggestions.isEmpty) {
    suggestions.add(
      'Mantener la práctica lectora para consolidar el nivel alcanzado.',
    );
  }

  return suggestions;
}
