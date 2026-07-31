import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:prosodia/core/database/app_database.dart';
import 'package:prosodia/core/responsive/responsive.dart';
import 'package:prosodia/core/theme/app_theme.dart';
import 'package:prosodia/features/assessment/data/stats_repository.dart';
import 'package:prosodia/features/assessment/presentation/eval_state.dart';
import 'package:prosodia/features/assessment/presentation/widgets/assessment_app_bar.dart';
import 'package:prosodia/features/assessment/presentation/widgets/assessment_layout.dart';
import 'package:prosodia/features/assessment/presentation/widgets/assessment_placeholders.dart';
import 'package:prosodia/features/assessment/presentation/widgets/context_charts.dart';
import 'package:prosodia/features/assessment/presentation/widgets/control_panel.dart';
import 'package:prosodia/features/assessment/presentation/widgets/manual_review_form.dart';
import 'package:prosodia/features/assessment/presentation/widgets/reading_gallery.dart';
import 'package:prosodia/features/assessment/presentation/widgets/reading_view.dart';
import 'package:prosodia/features/assessment/presentation/widgets/review_panel.dart';

/// Verificación de desbordamiento por viewport.
///
/// Un `RenderFlex` que desborda no lanza una excepción: reporta el error por
/// `FlutterError.onError` durante el pintado y sigue. Este harness intercepta
/// ese canal, monta cada superficie en la matriz completa de viewports,
/// orientaciones y escalas de texto, y falla si aparece cualquier reporte de
/// desbordamiento.
void main() {
  setUpAll(() {
    // Sin red en los tests: `google_fonts` usaría la fuente por defecto igual,
    // pero intentaría descargar y ensuciaría el canal de errores.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ── Matriz ────────────────────────────────────────────────────────────────

  const viewports = <({String name, Size portrait})>[
    (name: '360x640 · teléfono', portrait: Size(360, 640)),
    (name: '411x891 · teléfono', portrait: Size(411, 891)),
    (name: '768x1024 · tablet', portrait: Size(768, 1024)),
    (name: '800x1280 · tablet', portrait: Size(800, 1280)),
    (name: '1200x1920 · tablet grande', portrait: Size(1200, 1920)),
  ];

  const textScales = <double>[1.0, 1.3];

  // ── Fixtures con contenido largo, que es donde se rompe el layout ─────────

  final student = Student(
    id: 1,
    rut: '21.345.678-9',
    nombreCompleto: 'María Fernanda Valenzuela Undurraga',
    curso: '4°B',
    activo: true,
    syncedAt: DateTime(2026, 7, 30),
  );

  final reading = ReadingText(
    id: 1,
    titulo: 'El faro de la isla y las estrellas que guiaban a los pescadores',
    contenido: List.filled(
      12,
      'La niña caminó hasta el faro mientras el viento del sur golpeaba las '
      'rocas y las gaviotas cruzaban el cielo naranja del atardecer.',
    ).join(' '),
    nivel: '4',
    totalPalabras: 288,
  );

  final readings = List.generate(
    6,
    (i) => ReadingText(
      id: i + 1,
      titulo: i.isEven
          ? 'El cuaderno viajero que recorrió todas las salas del colegio'
          : 'La feria',
      contenido: reading.contenido,
      nivel: '4',
      totalPalabras: 120 + i * 37,
    ),
  );

  const courseStats = CourseStats(
    total: 28,
    promedioPcpm: 92.4,
    distribucionVelocidad: {
      'Muy Lenta': 3,
      'Lenta': 5,
      'Medio Baja': 7,
      'Medio Alta': 6,
      'Rápida': 4,
      'Muy Rápida': 3,
    },
  );

  final history = List.generate(
    5,
    (i) => StudentHistory(
      id: i,
      fecha: DateTime(2026, i + 1, 12),
      pcpm: 70.0 + i * 8,
      velocidad: 'Medio Baja',
      nivelLogro: 'Bajo lo Esperado',
      calidad: 'unidades_cortas',
      prosodia: 'básica',
      anio: 2026,
    ),
  );

  // ── Harness ───────────────────────────────────────────────────────────────

  Future<List<String>> pumpAndCollectOverflows(
    WidgetTester tester, {
    required Size size,
    required double textScale,
    required Widget Function(BuildContext context, Responsive r) builder,
    bool wrapInScaffold = true,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final reported = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reported.add;

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: wrapInScaffold
                  ? Scaffold(
                      backgroundColor: AppTheme.appBackground,
                      body: ResponsiveScope(builder: builder),
                    )
                  : ResponsiveScope(builder: builder),
            ),
          ),
        ),
      );
      await tester.pump();
    } finally {
      FlutterError.onError = previousOnError;
    }

    // Los fallos de carga de assets (los PNG de portada no están en el bundle
    // de test) llegan por el mismo canal y no son un problema de layout.
    return [
      for (final details in reported)
        if (details.exceptionAsString().contains('overflowed'))
          '${details.exceptionAsString()}\n${details.toString()}',
    ];
  }

  /// Corre [build] en toda la matriz de viewports × orientaciones × escalas.
  void matrixTest(
    String description,
    Widget Function(BuildContext context, Responsive r) build, {
    bool wrapInScaffold = true,
  }) {
    for (final viewport in viewports) {
      for (final landscape in [false, true]) {
        for (final scale in textScales) {
          final size = landscape
              ? Size(viewport.portrait.height, viewport.portrait.width)
              : viewport.portrait;
          final orientation = landscape ? 'landscape' : 'portrait';

          testWidgets(
            '$description — ${viewport.name} $orientation @${scale}x',
            (tester) async {
              final overflows = await pumpAndCollectOverflows(
                tester,
                size: size,
                textScale: scale,
                builder: build,
                wrapInScaffold: wrapInScaffold,
              );
              expect(
                overflows,
                isEmpty,
                reason:
                    'Desbordamiento en $description a '
                    '${size.width.toInt()}x${size.height.toInt()} '
                    '$orientation con textScale $scale:\n'
                    '${overflows.join('\n')}',
              );
            },
          );
        }
      }
    }
  }

  // ── Constructores de superficie ───────────────────────────────────────────

  Widget controlPanel(
    Responsive r, {
    required EvalState state,
    Widget? manualReview,
  }) {
    return AssessmentControlPanel(
      trial: false,
      state: state,
      cursos: const ['1°A', '2°B', '4°B', '8°A'],
      selectedCurso: '4°B',
      onCursoChanged: (_) {},
      studentsInCurso: [student],
      selectedStudent: student,
      onStudentChanged: (_) {},
      selectedTexto: reading,
      elapsed: const Duration(minutes: 2, seconds: 14),
      timerKey: const ValueKey('timer'),
      onStartRecording: () {},
      onStopRecording: () {},
      manualReview: manualReview,
      scrollController: null,
      scrollable: r.paneStrategy.isDual,
    );
  }

  Widget manualReviewForm(Responsive r) {
    return ManualReviewForm(
      whisperAnalyzed: false,
      palabrasLeidas: 214,
      errores: 12,
      totalPalabras: 288,
      pcpm: 94.3,
      calidad: 'unidades_cortas',
      prosodia: 'básica',
      audioPlayer: const AudioPlayerBar(
        playing: true,
        position: Duration(seconds: 42),
        total: Duration(minutes: 2, seconds: 14),
        onToggle: _noop,
      ),
      onPalabrasChanged: (_) {},
      onErroresChanged: (_) {},
      onCalidadChanged: (_) {},
      onProsodiaChanged: (_) {},
      onSave: () {},
      onDiscard: () {},
    );
  }

  // ── Superficies ───────────────────────────────────────────────────────────

  group('Barra superior', () {
    matrixTest(
      'AssessmentAppBar',
      (context, r) => Scaffold(
        appBar: AssessmentAppBar(
          compact: r.isShortViewport,
          trial: false,
          state: EvalState.analyzing,
          syncing: true,
          checkingUpdate: false,
          onTitleTap: _noop,
          onCheckUpdate: _noop,
          onSync: _noop,
          onLogout: _noop,
        ),
        body: const SizedBox.expand(),
      ),
      wrapInScaffold: false,
    );
  });

  group('Estado inicial', () {
    matrixTest(
      'Selección vacía',
      (context, r) => AssessmentLayout(
        workAreaFirst: false,
        controlPanel: AssessmentControlPanel(
          trial: false,
          state: EvalState.idle,
          cursos: const ['1°A', '4°B'],
          selectedCurso: null,
          onCursoChanged: (_) {},
          studentsInCurso: const [],
          selectedStudent: null,
          onStudentChanged: null,
          selectedTexto: null,
          elapsed: Duration.zero,
          timerKey: const ValueKey('timer'),
          onStartRecording: _noop,
          onStopRecording: _noop,
          manualReview: null,
          scrollController: null,
          scrollable: r.paneStrategy.isDual,
        ),
        workArea: AssessmentEmptyState(
          prompt: 'Selecciona un curso',
          hasCurso: false,
          hasStudent: false,
          hasReading: false,
          fillHeight: r.paneStrategy.isDual,
        ),
      ),
    );
  });

  group('Galería de lecturas', () {
    matrixTest(
      'Galería con títulos largos',
      (context, r) => AssessmentLayout(
        workAreaFirst: false,
        controlPanel: controlPanel(r, state: EvalState.idle),
        workArea: ReadingGallery(
          texts: readings,
          studentName: student.nombreCompleto,
          onSelect: (_) {},
          fillHeight: r.paneStrategy.isDual,
        ),
      ),
    );
  });

  group('Lectura abierta', () {
    matrixTest(
      'Texto de lectura',
      (context, r) => AssessmentLayout(
        workAreaFirst: true,
        controlPanel: controlPanel(r, state: EvalState.recording),
        workArea: ReadingView(
          text: reading,
          cursoLabel: '4°B',
          studentName: student.nombreCompleto,
          onChangeReading: _noop,
          fillHeight: r.paneStrategy.isDual,
        ),
      ),
    );
  });

  group('Medida de lectura efectiva', () {
    // El texto de lectura se acota a ~64 cpl como constante de diseño
    // (`AppTypeScale.readingMaxWidth`), pero lo que importa para el niño que
    // lee es el ancho **real** disponible tras el layout de cada viewport —
    // que puede ser menor a ese tope en un teléfono. Este grupo mide el valor
    // efectivo a través del árbol de widgets real, no de la fórmula teórica.
    // `AppTypeScale.readingSizeFor` reduce la fuente para sostener el piso de
    // 45 cpl en contenedores angostos, pero nunca baja de 14sp: bajo eso el
    // texto deja de ser cómodo para un niño leyendo bajo cronómetro.
    //
    // Los casos portrait de este grupo NO son el flujo normal: la superficie
    // de lectura se fuerza a landscape en todo dispositivo (ver
    // `orientation_lock.dart`). Quedan cubiertos porque
    // `setPreferredOrientations` es una preferencia y el sistema puede
    // entregar igual un contenedor angosto en multiventana o pantalla
    // dividida. O sea: verifican la red de seguridad, no la ruta feliz.
    //
    // En 360×640 portrait —el contenedor más angosto de la matriz— el piso de
    // legibilidad gana antes que el piso de cpl y el valor efectivo queda algo
    // por debajo de 45. Es un trade-off deliberado (legibilidad > cpl exacto),
    // así que ese caso puntual se verifica contra un piso más bajo.
    const minCplExceptions = <String, double>{'360x640 · teléfono/portrait': 35};

    for (final viewport in viewports) {
      for (final landscape in [false, true]) {
        final size = landscape
            ? Size(viewport.portrait.height, viewport.portrait.width)
            : viewport.portrait;
        final orientation = landscape ? 'landscape' : 'portrait';

        testWidgets(
          'readingCpl efectivo en 45–75 — ${viewport.name} $orientation',
          (tester) async {
            double? measured;
            tester.view.devicePixelRatio = 1.0;
            tester.view.physicalSize = size;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light,
                debugShowCheckedModeBanner: false,
                home: Scaffold(
                  backgroundColor: AppTheme.appBackground,
                  body: ResponsiveScope(
                    builder: (context, r) => AssessmentLayout(
                      workAreaFirst: true,
                      controlPanel: controlPanel(
                        r,
                        state: EvalState.recording,
                      ),
                      workArea: ReadingView(
                        text: reading,
                        cursoLabel: '4°B',
                        studentName: student.nombreCompleto,
                        onChangeReading: _noop,
                        fillHeight: r.paneStrategy.isDual,
                        onReadingCplMeasured: (v) => measured = v,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();

            final minCpl =
                minCplExceptions['${viewport.name}/$orientation'] ?? 45.0;

            expect(measured, isNotNull, reason: 'no se midió readingCpl');
            expect(
              measured,
              inInclusiveRange(minCpl, 75),
              reason:
                  '${viewport.name} $orientation → readingCpl efectivo '
                  '$measured fuera del rango legible $minCpl–75',
            );
          },
        );
      }
    }
  });

  group('Análisis en curso', () {
    matrixTest(
      'Panel de análisis',
      (context, r) => AssessmentLayout(
        workAreaFirst: true,
        controlPanel: controlPanel(r, state: EvalState.analyzing),
        workArea: AnalyzingPanel(
          elapsed: const Duration(minutes: 2, seconds: 14),
          fillHeight: r.paneStrategy.isDual,
        ),
      ),
    );
  });

  group('Revisión', () {
    matrixTest(
      'Revisión con IA disponible',
      (context, r) => AssessmentLayout(
        workAreaFirst: true,
        controlPanel: controlPanel(
          r,
          state: EvalState.reviewing,
          manualReview: manualReviewForm(r),
        ),
        workArea: ReviewPanel(
          showContextCharts: true,
          whisperFailed: false,
          originalText: reading.contenido,
          totalWords: reading.totalPalabras,
          transcript: reading.contenido,
          errorMap: const {3: 'sustitución', 11: 'omisión', 40: 'sustitución'},
          resultsKey: const ValueKey('results'),
          pcpm: 94.3,
          velocidad: 'Medio Baja',
          nivelLogro: 'Muy Bajo lo Esperado',
          calidad: 'unidades_cortas',
          prosodia: 'básica',
          courseStats: courseStats,
          studentHistory: history,
          loadingContext: true,
          suggestions: buildSuggestions(
            nivelLogro: 'Muy Bajo lo Esperado',
            calidad: 'unidades_cortas',
            prosodia: 'básica',
          ),
          scrollController: null,
          fillHeight: r.paneStrategy.isDual,
        ),
      ),
    );

    matrixTest(
      'Revisión sin análisis de IA',
      (context, r) => AssessmentLayout(
        workAreaFirst: true,
        controlPanel: controlPanel(
          r,
          state: EvalState.reviewing,
          manualReview: manualReviewForm(r),
        ),
        workArea: ReviewPanel(
          showContextCharts: true,
          whisperFailed: true,
          originalText: reading.contenido,
          totalWords: reading.totalPalabras,
          transcript: null,
          errorMap: const {},
          resultsKey: const ValueKey('results'),
          pcpm: 0,
          velocidad: '—',
          nivelLogro: '—',
          calidad: 'fluida',
          prosodia: 'adecuada',
          courseStats: null,
          studentHistory: const [],
          loadingContext: false,
          suggestions: const ['Mantener la práctica lectora.'],
          scrollController: null,
          fillHeight: r.paneStrategy.isDual,
        ),
      ),
    );
  });

  group('Diálogo de resultado', () {
    // Reproduce la estructura real de `_showResult`: `AlertDialog` con el
    // contenido en un scroll, sobre el ancho más angosto en que se muestra.
    matrixTest(
      'Filas de resultado con valores largos',
      (context, r) => Center(
        child: SizedBox(
          width: 280,
          child: AlertDialog(
            title: const Text('Evaluación guardada'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ResultRow(label: 'PCPM', value: '94.3'),
                  ResultRow(label: 'Velocidad', value: 'Medio Baja'),
                  ResultRow(
                    label: 'Nivel de logro',
                    value: 'Muy Bajo lo Esperado',
                  ),
                  ResultRow(label: 'Calidad', value: 'Palabra A Palabra'),
                  ResultRow(label: 'Prosodia', value: 'Inadecuada'),
                ],
              ),
            ),
            actions: [
              FilledButton(onPressed: _noop, child: const Text('Nueva')),
            ],
          ),
        ),
      ),
    );
  });

  // ── Accesibilidad táctil ──────────────────────────────────────────────────

  group('Áreas táctiles', () {
    Future<void> pumpSurface(
      WidgetTester tester,
      Size size,
      Widget Function(BuildContext, Responsive) builder,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: ResponsiveScope(builder: builder)),
        ),
      );
      await tester.pump();
    }

    testWidgets('formulario de revisión — tablet landscape', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSurface(
        tester,
        const Size(1280, 800),
        (context, r) => SingleChildScrollView(child: manualReviewForm(r)),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('formulario de revisión — teléfono portrait', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSurface(
        tester,
        const Size(360, 640),
        (context, r) => SingleChildScrollView(child: manualReviewForm(r)),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('barra superior — teléfono landscape', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(640, 360);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ResponsiveScope(
            builder: (context, r) => Scaffold(
              appBar: AssessmentAppBar(
                compact: r.isShortViewport,
                trial: false,
                state: EvalState.idle,
                syncing: false,
                checkingUpdate: false,
                onTitleTap: _noop,
                onCheckUpdate: _noop,
                onSync: _noop,
                onLogout: _noop,
              ),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  // ── Contratos de la capa responsive ───────────────────────────────────────

  group('Capa responsive', () {
    test('la clase de dispositivo no cambia al rotar', () {
      for (final viewport in viewports) {
        final portrait = AppBreakpoint.fromShortestSide(
          viewport.portrait.shortestSide,
        );
        final landscape = AppBreakpoint.fromShortestSide(
          Size(viewport.portrait.height, viewport.portrait.width).shortestSide,
        );
        expect(landscape, portrait, reason: viewport.name);
      }
    });

    test('los viewports objetivo caen en la clase esperada', () {
      expect(AppBreakpoint.fromShortestSide(360), AppBreakpoint.phone);
      expect(AppBreakpoint.fromShortestSide(411), AppBreakpoint.phone);
      expect(AppBreakpoint.fromShortestSide(599), AppBreakpoint.phone);
      expect(AppBreakpoint.fromShortestSide(600), AppBreakpoint.tablet);
      expect(AppBreakpoint.fromShortestSide(768), AppBreakpoint.tablet);
      expect(AppBreakpoint.fromShortestSide(800), AppBreakpoint.tablet);
      expect(AppBreakpoint.fromShortestSide(1024), AppBreakpoint.tablet);
      expect(AppBreakpoint.fromShortestSide(1200), AppBreakpoint.tabletLarge);
    });

    test('la medida de lectura queda dentro del rango legible', () {
      for (final breakpoint in AppBreakpoint.values) {
        for (final short in [false, true]) {
          final type = AppTypeScale.forBreakpoint(breakpoint, short: short);
          // ~0.5 dp de avance medio por punto de tamaño en Source Serif 4.
          final charsPerLine = type.readingMaxWidth / (type.readingSize * 0.5);
          expect(
            charsPerLine,
            inInclusiveRange(45, 75),
            reason: '$breakpoint short=$short → $charsPerLine cpl',
          );
        }
      }
    });

    test('el panel de control se mantiene usable en todo ancho', () {
      for (final width in [720.0, 1024.0, 1280.0, 1920.0]) {
        final r = Responsive.resolve(
          deviceSize: Size(width, 800),
          constraints: BoxConstraints.tightFor(width: width, height: 800),
          textScale: 1,
        );
        expect(r.controlPanelWidth, greaterThanOrEqualTo(320));
        expect(r.controlPanelWidth, lessThanOrEqualTo(460));
        // Al área de trabajo siempre le queda al menos la medida mínima.
        expect(width - r.controlPanelWidth, greaterThanOrEqualTo(340));
      }
    });

    test('la composición apilada se activa bajo 720 dp', () {
      expect(PaneStrategy.fromWidth(719), PaneStrategy.stacked);
      expect(PaneStrategy.fromWidth(720), PaneStrategy.dual);
    });
  });
}

void _noop() {}
