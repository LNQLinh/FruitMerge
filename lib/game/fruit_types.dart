import 'dart:math' as math;
import 'dart:ui';

/// Draws a fruit's body (without the face) centered on the origin.
typedef FruitPainter = void Function(Canvas canvas, double r, Color color);

/// One tier in the merge chain. Two fruits of the same tier merge into the
/// next tier.
class FruitType {
  const FruitType(
    this.name,
    this.color,
    this.radius,
    this.points,
    this.paintBody, {
    this.faceY = 0,
  });

  final String name;
  final Color color;

  /// Radius in world units (meters).
  final double radius;

  /// Points awarded when this tier is created by a merge.
  final int points;

  final FruitPainter paintBody;

  /// Vertical position of the face, as a fraction of the radius.
  final double faceY;
}

const fruitTypes = <FruitType>[
  FruitType('Cherry', Color(0xFFD7263D), 0.30, 1, _paintCherry, faceY: 0.1),
  FruitType(
    'Strawberry',
    Color(0xFFFF4F6D),
    0.40,
    3,
    _paintStrawberry,
    faceY: 0.05,
  ),
  FruitType('Grape', Color(0xFF8E5CD9), 0.50, 6, _paintGrape, faceY: 0.1),
  FruitType('Lemon', Color(0xFFFFD23F), 0.62, 10, _paintLemon),
  FruitType('Orange', Color(0xFFFF8C1A), 0.75, 15, _paintOrange, faceY: 0.05),
  FruitType('Apple', Color(0xFF7BC043), 0.90, 21, _paintApple, faceY: 0.1),
  FruitType('Pear', Color(0xFFC9DB4B), 1.05, 28, _paintPear, faceY: 0.4),
  FruitType('Peach', Color(0xFFFFA8A0), 1.20, 36, _paintPeach, faceY: 0.1),
  FruitType(
    'Pineapple',
    Color(0xFFF2B134),
    1.38,
    45,
    _paintPineapple,
    faceY: 0.2,
  ),
  FruitType('Melon', Color(0xFFB8E07A), 1.58, 55, _paintMelon, faceY: 0.05),
  FruitType(
    'Watermelon',
    Color(0xFF2E9E4F),
    1.80,
    66,
    _paintWatermelon,
    faceY: 0.05,
  ),
];

/// Only the smallest tiers are handed to the player to drop.
const droppableTiers = 5;

/// Draws a fruit centered on the canvas origin. Works in any unit: every size
/// is relative to [radius], so it is used both in world space and in widgets.
void drawFruit(Canvas canvas, int tier, double radius) {
  final type = fruitTypes[tier];
  type.paintBody(canvas, radius, type.color);
  _drawFace(canvas, radius, type.faceY * radius);
}

const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);
const _leafGreen = Color(0xFF3FA34D);
const _stemBrown = Color(0xFF6B4226);
const _ink = Color(0xFF2B1B17);

Color _darker(Color c, [double t = 0.4]) => Color.lerp(c, _black, t)!;

/// Fills [path] with a soft shaded [color], applies an optional [texture]
/// clipped to the path, then adds a highlight and an outline.
void _drawShape(
  Canvas canvas,
  Path path,
  Color color,
  double r, {
  void Function()? texture,
  Offset shine = const Offset(-0.4, -0.45),
}) {
  canvas.drawPath(
    path,
    Paint()
      ..shader = Gradient.radial(
        Offset(-r * 0.35, -r * 0.35),
        r * 1.5,
        [Color.lerp(color, _white, 0.35)!, color, _darker(color, 0.15)],
        [0, 0.65, 1],
      ),
  );
  canvas.save();
  canvas.clipPath(path);
  texture?.call();
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(shine.dx * r, shine.dy * r),
      width: r * 0.5,
      height: r * 0.28,
    ),
    Paint()..color = const Color(0x66FFFFFF),
  );
  canvas.restore();
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = r * 0.07
      ..color = _darker(color),
  );
}

/// A leaf growing from [at] in the direction [angle] (0 = pointing right).
void _leaf(
  Canvas canvas,
  Offset at,
  double angle,
  double length, {
  double width = 0.45,
  Color color = _leafGreen,
}) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.rotate(angle);
  final w = length * width;
  final path = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(length * 0.5, -w, length, 0)
    ..quadraticBezierTo(length * 0.5, w, 0, 0)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = length * 0.07
    ..color = _darker(color, 0.3);
  canvas.drawPath(path, line);
  canvas.drawLine(Offset.zero, Offset(length * 0.75, 0), line);
  canvas.restore();
}

void _stem(
  Canvas canvas,
  Offset from,
  Offset control,
  Offset to,
  double width,
) {
  canvas.drawPath(
    Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = _stemBrown,
  );
}

/// Evenly scattered dots (sunflower pattern), used for seeds and pores.
void _dots(
  Canvas canvas,
  Offset center,
  double spread,
  int count,
  double dotRadius,
  Color color,
) {
  final paint = Paint()..color = color;
  for (var i = 0; i < count; i++) {
    final a = i * 2.39996;
    final d = spread * math.sqrt((i + 0.5) / count);
    canvas.drawCircle(
      center + Offset(math.cos(a) * d, math.sin(a) * d),
      dotRadius,
      paint,
    );
  }
}

/// Mirrors a right-half outline (from top center to bottom center) into a
/// closed, left-right symmetric path. Each segment is a cubic given as
/// [c1x, c1y, c2x, c2y, x, y], in units of [r].
Path _symmetric(double r, double topY, List<List<double>> right) {
  final path = Path()..moveTo(0, topY * r);
  for (final s in right) {
    path.cubicTo(s[0] * r, s[1] * r, s[2] * r, s[3] * r, s[4] * r, s[5] * r);
  }
  // Walk the same segments backwards on the left side.
  for (var i = right.length - 1; i >= 0; i--) {
    final s = right[i];
    final end = i == 0 ? [0.0, topY] : [right[i - 1][4], right[i - 1][5]];
    path.cubicTo(
      -s[2] * r,
      s[3] * r,
      -s[0] * r,
      s[1] * r,
      -end[0] * r,
      end[1] * r,
    );
  }
  return path..close();
}

void _drawFace(Canvas canvas, double r, double y) {
  final ink = Paint()..color = _ink;
  final shine = Paint()..color = _white;
  final cheek = Paint()..color = const Color(0x66FF5A7A);
  for (final side in const [-1.0, 1.0]) {
    final eye = Offset(side * r * 0.28, y - r * 0.05);
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: r * 0.17, height: r * 0.22),
      ink,
    );
    canvas.drawCircle(eye + Offset(r * 0.03, -r * 0.05), r * 0.045, shine);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(side * r * 0.47, y + r * 0.15),
        width: r * 0.2,
        height: r * 0.11,
      ),
      cheek,
    );
  }
  canvas.drawPath(
    Path()
      ..moveTo(-r * 0.11, y + r * 0.12)
      ..quadraticBezierTo(0, y + r * 0.26, r * 0.11, y + r * 0.12),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.05
      ..color = _ink,
  );
}

void _paintCherry(Canvas canvas, double r, Color color) {
  // Long, thin stem so the cherry does not read as a small apple.
  _stem(
    canvas,
    Offset(0, -r * 0.82),
    Offset(r * 0.05, -r * 1.25),
    Offset(r * 0.4, -r * 1.4),
    r * 0.07,
  );
  _leaf(canvas, Offset(r * 0.38, -r * 1.38), -0.1, r * 0.45);
  final path = _symmetric(r, -0.84, const [
    [0.4, -1.0, 0.97, -0.6, 0.97, 0.05],
    [0.95, 0.7, 0.5, 1.0, 0, 1.0],
  ]);
  _drawShape(canvas, path, color, r);
}

void _paintStrawberry(Canvas canvas, double r, Color color) {
  final path = _symmetric(r, -0.72, const [
    [0.6, -0.95, 0.95, -0.75, 0.95, -0.35],
    [1.0, 0.2, 0.5, 0.9, 0, 0.98],
  ]);
  _drawShape(
    canvas,
    path,
    color,
    r,
    texture: () => _dots(
      canvas,
      Offset(0, r * 0.1),
      r * 0.85,
      24,
      r * 0.04,
      const Color(0xFFFFE08A),
    ),
  );
  // Green calyx on top.
  final top = Offset(0, -r * 0.7);
  for (final a in const [2.7, 3.5, -math.pi / 2, -0.35, 0.45]) {
    _leaf(canvas, top, a, r * 0.42, width: 0.35);
  }
}

void _paintGrape(Canvas canvas, double r, Color color) {
  // Curly tendril next to the stem.
  canvas.drawPath(
    Path()
      ..moveTo(0, -r * 0.95)
      ..cubicTo(r * 0.4, -r * 1.15, r * 0.6, -r * 0.85, r * 0.38, -r * 0.8),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.06
      ..color = _leafGreen,
  );
  _stem(
    canvas,
    Offset(0, -r * 0.85),
    Offset(-r * 0.02, -r * 1.0),
    Offset(-r * 0.08, -r * 1.12),
    r * 0.1,
  );
  final path = Path()
    ..addOval(
      Rect.fromCenter(
        center: Offset(0, r * 0.05),
        width: r * 1.8,
        height: r * 1.9,
      ),
    );
  _drawShape(
    canvas,
    path,
    color,
    r,
    texture: () => canvas.drawCircle(
      Offset(r * 0.35, r * 0.45),
      r * 0.6,
      Paint()..color = const Color(0x22FFFFFF),
    ),
  );
}

void _paintLemon(Canvas canvas, double r, Color color) {
  canvas.save();
  canvas.rotate(-0.25);
  final path = Path()
    ..moveTo(-r, 0)
    ..cubicTo(-r * 0.9, -r * 0.15, -r * 0.85, -r * 0.75, 0, -r * 0.75)
    ..cubicTo(r * 0.85, -r * 0.75, r * 0.9, -r * 0.15, r, 0)
    ..cubicTo(r * 0.9, r * 0.15, r * 0.85, r * 0.75, 0, r * 0.75)
    ..cubicTo(-r * 0.85, r * 0.75, -r * 0.9, r * 0.15, -r, 0)
    ..close();
  _drawShape(
    canvas,
    path,
    color,
    r,
    shine: const Offset(-0.35, -0.4),
    texture: () => _dots(
      canvas,
      Offset.zero,
      r * 0.8,
      30,
      r * 0.02,
      _darker(color, 0.15).withValues(alpha: 0.6),
    ),
  );
  canvas.restore();
}

void _paintOrange(Canvas canvas, double r, Color color) {
  final path = Path()
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * 0.97));
  _drawShape(
    canvas,
    path,
    color,
    r,
    texture: () => _dots(
      canvas,
      Offset.zero,
      r * 0.95,
      40,
      r * 0.022,
      _darker(color, 0.2).withValues(alpha: 0.5),
    ),
  );
  canvas.drawCircle(
    Offset(0, -r * 0.82),
    r * 0.07,
    Paint()..color = const Color(0xFF5E8C2A),
  );
  _leaf(canvas, Offset(r * 0.03, -r * 0.85), -0.5, r * 0.5);
}

void _paintApple(Canvas canvas, double r, Color color) {
  _stem(
    canvas,
    Offset(0, -r * 0.62),
    Offset(-r * 0.02, -r * 0.9),
    Offset(r * 0.08, -r * 1.12),
    r * 0.1,
  );
  _leaf(canvas, Offset(r * 0.05, -r * 0.92), -0.45, r * 0.5);
  final path = _symmetric(r, -0.65, const [
    [0.35, -1.0, 1.0, -0.85, 0.98, -0.1],
    [0.95, 0.6, 0.55, 1.0, 0.2, 0.95],
    [0.12, 0.92, 0.06, 0.88, 0, 0.88],
  ]);
  _drawShape(canvas, path, color, r);
}

void _paintPear(Canvas canvas, double r, Color color) {
  _stem(
    canvas,
    Offset(0, -r * 0.88),
    Offset(r * 0.02, -r * 1.05),
    Offset(r * 0.12, -r * 1.15),
    r * 0.09,
  );
  _leaf(canvas, Offset(r * 0.06, -r * 1.02), -2.6, r * 0.42);
  final path = _symmetric(r, -0.92, const [
    [0.3, -0.92, 0.38, -0.6, 0.45, -0.3],
    [0.52, -0.05, 0.95, 0.15, 0.92, 0.55],
    [0.9, 0.9, 0.5, 1.0, 0, 1.0],
  ]);
  _drawShape(
    canvas,
    path,
    color,
    r,
    shine: const Offset(-0.45, 0.15),
    texture: () => _dots(
      canvas,
      Offset(0, r * 0.3),
      r * 0.75,
      16,
      r * 0.025,
      const Color(0x668A6D3B),
    ),
  );
}

void _paintPeach(Canvas canvas, double r, Color color) {
  final path = _symmetric(r, -0.7, const [
    [0.35, -1.0, 1.0, -0.8, 0.97, 0],
    [0.95, 0.7, 0.5, 1.0, 0, 1.0],
  ]);
  _drawShape(
    canvas,
    path,
    color,
    r,
    texture: () {
      // Warm yellow underside blending into the pink blush.
      canvas.drawCircle(
        Offset(-r * 0.3, r * 0.6),
        r * 0.9,
        Paint()
          ..shader = Gradient.radial(Offset(-r * 0.3, r * 0.6), r * 0.9, [
            const Color(0x99FFD27A),
            const Color(0x00FFD27A),
          ]),
      );
      canvas.drawPath(
        Path()
          ..moveTo(r * 0.05, -r * 0.68)
          ..cubicTo(r * 0.5, -r * 0.45, r * 0.72, r * 0.1, r * 0.62, r * 0.55),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = r * 0.05
          ..color = _darker(color, 0.25).withValues(alpha: 0.6),
      );
    },
  );
  _leaf(canvas, Offset(0, -r * 0.7), -0.55, r * 0.5);
  _leaf(canvas, Offset(0, -r * 0.7), -2.5, r * 0.4);
}

void _paintPineapple(Canvas canvas, double r, Color color) {
  // Spiky crown, drawn first so the body hides its base.
  final crown = Offset(0, -r * 0.55);
  const spikes = [
    [-math.pi / 2, 0.65],
    [-math.pi / 2 - 0.4, 0.55],
    [-math.pi / 2 + 0.4, 0.55],
    [-math.pi / 2 - 0.85, 0.45],
    [-math.pi / 2 + 0.85, 0.45],
  ];
  for (final s in spikes) {
    _leaf(canvas, crown, s[0], r * s[1], width: 0.28);
  }
  final path = Path()
    ..addOval(
      Rect.fromCenter(
        center: Offset(0, r * 0.15),
        width: r * 1.75,
        height: r * 1.7,
      ),
    );
  _drawShape(
    canvas,
    path,
    color,
    r,
    shine: const Offset(-0.35, -0.3),
    texture: () {
      final line = Paint()
        ..strokeWidth = r * 0.045
        ..color = _darker(color, 0.35).withValues(alpha: 0.7);
      for (var x = -2.0; x <= 2.0; x += 0.32) {
        canvas.drawLine(
          Offset((x - 1) * r, -r),
          Offset((x + 1) * r, r * 1.1),
          line,
        );
        canvas.drawLine(
          Offset((x + 1) * r, -r),
          Offset((x - 1) * r, r * 1.1),
          line,
        );
      }
    },
  );
}

void _paintMelon(Canvas canvas, double r, Color color) {
  _stem(
    canvas,
    Offset(0, -r * 0.9),
    Offset(0, -r * 1.0),
    Offset(r * 0.05, -r * 1.1),
    r * 0.1,
  );
  final path = Path()
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * 0.97));
  _drawShape(
    canvas,
    path,
    color,
    r,
    texture: () {
      final net = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..color = const Color(0xAAF7F9E8);
      for (final k in const [-0.9, -0.45, 0.45, 0.9]) {
        canvas.drawPath(
          Path()
            ..moveTo(0, -r)
            ..quadraticBezierTo(k * r * 1.3, 0, 0, r),
          net,
        );
      }
      for (final y in const [-0.55, 0.55]) {
        canvas.drawPath(
          Path()
            ..moveTo(-r, y * r)
            ..quadraticBezierTo(0, (y + 0.2) * r, r, y * r),
          net,
        );
      }
    },
  );
}

void _paintWatermelon(Canvas canvas, double r, Color color) {
  _stem(
    canvas,
    Offset(0, -r * 0.9),
    Offset(0, -r * 1.0),
    Offset(r * 0.06, -r * 1.08),
    r * 0.09,
  );
  final path = Path()
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * 0.97));
  _drawShape(
    canvas,
    path,
    color,
    r,
    texture: () {
      final stripe = Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = r * 0.13
        ..color = const Color(0xFF17602C);
      // Zig-zag stripes running from the stem to the bottom.
      for (final k in const [-0.95, -0.6, 0.6, 0.95]) {
        final stripePath = Path()..moveTo(0, -r);
        for (var i = 1; i <= 12; i++) {
          final t = -1 + i / 6;
          final wobble = i.isEven ? 0.06 : -0.06;
          final x = (k * math.sqrt(1 - t * t) + wobble) * r;
          stripePath.lineTo(x, t * r);
        }
        canvas.drawPath(stripePath, stripe);
      }
    },
  );
}
