import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:prosodia/core/database/app_database.dart';
import 'package:prosodia/core/responsive/responsive.dart';
import 'package:prosodia/core/theme/app_theme.dart';
import 'package:prosodia/features/assessment/presentation/eval_state.dart';
import 'package:prosodia/features/assessment/presentation/widgets/assessment_app_bar.dart';
import 'package:prosodia/features/assessment/presentation/widgets/control_panel.dart';
import 'package:prosodia/features/assessment/presentation/widgets/reading_gallery.dart';

/// Modo prueba: se entra sin credenciales y **no se guarda nada**.
///
/// Lo que se fija acá es que la interfaz no ofrezca nada que en ese modo no
/// pueda funcionar — un selector de alumno que estaría siempre vacío, o un
/// botón de sincronizar que solo podría devolver 401.
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
    nivel: '4',
    totalPalabras: 288,
  );

  Widget panel({
    required bool trial,
    ReadingText? selectedTexto,
    String? selectedCurso = '4° básico',
    EvalState state = EvalState.idle,
  }) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: ResponsiveScope(
        builder: (context, r) => SingleChildScrollView(
          child: AssessmentControlPanel(
            trial: trial,
            state: state,
            cursos: const ['3° básico', '4° básico'],
            selectedCurso: selectedCurso,
            onCursoChanged: (_) {},
            studentsInCurso: trial ? const [] : [student],
            selectedStudent: trial ? null : student,
            onStudentChanged: (_) {},
            selectedTexto: selectedTexto,
            elapsed: Duration.zero,
            timerKey: const ValueKey('timer'),
            onStartRecording: () {},
            onStopRecording: () {},
            manualReview: null,
            scrollController: null,
            scrollable: false,
          ),
        ),
      ),
    ),
  );

  Widget bar({required bool trial}) => MaterialApp(
    theme: AppTheme.light,
    home: ResponsiveScope(
      builder: (context, r) => Scaffold(
        appBar: AssessmentAppBar(
          compact: r.isShortViewport,
          trial: trial,
          state: EvalState.idle,
          syncing: false,
          checkingUpdate: false,
          onTitleTap: () {},
          onCheckUpdate: () {},
          onSync: () {},
          onLogout: () {},
        ),
        body: const SizedBox.shrink(),
      ),
    ),
  );

  group('Panel de preparación', () {
    testWidgets('en prueba no ofrece seleccionar alumno', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(panel(trial: true));

      expect(
        find.text('Estudiante'),
        findsNothing,
        reason:
            'Sin sesión no hay alumnos sincronizados: el selector estaría '
            'siempre vacío y el resultado no se guarda contra nadie.',
      );
      expect(find.text('Curso'), findsOneWidget);
    });

    testWidgets('en el flujo normal sí lo ofrece', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(panel(trial: false));

      expect(find.text('Estudiante'), findsOneWidget);
      expect(find.text('Curso'), findsOneWidget);
    });

    testWidgets('en prueba el flujo no muestra el paso de estudiante', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(panel(trial: true));

      expect(
        find.text('2. Estudiante'),
        findsNothing,
        reason:
            'Una pastilla que nunca se completa hace ver el flujo como '
            'permanentemente incompleto.',
      );
      expect(find.text('2. Lectura'), findsOneWidget);
    });
  });

  group('Botón de grabación', () {
    testWidgets('en prueba se habilita con curso y lectura, sin alumno', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(panel(trial: true, selectedTexto: reading));

      expect(
        _accion(tester, 'Iniciar evaluación').onPressed,
        isNotNull,
        reason:
            'En prueba no hay alumno, así que exigirlo dejaría el botón muerto '
            'para siempre.',
      );
    });

    testWidgets('en prueba sigue deshabilitado sin lectura', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(panel(trial: true));

      expect(_accion(tester, 'Iniciar evaluación').onPressed, isNull);
    });
  });

  // El bug que motivó este grupo: la galería estaba condicionada a
  // `_selectedStudent != null`, que en modo prueba nunca se cumple. El curso se
  // seleccionaba, las lecturas se cargaban en memoria y no se mostraba ninguna.
  // Los tests anteriores cubrían el panel y la barra, nunca el área de trabajo.
  group('Galería de lecturas', () {
    testWidgets('se muestra sin alumno cuando hay lecturas del nivel', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ResponsiveScope(
              builder: (context, r) => ReadingGallery(
                texts: [reading],
                studentName: null,
                fillHeight: false,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Lecturas disponibles'), findsOneWidget);
      expect(find.textContaining('Tito, el perro alegre'), findsWidgets);
      expect(
        find.textContaining('Selecciona una lectura para probar'),
        findsOneWidget,
        reason: 'Sin alumno, el subtítulo no puede nombrar a nadie.',
      );
    });

    testWidgets('con alumno mantiene su nombre en el subtítulo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ResponsiveScope(
              builder: (context, r) => ReadingGallery(
                texts: [reading],
                studentName: student.nombreCompleto,
                fillHeight: false,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Josefa'), findsOneWidget);
    });
  });

  group('Barra superior', () {
    testWidgets('en prueba no ofrece sincronizar', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(bar(trial: true));

      expect(
        find.byTooltip('Sincronizar estudiantes'),
        findsNothing,
        reason: 'Sin sesión, sincronizar solo puede devolver 401.',
      );
      expect(find.byTooltip('Salir de la prueba'), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsNothing);
    });

    testWidgets('en el flujo normal ofrece sincronizar y cerrar sesión', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(bar(trial: false));

      expect(find.byTooltip('Sincronizar estudiantes'), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
      expect(find.byTooltip('Salir de la prueba'), findsNothing);
    });
  });
}

/// `FilledButton.icon` construye un subtipo privado, y `find.byType` exige tipo
/// exacto: buscar `FilledButton` no lo encuentra. Se busca por el texto y se
/// sube al botón que lo contiene.
ButtonStyleButton _accion(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(
      find
          .ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          )
          .first,
    );
