import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:prosodia/core/database/app_database.dart';
import 'package:prosodia/core/responsive/responsive.dart';
import 'package:prosodia/core/theme/app_theme.dart';
import 'package:prosodia/features/assessment/presentation/eval_state.dart';
import 'package:prosodia/features/assessment/presentation/widgets/reading_mode_bar.dart';
import 'package:prosodia/features/assessment/presentation/widgets/reading_view.dart';

/// Control de tamaño del texto de lectura.
///
/// La garantía que sostiene todo lo demás: **ninguna posición del control puede
/// sacar el texto del rango legible de 45–75 cpl**. Por eso estos tests barren
/// el rango completo y no solo el tamaño nominal — un test que probara solo el
/// centro dejaría pasar precisamente el caso que rompe la medición.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final reading = ReadingText(
    id: 1,
    titulo: 'Tito, el perro alegre',
    contenido:
        'Tito es un perro pequeño y alegre. Tiene el pelo café y las orejas '
        'largas. Su juguete favorito es una pelota roja.',
    nivel: '4',
    totalPalabras: 288,
  );

  const viewports = [Size(640, 360), Size(740, 360), Size(891, 411)];

  /// Posiciones del control: los dos extremos y varios intermedios. Los
  /// extremos son los que importan — es donde el rango se rompe si los topes
  /// están mal derivados.
  const posiciones = [0.0, 0.15, 0.35, 0.5, 0.65, 0.85, 1.0];

  group('El rango legible se respeta en todo el recorrido del control', () {
    for (final size in viewports) {
      for (final posicion in posiciones) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} · posición $posicion',
          (tester) async {
            tester.view.devicePixelRatio = 1.0;
            tester.view.physicalSize = size;
            addTearDown(tester.view.reset);

            double? cpl;
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light,
                home: Scaffold(
                  // Igual que `_buildFocusBody`: en modo foco el texto va
                  // dentro de un scroll. Sin él, con la letra al máximo y la
                  // fuente de test —un em por glifo, ~2× Nunito— el bloque
                  // desborda el alto y el desborde tapa lo que se quiere medir.
                  body: ResponsiveScope(
                    builder: (context, r) => SingleChildScrollView(
                      child: ReadingView(
                        text: reading,
                        cursoLabel: '4°B',
                        studentName: null,
                        onChangeReading: null,
                        fillHeight: false,
                        focus: true,
                        sizePosition: posicion,
                        onReadingCplMeasured: (v) => cpl = v,
                      ),
                    ),
                  ),
                ),
              ),
            );

            expect(cpl, isNotNull, reason: 'El cpl no se midió.');
            expect(
              cpl!,
              inInclusiveRange(45, 75),
              reason:
                  'A posición $posicion en ${size.width.toInt()} dp el texto '
                  'queda en ${cpl!.toStringAsFixed(1)} cpl, fuera del rango '
                  'legible. Los topes de AppTypeScale.readingSizeRange tienen '
                  'que derivarse del ancho real, no de constantes.',
            );
          },
        );
      }
    }
  });

  group('Los topes salen del ancho, no de constantes', () {
    test('un contenedor más ancho admite letra más grande', () {
      final scale = AppTypeScale.forBreakpoint(AppBreakpoint.phone);
      final angosto = scale.readingSizeRange(400);
      final ancho = scale.readingSizeRange(800);

      expect(ancho.max, greaterThan(angosto.max));
      expect(ancho.min, greaterThan(angosto.min));
    });

    test('los extremos corresponden a 75 y 45 cpl', () {
      final scale = AppTypeScale.forBreakpoint(AppBreakpoint.phone);
      const width = 608.0;
      final range = scale.readingSizeRange(width);

      expect(scale.effectiveCplFor(width, fontSize: range.min), closeTo(75, 0.5));
      expect(scale.effectiveCplFor(width, fontSize: range.max), closeTo(45, 0.5));
    });

    test('en un contenedor muy angosto gana el piso de legibilidad', () {
      final scale = AppTypeScale.forBreakpoint(AppBreakpoint.phone);
      // A 200 dp, 75 cpl exigirían 5.3 sp: ilegible para un niño. La política
      // es la misma que readingSizeFor — antes que empujar la letra bajo lo
      // legible, se acepta quedar sobre 75 cpl.
      final range = scale.readingSizeRange(200);
      expect(range.min, greaterThanOrEqualTo(14));
      expect(range.max, greaterThanOrEqualTo(range.min));
    });
  });

  group('Disponibilidad del control', () {
    Widget bar(EvalState state, {ValueChanged<double>? onChanged}) => MaterialApp(
      theme: AppTheme.light,
      home: ResponsiveScope(
        builder: (context, r) => Scaffold(
          appBar: ReadingModeBar(
            height: ReadingModeBar.compactHeight,
            elapsed: Duration.zero,
            state: state,
            onStart: () {},
            onStop: () {},
            onRepeat: () {},
            onChangeReading: state == EvalState.idle ? () {} : null,
            sizePosition: 0.5,
            onSizePositionChanged: onChanged,
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    testWidgets('en reposo se ofrece', (tester) async {
      await tester.pumpWidget(bar(EvalState.idle, onChanged: (_) {}));
      expect(find.byTooltip('Tamaño del texto'), findsOneWidget);
    });

    testWidgets('grabando NO se ofrece', (tester) async {
      await tester.pumpWidget(bar(EvalState.recording, onChanged: (_) {}));
      expect(
        find.byTooltip('Tamaño del texto'),
        findsNothing,
        reason:
            'Ajustar el tamaño con la grabación andando cambia las condiciones '
            'de medición en medio de la medición, y readingCpl solo guarda el '
            'último valor: la sesión quedaría registrada con condiciones que '
            'solo describen su tramo final.',
      );
    });

    testWidgets('en revisión NO se ofrece', (tester) async {
      await tester.pumpWidget(bar(EvalState.reviewing, onChanged: (_) {}));
      expect(find.byTooltip('Tamaño del texto'), findsNothing);
    });

    testWidgets('sin medición todavía, no se ofrece', (tester) async {
      await tester.pumpWidget(bar(EvalState.idle));
      expect(
        find.byTooltip('Tamaño del texto'),
        findsNothing,
        reason:
            'Sin un ancho medido no hay con qué acotar el rango legible, así '
            'que el control no puede ofrecerse todavía.',
      );
    });
  });

  group('Interacción del control', () {
    testWidgets('abrirlo reemplaza la barra y cerrarlo la restaura', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(640, 360);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ResponsiveScope(
            builder: (context, r) => Scaffold(
              appBar: ReadingModeBar(
                height: ReadingModeBar.compactHeight,
                elapsed: Duration.zero,
                state: EvalState.idle,
                onStart: () {},
                onStop: () {},
                onRepeat: () {},
                onChangeReading: () {},
                sizePosition: 0.5,
                onSizePositionChanged: (_) {},
              ),
              body: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      expect(find.byType(Slider), findsNothing);

      await tester.tap(find.byTooltip('Tamaño del texto'));
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsOneWidget);
      expect(
        find.text('Iniciar evaluación'),
        findsNothing,
        reason:
            'El control ocupa la barra completa: sin overlay que tape el texto '
            'mientras se arrastra.',
      );

      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsNothing);
      expect(find.text('Iniciar evaluación'), findsOneWidget);
    });

    testWidgets('arrastrar reporta la posición nueva', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(640, 360);
      addTearDown(tester.view.reset);

      final reportadas = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ResponsiveScope(
            builder: (context, r) => Scaffold(
              appBar: ReadingModeBar(
                height: ReadingModeBar.compactHeight,
                elapsed: Duration.zero,
                state: EvalState.idle,
                onStart: () {},
                onStop: () {},
                onRepeat: () {},
                onChangeReading: () {},
                sizePosition: 0.5,
                onSizePositionChanged: reportadas.add,
              ),
              body: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Tamaño del texto'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Slider), const Offset(60, 0));
      await tester.pumpAndSettle();

      expect(reportadas, isNotEmpty);
      expect(reportadas.last, greaterThan(0.5));
      expect(reportadas.every((p) => p >= 0 && p <= 1), isTrue);
    });
  });
}
