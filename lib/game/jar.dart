import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

/// Jar dimensions in world units. The jar spans x in [-halfWidth, halfWidth]
/// and y in [0, height], with y pointing down.
const jarHalfWidth = 3.0;
const jarHeight = 9.0;

/// A fruit resting above this line for too long ends the game.
const dangerLineY = 1.2;

/// Static walls and floor of the jar, plus its background and danger line.
class Jar extends BodyComponent {
  Jar() : super(renderBody: false, priority: -1);

  @override
  Body createBody() {
    final body = world.createBody(BodyDef());
    final def = ShapeDef(material: SurfaceMaterial(friction: 0.5));
    const top = -2.0; // walls extend above the jar so fruits cannot escape
    body
      ..createShape(
        Segment(
          point1: Vector2(-jarHalfWidth, top),
          point2: Vector2(-jarHalfWidth, jarHeight),
        ),
        def,
      )
      ..createShape(
        Segment(
          point1: Vector2(jarHalfWidth, top),
          point2: Vector2(jarHalfWidth, jarHeight),
        ),
        def,
      )
      ..createShape(
        Segment(
          point1: Vector2(-jarHalfWidth, jarHeight),
          point2: Vector2(jarHalfWidth, jarHeight),
        ),
        def,
      )
      // Nắp vô hình phía trên miệng bình: chặn quả bị lắc tung quá cao bay
      // ra ngoài.
      ..createShape(
        Segment(
          point1: Vector2(-jarHalfWidth, top),
          point2: Vector2(jarHalfWidth, top),
        ),
        def,
      );
    return body;
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTRB(-jarHalfWidth, 0, jarHalfWidth, jarHeight);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(0.4),
        bottomRight: const Radius.circular(0.4),
      ),
      Paint()..color = const Color(0xFFE3F2FD),
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(0.4),
        bottomRight: const Radius.circular(0.4),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08
        ..color = const Color(0xFF5C7A99),
    );

    // Dashed danger line
    final dash = Paint()
      ..strokeWidth = 0.05
      ..color = const Color(0xAAE53935);
    for (var x = -jarHalfWidth; x < jarHalfWidth; x += 0.4) {
      canvas.drawLine(
        Offset(x, dangerLineY),
        Offset(math.min(x + 0.22, jarHalfWidth), dangerLineY),
        dash,
      );
    }
  }
}
