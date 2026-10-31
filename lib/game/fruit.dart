import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import 'fruit_types.dart';

/// Thời gian hiệu ứng nảy của quả mới gộp (giây).
const _popDuration = 0.3;

/// A physical fruit in the jar.
class Fruit extends BodyComponent {
  Fruit(this.tier, this.spawnPosition, {this.popIn = false})
    : super(renderBody: false);

  final int tier;
  final Vector2 spawnPosition;

  /// Quả sinh ra từ việc gộp: lúc xuất hiện sẽ phồng lên rồi nảy về cỡ thật.
  final bool popIn;

  /// Set once this fruit has been consumed by a merge, so it is not merged
  /// twice in the same frame.
  bool merged = false;

  /// Seconds since the fruit entered the jar. Fresh fruits are ignored by the
  /// game-over check while they are still falling.
  double age = 0;

  double get radius => fruitTypes[tier].radius;

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(type: BodyType.dynamic, position: spawnPosition),
    );
    body.createShape(
      Circle(radius: radius),
      ShapeDef(
        density: 1,
        material: SurfaceMaterial(friction: 0.4, restitution: 0.1),
      ),
    );
    return body;
  }

  @override
  void update(double dt) {
    super.update(dt);
    age += dt;
  }

  @override
  void render(Canvas canvas) {
    if (popIn && age < _popDuration) {
      // Phóng từ 50% lên hơi quá cỡ rồi nảy về 100% (easeOutBack).
      const c1 = 1.70158;
      final x = age / _popDuration - 1;
      final ease = 1 + (c1 + 1) * x * x * x + c1 * x * x;
      final scale = 0.5 + 0.5 * ease;
      canvas.save();
      canvas.scale(scale);
      drawFruit(canvas, tier, radius);
      canvas.restore();
      return;
    }
    drawFruit(canvas, tier, radius);
  }
}
