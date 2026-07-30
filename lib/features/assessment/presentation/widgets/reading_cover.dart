import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';

/// Especificación visual de la portada de una lectura: color, categoría y escena
/// del arte de respaldo.
typedef ReadingCoverSpec = ({List<Color> colors, String badge, String scene});

/// Ruta del PNG de portada dentro de `assets/reading_covers/`.
String readingCoverImagePath(ReadingText text) {
  var slug = text.titulo.toLowerCase();
  slug = slug
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
  slug = slug.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
  return 'assets/reading_covers/${text.nivel}_$slug.png';
}

ReadingCoverSpec readingCoverSpec(ReadingText text) {
  final title = text.titulo.toLowerCase();

  if (title.contains('perro') || title.contains('pelota')) {
    return (
      colors: [const Color(0xFFFB923C), const Color(0xFFF97316)],
      badge: 'Aventura',
      scene: 'playground',
    );
  }
  if (title.contains('mochila') ||
      title.contains('cuaderno') ||
      title.contains('carta')) {
    return (
      colors: [const Color(0xFF60A5FA), const Color(0xFF2563EB)],
      badge: 'Escuela',
      scene: 'school',
    );
  }
  if (title.contains('nubes')) {
    return (
      colors: [const Color(0xFF93C5FD), const Color(0xFF38BDF8)],
      badge: 'Imaginación',
      scene: 'sky',
    );
  }
  if (title.contains('semilla') ||
      title.contains('huerto') ||
      title.contains('quínoa')) {
    return (
      colors: [const Color(0xFF86EFAC), const Color(0xFF16A34A)],
      badge: 'Naturaleza',
      scene: 'garden',
    );
  }
  if (title.contains('feria') || title.contains('mercado')) {
    return (
      colors: [const Color(0xFFFDE68A), const Color(0xFFF59E0B)],
      badge: 'Vida cotidiana',
      scene: 'market',
    );
  }
  if (title.contains('faro') ||
      title.contains('isla') ||
      title.contains('río') ||
      title.contains('agua') ||
      title.contains('canal')) {
    return (
      colors: [const Color(0xFF67E8F9), const Color(0xFF0EA5E9)],
      badge: 'Entorno',
      scene: 'sea',
    );
  }
  if (title.contains('puente') || title.contains('cerro')) {
    return (
      colors: [const Color(0xFFA7F3D0), const Color(0xFF059669)],
      badge: 'Territorio',
      scene: 'mountains',
    );
  }
  if (title.contains('volantines') || title.contains('estrellas')) {
    return (
      colors: [const Color(0xFFC4B5FD), const Color(0xFF7C3AED)],
      badge: 'Exploración',
      scene: 'night',
    );
  }
  if (title.contains('fotógrafa') || title.contains('entrevista')) {
    return (
      colors: [const Color(0xFFF9A8D4), const Color(0xFFDB2777)],
      badge: 'Observación',
      scene: 'studio',
    );
  }
  if (title.contains('ciudad') ||
      title.contains('archivo') ||
      title.contains('energía')) {
    return (
      colors: [const Color(0xFFD8B4FE), const Color(0xFF8B5CF6)],
      badge: 'Sociedad',
      scene: 'city',
    );
  }

  switch (text.nivel) {
    case '1':
    case '2':
      return (
        colors: [const Color(0xFFFDE68A), const Color(0xFFF97316)],
        badge: 'Cuento',
        scene: 'playground',
      );
    case '3':
    case '4':
      return (
        colors: [const Color(0xFF93C5FD), const Color(0xFF2563EB)],
        badge: 'Lectura guiada',
        scene: 'mountains',
      );
    case '5':
    case '6':
      return (
        colors: [const Color(0xFFA7F3D0), const Color(0xFF059669)],
        badge: 'Texto informativo',
        scene: 'garden',
      );
    default:
      return (
        colors: [const Color(0xFFD8B4FE), const Color(0xFF7C3AED)],
        badge: 'Texto de análisis',
        scene: 'city',
      );
  }
}

/// Portada de una lectura.
///
/// ⚠️ **No cambiar la composición de la imagen sin leer
/// `wiki/projects/prosodia/bugs/mediatek-image-banding.md`.**
///
/// `BoxFit.cover` + `ColoredBox` + `cacheHeight` es el fix del banding en GPUs
/// MediaTek: `BoxFit.contain` obliga a componer las zonas transparentes que
/// rodean la imagen, y esa operación con alpha es la que dispara el artefacto.
/// `cacheHeight` además baja la carga de decodificación en esas tablets.
class ReadingCover extends StatelessWidget {
  const ReadingCover({super.key, required this.text, required this.height});

  final ReadingText text;
  final double height;

  @override
  Widget build(BuildContext context) {
    final spec = readingCoverSpec(text);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheH = (height * dpr).round();

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ColoredBox(
        color: spec.colors.first.withValues(alpha: 0.18),
        child: Image.asset(
          readingCoverImagePath(text),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          width: double.infinity,
          height: height,
          cacheHeight: cacheH,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              ReadingCoverArt(spec: spec, height: height),
        ),
      ),
    );
  }
}

/// Arte de respaldo cuando falta el PNG de la portada.
///
/// Se dibuja sobre un lienzo de diseño fijo de [_canvasWidth]×[_canvasHeight] y
/// se escala con `FittedBox`. Las constantes de cada escena son coordenadas de
/// ese lienzo, no medidas de layout: antes se dibujaban tal cual dentro de un
/// contenedor que podía medir 96 dp de alto, y la escena quedaba cortada.
class ReadingCoverArt extends StatelessWidget {
  const ReadingCoverArt({super.key, required this.spec, required this.height});

  final ReadingCoverSpec spec;
  final double height;

  static const double _canvasWidth = 320;
  static const double _canvasHeight = 196;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: _canvasWidth,
            height: _canvasHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(color: spec.colors.first),
              child: Stack(
                children: [
                  Positioned(
                    top: -18,
                    right: -10,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -22,
                    left: -8,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  ..._sceneWidgets(spec.scene),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        spec.badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    top: 14,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _cloud({
    required double left,
    required double top,
    required double width,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: width,
        height: width * 0.42,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                width: width * 0.46,
                height: width * 0.28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(width),
                ),
              ),
            ),
            Positioned(
              left: width * 0.18,
              top: 0,
              child: Container(
                width: width * 0.34,
                height: width * 0.26,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(width),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: width * 0.02,
              child: Container(
                width: width * 0.42,
                height: width * 0.24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(width),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _star({
    required double left,
    required double top,
    required double size,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: Icon(
        Icons.star_rounded,
        size: size,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }

  static List<Widget> _sceneWidgets(String scene) {
    switch (scene) {
      case 'school':
        return [
          Positioned(
            right: 22,
            top: 20,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.amber[200],
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 18,
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            left: 48,
            right: 48,
            bottom: 44,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            left: 40,
            right: 40,
            bottom: 28,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                4,
                (_) => Container(
                  width: 10,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ];
      case 'sky':
        return [
          Positioned(
            right: 24,
            top: 20,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.38),
                shape: BoxShape.circle,
              ),
            ),
          ),
          _cloud(left: 20, top: 28, width: 56),
          _cloud(left: 108, top: 18, width: 48),
          Positioned(
            left: -16,
            right: -12,
            bottom: -10,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(44),
              ),
            ),
          ),
        ];
      case 'garden':
        return [
          Positioned(
            right: 22,
            top: 18,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.amber[100],
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -18,
            right: -18,
            bottom: -16,
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(46),
              ),
            ),
          ),
          Positioned(
            left: 34,
            bottom: 24,
            child: Container(
              width: 6,
              height: 36,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          Positioned(
            left: 22,
            bottom: 42,
            child: Transform.rotate(
              angle: -0.55,
              child: Container(
                width: 22,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Positioned(
            left: 35,
            bottom: 46,
            child: Transform.rotate(
              angle: 0.55,
              child: Container(
                width: 22,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Positioned(
            left: 78,
            bottom: 24,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ];
      case 'market':
        return [
          Positioned(
            left: 18,
            right: 18,
            top: 24,
            child: Container(
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: List.generate(
                  6,
                  (index) => Expanded(
                    child: Container(
                      color: index.isEven
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 18,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Positioned(
            left: 36,
            bottom: 30,
            child: Row(
              children: List.generate(
                4,
                (index) => Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: index.isEven
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.58),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ];
      case 'sea':
        return [
          Positioned(
            right: 24,
            top: 18,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.38),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 24,
            bottom: 30,
            child: Container(
              width: 18,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 70,
            child: Container(
              width: 26,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Positioned(
            left: -20,
            right: -20,
            bottom: 18,
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            left: -10,
            right: -10,
            bottom: -2,
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ];
      case 'mountains':
        return [
          Positioned(
            left: 8,
            right: 8,
            bottom: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(80),
                        topRight: Radius.circular(80),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(90),
                        topRight: Radius.circular(90),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(70),
                        topRight: Radius.circular(70),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      case 'night':
        return [
          Positioned(
            right: 28,
            top: 18,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.38),
                shape: BoxShape.circle,
              ),
            ),
          ),
          _star(left: 26, top: 24, size: 16),
          _star(left: 92, top: 38, size: 12),
          _star(left: 142, top: 20, size: 14),
          Positioned(
            left: 42,
            bottom: 22,
            child: Container(
              width: 60,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(40),
                ),
              ),
            ),
          ),
          Positioned(
            left: 70,
            bottom: 54,
            child: Container(
              width: 16,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ];
      case 'studio':
        return [
          Positioned(
            left: 26,
            top: 24,
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 42,
            top: 40,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.82),
                  width: 4,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ];
      case 'city':
        return [
          Positioned(
            left: 18,
            right: 18,
            bottom: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final height in [46.0, 66.0, 54.0, 74.0, 42.0])
                  Expanded(
                    child: Container(
                      height: height,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ];
      default:
        return [
          Positioned(
            left: 0,
            right: 0,
            bottom: -8,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(44),
              ),
            ),
          ),
        ];
    }
  }
}
