import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';

/// Panel flotante de nivel superior: el lienzo blanco sobre el fondo lavanda.
class SurfacePanel extends StatelessWidget {
  const SurfacePanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.responsive.radii.surface);
    final panelChild = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(borderRadius: radius, child: panelChild),
    );
  }
}

/// Tarjeta de sección con encabezado. El subtítulo se oculta en viewports bajos:
/// es texto de apoyo y la altura vale más que la explicación en un teléfono en
/// landscape.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.backgroundColor,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final IconData? icon;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final showSubtitle = subtitle != null && !r.isShortViewport;

    return Container(
      padding: EdgeInsets.all(r.spacing.lg),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surface,
        borderRadius: BorderRadius.circular(r.radii.panel),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: r.type.iconMd, color: AppTheme.primary),
                SizedBox(width: r.spacing.sm),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (showSubtitle) ...[
            SizedBox(height: r.spacing.sm),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
          ],
          SizedBox(height: r.isShortViewport ? r.spacing.sm : r.spacing.lg),
          child,
        ],
      ),
    );
  }
}

/// Pastilla de progreso del flujo (`1. Curso`, `2. Estudiante`, `3. Lectura`).
class WorkflowChip extends StatelessWidget {
  const WorkflowChip({super.key, required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.spacing.md,
        vertical: r.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: active ? AppTheme.surfaceAlt : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: active ? AppTheme.surfaceStrong : theme.colorScheme.outline,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: active ? AppTheme.primary : AppTheme.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Las tres pastillas del flujo, en un `Wrap` para que bajen de línea en vez de
/// desbordar cuando el panel se estrecha o el texto escala.
class WorkflowChips extends StatelessWidget {
  const WorkflowChips({
    super.key,
    required this.hasCurso,
    required this.hasStudent,
    required this.hasReading,
    this.showStudent = true,
    this.alignment = WrapAlignment.start,
  });

  final bool hasCurso;
  final bool hasStudent;
  final bool hasReading;

  /// El modo prueba no tiene paso de estudiante. Mostrar una pastilla que nunca
  /// se completa haría ver el flujo como incompleto para siempre.
  final bool showStudent;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final gap = context.responsive.spacing.sm;

    return Wrap(
      alignment: alignment,
      spacing: gap,
      runSpacing: gap,
      children: [
        WorkflowChip(label: '1. Curso', active: hasCurso),
        if (showStudent)
          WorkflowChip(label: '2. Estudiante', active: hasStudent),
        WorkflowChip(
          label: showStudent ? '3. Lectura' : '2. Lectura',
          active: hasReading,
        ),
      ],
    );
  }
}

/// Pastilla informativa compacta usada en encabezados y metadatos.
class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.label,
    this.icon,
    this.background = Colors.white,
    this.foreground = AppTheme.primary,
    this.border,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.spacing.md,
        vertical: r.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: r.type.iconSm, color: foreground),
            SizedBox(width: r.spacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
