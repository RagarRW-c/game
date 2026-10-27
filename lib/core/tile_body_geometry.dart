import 'dart:math' as math;
import 'dart:ui';

/// Physical tile bodies, excluding transparent canvas margins and cast shadows.
/// Coordinates are local to the unchanged tile layout/hit rectangle.
class TileBodyGeometry {
  const TileBodyGeometry._();

  static const illustratedTypes = <String>{
    'apple',
    'banana',
    'berry',
    'carrot',
    'star',
    'shell',
    'flower',
    'moon',
    'gem',
    'leaf',
    'candy',
    'heart',
  };

  static Rect artworkRect(Size size) => Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.shortestSide,
      height: size.shortestSide);

  static RRect illustratedBody(Size size) {
    final square = artworkRect(size);
    final unit = square.width;
    // Measured opaque bodies in the 320px PNGs: approximately x=15..303,
    // y=8..307, with 70px rounded corners. Ignore the soft exterior shadow.
    return RRect.fromRectAndRadius(
        Rect.fromLTRB(
            square.left + unit * 15 / 320,
            square.top + unit * 8 / 320,
            square.right - unit * 17 / 320,
            square.bottom - unit * 13 / 320),
        Radius.circular(unit * 70 / 320));
  }

  static Rect fallbackFace(Size size) {
    final unit = size.shortestSide;
    return Rect.fromLTRB(unit * .025, unit * .025, size.width - unit * .025,
        size.height - unit * .12);
  }

  static RRect fallbackBody(Size size) {
    final unit = size.shortestSide;
    final face = fallbackFace(size);
    return RRect.fromRectAndRadius(
        Rect.fromLTRB(face.left, face.top + unit * .06, face.right,
            size.height - unit * .035),
        Radius.circular(unit * .19));
  }

  /// The cap and lower bevel together form this silhouette; neither shadow
  /// nor pressed/flight transforms should change resting board availability.
  static RRect bodyFor(String type, Size size) {
    if (illustratedTypes.contains(type)) return illustratedBody(size);
    final face = fallbackFace(size);
    final unit = size.shortestSide;
    return RRect.fromRectAndRadius(
        Rect.fromLTRB(
            face.left, face.top, face.right, size.height - unit * .035),
        Radius.circular(unit * .19));
  }

  /// Exact intersection predicate for two axis-aligned rounded rectangles
  /// with uniform circular corners. No Path.combine, pixel reads or allocations
  /// proportional to the number of pixels are needed during board rebuilding.
  static bool bodiesOverlap(RRect first, RRect second) {
    if (!first.outerRect.overlaps(second.outerRect)) return false;
    final a = first.scaleRadii();
    final b = second.scaleRadii();
    final radius = a.tlRadiusX + b.tlRadiusX;
    if (radius == 0) return true;
    final delta = a.center - b.center;
    final dx = math.max(0.0, delta.dx.abs() - (a.width + b.width) / 2 + radius);
    final dy =
        math.max(0.0, delta.dy.abs() - (a.height + b.height) / 2 + radius);
    return dx * dx + dy * dy < radius * radius;
  }
}
