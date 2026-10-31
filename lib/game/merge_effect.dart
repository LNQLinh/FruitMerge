import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// Thời gian tồn tại của hiệu ứng (giây).
const _life = 0.55;

/// Một giọt nước ép bắn ra từ chỗ gộp quả.
class _Drop {
  _Drop(this.position, this.velocity, this.size);

  final Vector2 position;
  final Vector2 velocity;
  final double size;
}

/// Hiệu ứng khi hai quả gộp lại (hoặc bị búa đập): chớp sáng ở tâm, vòng sáng
/// lan rộng ra và các giọt nước ép cùng màu quả bắn tung toé. Quả càng lớn
/// ([radius] càng to) thì hiệu ứng càng to và nhiều giọt hơn.
class MergeEffect extends PositionComponent {
  MergeEffect({
    required Vector2 position,
    required this.color,
    required this.radius,
  }) : super(position: position, priority: 10) {
    final random = math.Random();
    final count = 8 + (radius * 8).round();
    _drops = List.generate(count, (_) {
      final angle = random.nextDouble() * 2 * math.pi;
      final dir = Vector2(math.cos(angle), math.sin(angle));
      final speed = radius * (3 + random.nextDouble() * 3);
      return _Drop(
        dir * (radius * 0.5),
        dir * speed,
        radius * (0.08 + random.nextDouble() * 0.08),
      );
    });
  }

  final Color color;
  final double radius;
  late final List<_Drop> _drops;
  double _time = 0;

  /// Di chuyển các giọt theo trọng lực và lực cản không khí, tự xoá khi hết
  /// thời gian.
  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_time >= _life) {
      removeFromParent();
      return;
    }
    for (final d in _drops) {
      d.velocity
        ..y += 12 * dt
        ..scale(1 - 3 * dt);
      d.position.addScaled(d.velocity, dt);
    }
  }

  @override
  void render(Canvas canvas) {
    final p = (_time / _life).clamp(0.0, 1.0);
    final fade = 1 - p;

    // Chớp sáng ngắn ở tâm trong 1/4 thời gian đầu.
    final flash = (1 - p * 4).clamp(0.0, 1.0);
    if (flash > 0) {
      canvas.drawCircle(
        Offset.zero,
        radius * 1.1,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: flash * 0.6),
      );
    }

    // Vòng sáng lan rộng, nhanh lúc đầu rồi chậm dần.
    final ease = 1 - math.pow(1 - p, 3);
    canvas.drawCircle(
      Offset.zero,
      radius * (1 + 0.9 * ease),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.14 * fade
        ..color = const Color(0xFFFFFFFF).withValues(alpha: fade * 0.9),
    );

    // Giọt nước ép, nhỏ dần và mờ dần.
    final drop = Paint()..color = color.withValues(alpha: fade);
    final shine = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: fade * 0.7);
    for (final d in _drops) {
      final r = d.size * (1 - p * 0.6);
      final c = Offset(d.position.x, d.position.y);
      canvas.drawCircle(c, r, drop);
      canvas.drawCircle(c - Offset(r * 0.3, r * 0.3), r * 0.35, shine);
    }
  }
}
