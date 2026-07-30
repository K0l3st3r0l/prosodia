import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import 'reading_cover.dart';
import 'surfaces.dart';

/// Tarjeta de una lectura disponible.
///
/// La altura es **mínima, no fija**. La versión anterior la clavaba en 322 dp
/// con una portada de 168: quedaban 154 dp para un título de dos líneas, tres
/// de extracto y una fila de pie, que suman ~179 dp a escala 1.0 y ~215 dp a
/// 1.3x. Era el desbordamiento más probable de la pantalla.
class ReadingCard extends StatelessWidget {
  const ReadingCard({
    super.key,
    required this.text,
    required this.coverHeight,
    required this.onTap,
    this.showExcerpt = true,
  });

  final ReadingText text;
  final double coverHeight;
  final VoidCallback? onTap;
  final bool showExcerpt;

  static String excerptOf(ReadingText text) => text.contenido
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .take(2)
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.responsive;
    final radius = BorderRadius.circular(r.radii.surface);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x207C3AED),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: radius.topLeft),
                child: ReadingCover(text: text, height: coverHeight),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  r.spacing.lg,
                  r.spacing.lg,
                  r.spacing.lg,
                  r.spacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (showExcerpt) ...[
                      SizedBox(height: r.spacing.sm),
                      Text(
                        excerptOf(text),
                        maxLines: r.breakpoint.isPhone ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                          height: 1.45,
                        ),
                      ),
                    ],
                    SizedBox(height: r.spacing.md),
                    Row(
                      children: [
                        Flexible(
                          child: InfoPill(
                            icon: Icons.auto_stories_rounded,
                            label: '${text.totalPalabras} palabras',
                            background: AppTheme.surfaceAlt,
                          ),
                        ),
                        SizedBox(width: r.spacing.sm),
                        Text(
                          'Abrir',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppTheme.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.secondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Galería de lecturas disponibles para el estudiante seleccionado.
class ReadingGallery extends StatelessWidget {
  const ReadingGallery({
    super.key,
    required this.texts,
    required this.studentName,
    required this.onSelect,
    required this.fillHeight,
  });

  final List<ReadingText> texts;
  final String studentName;
  final ValueChanged<ReadingText>? onSelect;

  /// `true` cuando la galería recibe una altura acotada y debe hacer scroll por
  /// su cuenta (composición de dos paneles). `false` cuando ya vive dentro de un
  /// scroll del padre (composición apilada).
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    final header = SectionCard(
      title: 'Lecturas disponibles',
      subtitle:
          'Selecciona una lectura para $studentName. '
          'Cada tarjeta incluye una portada visual del texto.',
      icon: Icons.menu_book_rounded,
      backgroundColor: AppTheme.surface,
      child: Wrap(
        spacing: r.spacing.sm,
        runSpacing: r.spacing.sm,
        children: [
          InfoPill(
            label: '${texts.length} lecturas',
            border: Theme.of(context).colorScheme.outline,
          ),
          if (!r.isShortViewport)
            InfoPill(
              label: 'Toca una tarjeta para abrir la lectura',
              foreground: AppTheme.muted,
              border: Theme.of(context).colorScheme.outline,
            ),
        ],
      ),
    );

    final grid = LayoutBuilder(
      builder: (context, constraints) {
        final spacing = r.spacing.md;
        final columns = r.galleryColumns(constraints.maxWidth);
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final text in texts)
              SizedBox(
                width: cardWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: r.galleryCardMinHeight,
                  ),
                  child: ReadingCard(
                    text: text,
                    coverHeight: r.coverHeight,
                    showExcerpt: !r.isShortViewport,
                    onTap: onSelect == null ? null : () => onSelect!(text),
                  ),
                ),
              ),
          ],
        );
      },
    );

    return Column(
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        SizedBox(height: r.spacing.md),
        if (fillHeight)
          Expanded(child: SingleChildScrollView(child: grid))
        else
          grid,
      ],
    );
  }
}
