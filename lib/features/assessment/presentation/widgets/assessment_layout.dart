import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive.dart';
import 'surfaces.dart';

/// Compone el panel de control y el área de trabajo según el ancho disponible.
///
/// `dual` es el layout de tablet en landscape —el caso de producción—: control
/// a la izquierda, lectura a la derecha, ambos con su propio scroll.
///
/// `stacked` es una columna scrolleable, y no una versión encogida del anterior:
/// bajo 720 dp los dos paneles no caben sin dejar ninguno inutilizable.
class AssessmentLayout extends StatelessWidget {
  const AssessmentLayout({
    super.key,
    required this.controlPanel,
    required this.workArea,
    required this.workAreaFirst,
    this.showWorkArea = true,
  });

  final Widget controlPanel;
  final Widget workArea;

  /// En composición apilada, si el área de trabajo va arriba. Se activa cuando
  /// hay una lectura abierta: en ese momento el texto es lo que el docente y el
  /// estudiante están mirando, y el panel de control pasa a segundo plano.
  final bool workAreaFirst;

  /// En composición apilada, si el área de trabajo se dibuja como segundo
  /// panel. `false` cuando no aporta nada que el panel de control —siempre
  /// visible primero en ese caso— no muestre ya (ver `AssessmentScreen`). No
  /// afecta a `dual`: ahí son dos columnas independientes y la de trabajo
  /// siempre se dibuja.
  final bool showWorkArea;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    if (r.paneStrategy.isDual) {
      return Padding(
        padding: EdgeInsets.all(r.spacing.gutter),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: r.controlPanelWidth,
              child: SurfacePanel(
                padding: EdgeInsets.all(r.spacing.lg),
                child: controlPanel,
              ),
            ),
            SizedBox(width: r.spacing.paneGap),
            Expanded(
              child: SurfacePanel(
                padding: EdgeInsets.all(r.spacing.lg),
                child: workArea,
              ),
            ),
          ],
        ),
      );
    }

    if (!showWorkArea) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(r.spacing.gutter),
        child: SurfacePanel(
          padding: EdgeInsets.all(r.spacing.lg),
          child: controlPanel,
        ),
      );
    }

    final panels = [
      SurfacePanel(
        padding: EdgeInsets.all(r.spacing.lg),
        child: workAreaFirst ? workArea : controlPanel,
      ),
      SizedBox(height: r.spacing.paneGap),
      SurfacePanel(
        padding: EdgeInsets.all(r.spacing.lg),
        child: workAreaFirst ? controlPanel : workArea,
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.spacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: panels,
      ),
    );
  }
}
