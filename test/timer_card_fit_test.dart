import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:prosodia/core/database/app_database.dart';
import 'package:prosodia/core/responsive/responsive.dart';
import 'package:prosodia/core/theme/app_theme.dart';
import 'package:prosodia/features/assessment/presentation/eval_state.dart';
import 'package:prosodia/features/assessment/presentation/widgets/control_panel.dart';

/// El cronómetro ocupa su tarjeta completa y el tamaño lo fija
/// `AppTypeScale.timer`. El `FittedBox` que lo envuelve es una red de
/// seguridad, no el mecanismo de dimensionado: si empieza a achicar la cifra en
/// el caso normal, es que la escala quedó grande para el ancho real del panel y
/// hay que corregir la escala, no delegar en el escalado.
///
/// Estos tests miden el **ancho real de la caja** en los anchos que produce
/// `Responsive.controlPanelWidth` y lo contrastan con el ancho que ocupará la
/// cifra en Nunito, derivado de `AppTypeScale.timerAdvanceMMSS`.
///
/// No se miden los glifos: `flutter_test` usa una fuente donde cada glifo mide
/// un em completo, casi el doble que Nunito, así que un ancho de texto medido
/// acá no dice nada del dispositivo. El layout de la caja sí es fiable, porque
/// no depende de la fuente. Mismo criterio que `readingMaxWidth`.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final student = Student(
    id: 1,
    rut: '11.111.111-1',
    nombreCompleto: 'Josefa Antonia Mardones Riquelme',
    curso: '4°B',
    activo: true,
    syncedAt: DateTime(2026, 7, 30),
  );

  final reading = ReadingText(
    id: 1,
    titulo: 'Tito, el perro alegre',
    contenido: 'Tito es un perro pequeño y alegre.',
    nivel: '4° básico',
    totalPalabras: 288,
  );

  /// Solo tablets: en teléfono la tarjeta del cronómetro no existe en el panel
  /// de control — el tiempo y el control de grabación viven en
  /// `ReadingModeBar`. Eso lo cubre el último test de este archivo.
  const viewports = <({String name, Size landscape})>[
    (name: '1024x768 · tablet', landscape: Size(1024, 768)),
    (name: '1280x800 · tablet', landscape: Size(1280, 800)),
    (name: '1920x1200 · tablet grande', landscape: Size(1920, 1200)),
  ];

  Widget panelAt(Size size, Widget Function(Responsive) build) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: ResponsiveScope(
        builder: (context, r) => Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: r.controlPanelWidth,
            child: SingleChildScrollView(child: build(r)),
          ),
        ),
      ),
    ),
  );

  for (final viewport in viewports) {
    testWidgets('la cifra cabe sin escalarse — ${viewport.name}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = viewport.landscape;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        panelAt(
          viewport.landscape,
          (r) => AssessmentControlPanel(
            trial: false,
            state: EvalState.recording,
            cursos: const ['1°A', '4°B'],
            selectedCurso: '4°B',
            onCursoChanged: (_) {},
            studentsInCurso: [student],
            selectedStudent: student,
            onStudentChanged: (_) {},
            selectedTexto: reading,
            elapsed: const Duration(minutes: 8, seconds: 47),
            timerKey: const ValueKey('timer'),
            onStartRecording: () {},
            onStopRecording: () {},
            manualReview: null,
            scrollController: null,
            scrollable: false,
          ),
        ),
      );

      final fittedFinder = find.descendant(
        of: find.byKey(const ValueKey('timer')),
        matching: find.byType(FittedBox),
      );

      expect(tester.widget<FittedBox>(fittedFinder).fit, BoxFit.scaleDown);

      final available = tester.renderObject<RenderBox>(fittedFinder).size.width;
      final context = tester.element(fittedFinder);
      final fontSize = context.responsive.type
          .timer(Theme.of(context).textTheme)!
          .fontSize!;
      final cifra = fontSize * AppTypeScale.timerAdvanceMMSS;

      expect(
        cifra,
        lessThanOrEqualTo(available),
        reason:
            '${viewport.name}: a ${fontSize.toStringAsFixed(0)} sp la cifra ocupa '
            '${cifra.toStringAsFixed(1)} dp en una caja de '
            '${available.toStringAsFixed(1)} dp. El FittedBox la achicaría, así '
            'que el cronómetro se vería más chico que lo que dice la escala. '
            'Bajar el tamaño en AppTypeScale.timer.',
      );

      // La caja tampoco debe quedar desangelada: si la cifra ocupa muy poco, el
      // cronómetro vuelve a verse perdido en la tarjeta, que es justo lo que
      // este rediseño corrigió.
      //
      // No aplica al rol `compact`: en un viewport bajo la restricción que
      // manda es la altura, no el ancho, y agrandar la cifra ahí le quita
      // espacio a los controles. Exigirle llenado horizontal sería medir la
      // restricción equivocada.
      if (!context.responsive.isShortViewport) {
        expect(
          cifra / available,
          greaterThan(0.45),
          reason:
              '${viewport.name}: la cifra ocupa solo '
              '${(cifra / available * 100).toStringAsFixed(0)}% del ancho de la '
              'tarjeta. Subir el tamaño en AppTypeScale.timer.',
        );
      }
    });
  }

  testWidgets('en teléfono el cronómetro no vive en el panel de control', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(640, 360);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      panelAt(
        const Size(640, 360),
        (r) => AssessmentControlPanel(
          trial: false,
          state: EvalState.idle,
          cursos: const ['1°A', '4°B'],
          selectedCurso: '4°B',
          onCursoChanged: (_) {},
          studentsInCurso: [student],
          selectedStudent: student,
          onStudentChanged: (_) {},
          selectedTexto: null,
          elapsed: Duration.zero,
          timerKey: const ValueKey('timer'),
          onStartRecording: () {},
          onStopRecording: () {},
          manualReview: null,
          scrollController: null,
          scrollable: false,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('timer')),
      findsNothing,
      reason:
          'En teléfono el panel solo se ve mientras no hay lectura abierta, así '
          'que no hay nada que cronometrar. El cronómetro y el control de '
          'grabación viven en ReadingModeBar.',
    );
    expect(find.text('Iniciar evaluación'), findsNothing);
  });
}
