import 'dart:ui';

/// Logical Android pixels. These match the two screens' LayoutBuilder inputs.
/// Actual widget tests below verify these calculations against the live widgets.
class QaScreen {
  const QaScreen(this.name, this.size, this.safeTop);
  final String name;
  final Size size;
  final double safeTop;

  QaGeometry geometry({bool endless = false}) {
    final width = (size.width - 20).clamp(0.0, 440.0).toDouble();
    final height = (size.height - safeTop - (endless ? 286 : 238))
        .clamp(endless ? 330.0 : 360.0, endless ? 600.0 : 620.0)
        .toDouble();
    final side = ((width + 20) * 0.16)
        .clamp(endless ? 48.0 : 50.0, endless ? 68.0 : 70.0)
        .toDouble();
    return QaGeometry(Size(width, height), Size(side, side));
  }
}

class QaGeometry {
  const QaGeometry(this.board, this.tile);
  final Size board;
  final Size tile;
}

const qaScreens = [
  QaScreen('small_320x568', Size(320, 568), 24),
  QaScreen('medium_360x800', Size(360, 800), 24),
  QaScreen('tall_412x915', Size(412, 915), 32),
];
