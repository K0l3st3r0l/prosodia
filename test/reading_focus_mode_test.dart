import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:prosodia/core/database/app_database.dart';
import 'package:prosodia/core/responsive/responsive.dart';
import 'package:prosodia/core/theme/app_theme.dart';
import 'package:prosodia/features/assessment/presentation/eval_state.dart';
import 'package:prosodia/features/assessment/presentation/widgets/reading_mode_bar.dart';
import 'package:prosodia/features/assessment/presentation/widgets/reading_view.dart';

/// Modo foco de teléfono: mientras hay una lectura abierta, `ReadingModeBar`
/// reemplaza a la barra con logo y botones, y el texto se queda con la pantalla.
///
/// Lo que se verifica acá es el contrato del modo, no su apariencia: qué acción
/// ofrece la barra en cada estado, que la salida exista, que el encabezado
/// desaparezca y que nada desborde en los viewports de teléfono en landscape,
/// que es la única orientación en que se ve.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final reading = ReadingText(
    id: 1,
    titulo: 'Tito, el perro alegre',
    contenido:
        'Tito es un perro pequeño y alegre. Tiene el pelo café y las orejas '
        'largas. Su juguete favorito es una pelota roja. Un día la pelota cayó '
        'al río y Tito corrió hasta la orilla y la miró.',
    nivel: '4° básico',
    totalPalabras: 288,
  );

  // El `ResponsiveScope` envuelve al `Scaffold` entero, igual que en
  // `AssessmentScreen`: la barra es `appBar`, así que un scope puesto en el
  // `body` la dejaría fuera y sin `context.responsive`.
  Widget barAt(EvalState state, {VoidCallback? onChangeReading}) => MaterialApp(
    theme: AppTheme.light,
    home: ResponsiveScope(
      builder: (context, r) => Scaffold(
        appBar: ReadingModeBar(
          height: ReadingModeBar.compactHeight,
          elapsed: const Duration(minutes: 2, seconds: 14),
          state: state,
          onStart: () {},
          onStop: () {},
          onRepeat: () {},
          onChangeReading: onChangeReading,
        ),
        body: const SizedBox.shrink(),
      ),
    ),
  );

  group('Acción de la barra según el estado', () {
    testWidgets('en reposo ofrece iniciar', (tester) async {
      await tester.pumpWidget(barAt(EvalState.idle));
      expect(find.text('Iniciar evaluación'), findsOneWidget);
      expect(find.text('02:14'), findsOneWidget);
    });

    testWidgets('grabando ofrece detener', (tester) async {
      await tester.pumpWidget(barAt(EvalState.recording));
      expect(find.text('Detener lectura'), findsOneWidget);
    });

    testWidgets('analizando no ofrece acción', (tester) async {
      await tester.pumpWidget(barAt(EvalState.analyzing));
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Analizando…'), findsOneWidget);
    });

    testWidgets('en revisión ofrece repetir', (tester) async {
      await tester.pumpWidget(barAt(EvalState.reviewing));
      expect(
        find.text('Repetir'),
        findsOneWidget,
        reason:
            'Al terminar, el docente puede considerar que la lectura debe '
            'repetirse. Ese es el control que corresponde, no volver a '
            '"Iniciar" ni quedarse sin acción.',
      );
      expect(find.text('02:14'), findsOneWidget,
          reason:
              'El tiempo sigue visible en la revisión: de ahí sale el PCPM que '
              'el docente está ajustando.');
    });
  });

  group('Salida de la lectura', () {
    testWidgets('en reposo existe, se lee como retroceso y respeta el mínimo táctil', (
      tester,
    ) async {
      await tester.pumpWidget(barAt(EvalState.idle, onChangeReading: () {}));

      final boton = find.byTooltip('Cambiar lectura');
      expect(
        boton,
        findsOneWidget,
        reason:
            'La barra reemplaza al AppBar, así que esta es la única salida de '
            'la lectura. Si no está, el docente queda encerrado.',
      );
      expect(
        find.descendant(
          of: boton,
          matching: find.byIcon(Icons.arrow_back_rounded),
        ),
        findsOneWidget,
        reason:
            'swap_horiz se leía como "intercambiar", no como "volver". '
            'arrow_back es el afordance de retroceso estándar.',
      );
      expect(
        find.byIcon(Icons.swap_horiz_rounded),
        findsNothing,
        reason: 'El ícono ambiguo no debe seguir en la barra.',
      );
      final size = tester.getSize(boton);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('va antes que el cronómetro, donde se busca "volver"', (
      tester,
    ) async {
      await tester.pumpWidget(barAt(EvalState.idle, onChangeReading: () {}));

      final botonX = tester.getTopLeft(find.byTooltip('Cambiar lectura')).dx;
      final tiempoX = tester.getTopLeft(find.text('02:14')).dx;
      expect(
        botonX,
        lessThan(tiempoX),
        reason:
            'Como el back estándar de Material, va en el extremo izquierdo de '
            'la barra — no pegado al cronómetro, donde vivía como swap_horiz '
            'sin lectura de "atrás".',
      );
    });

    testWidgets('grabando no se puede cambiar la lectura', (tester) async {
      await tester.pumpWidget(barAt(EvalState.recording));
      expect(
        find.byTooltip('Cambiar lectura'),
        findsNothing,
        reason:
            'Cambiar el texto con la grabación andando dejaría la medición sin '
            'referencia.',
      );
    });
  });

  group('Texto en modo foco', () {
    testWidgets('sin encabezado: no muestra título, curso ni alumno', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(640, 360);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ResponsiveScope(
              builder: (context, r) => ReadingView(
                text: reading,
                cursoLabel: '4°B',
                studentName: 'Josefa Mardones',
                onChangeReading: null,
                fillHeight: false,
                focus: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tito, el perro alegre'), findsNothing);
      expect(find.textContaining('Josefa'), findsNothing);
      expect(find.textContaining('Tito es un perro'), findsOneWidget);
    });

    testWidgets('el nominal de foco sube sobre el normal', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(640, 360);
      addTearDown(tester.view.reset);

      late Responsive responsive;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ResponsiveScope(
              builder: (context, r) {
                responsive = r;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(
        responsive.type.readingFocusSize,
        greaterThan(responsive.type.readingSize),
      );

      // El piso de cpl manda igual: subir el nominal no puede sacar al texto
      // del rango legible en el ancho real de un teléfono en landscape.
      const anchoUtil = 608.0;
      final size = responsive.type.readingSizeFor(
        anchoUtil,
        nominal: responsive.type.readingFocusSize,
      );
      final cpl = responsive.type.effectiveCplFor(anchoUtil, fontSize: size);
      expect(cpl, inInclusiveRange(45, 75));
    });
  });

  group('Sin desbordes en teléfono landscape', () {
    const viewports = [Size(640, 360), Size(891, 411), Size(740, 360)];

    for (final size in viewports) {
      for (final state in EvalState.values) {
        testWidgets(
          'barra ${size.width.toInt()}x${size.height.toInt()} · ${state.name}',
          (tester) async {
            final errores = <FlutterErrorDetails>[];
            final anterior = FlutterError.onError;
            FlutterError.onError = errores.add;
            addTearDown(() => FlutterError.onError = anterior);

            tester.view.devicePixelRatio = 1.0;
            tester.view.physicalSize = size;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              barAt(state, onChangeReading: state == EvalState.idle ? () {} : null),
            );
            await tester.pump();

            expect(
              errores.where((e) => e.toString().contains('overflow')),
              isEmpty,
              reason:
                  '${size.width.toInt()}x${size.height.toInt()} ${state.name}: '
                  'la barra desborda.',
            );
          },
        );
      }
    }
  });
}
