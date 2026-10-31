import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game/fruit_types.dart';

/// Màu viền chung cho các icon, giống màu chữ của HUD.
const _outline = Color(0xFF4E342E);

/// Nét viền dày kiểu hoạt hình, tỉ lệ theo kích thước icon [s].
Paint _outlinePaint(double s) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..strokeWidth = s * 0.06
  ..color = _outline;

/// Tô [rrect] bằng gradient dọc từ [light] xuống [dark], kẻ viền và thêm vệt
/// sáng ở nửa trên để trông bóng bẩy.
void _drawBlock(Canvas canvas, RRect rrect, Color light, Color dark, double s) {
  canvas.drawRRect(
    rrect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [light, dark],
      ).createShader(rrect.outerRect),
  );
  final r = rrect.outerRect;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        r.left + r.width * 0.18,
        r.top + r.height * 0.14,
        r.width * 0.64,
        r.height * 0.2,
      ),
      Radius.circular(r.shortestSide * 0.1),
    ),
    Paint()..color = const Color(0x88FFFFFF),
  );
  canvas.drawRRect(rrect, _outlinePaint(s));
}

/// Icon búa: cán gỗ và đầu búa thép, đặt nghiêng như đang gõ.
class HammerIconPainter extends CustomPainter {
  const HammerIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.6);

    // Cán gỗ, có hai vòng quấn tay cầm ở phía dưới.
    final handle = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, s * 0.14),
        width: s * 0.17,
        height: s * 0.64,
      ),
      Radius.circular(s * 0.08),
    );
    _drawBlock(
      canvas,
      handle,
      const Color(0xFFD7A15E),
      const Color(0xFF8D5524),
      s,
    );
    for (final y in [0.3, 0.38]) {
      canvas.drawLine(
        Offset(-s * 0.08, s * y),
        Offset(s * 0.08, s * y),
        _outlinePaint(s)..strokeWidth = s * 0.04,
      );
    }

    // Đầu búa bằng thép.
    final head = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -s * 0.2),
        width: s * 0.66,
        height: s * 0.28,
      ),
      Radius.circular(s * 0.07),
    );
    _drawBlock(
      canvas,
      head,
      const Color(0xFFECEFF4),
      const Color(0xFF8C99A8),
      s,
    );
  }

  @override
  bool shouldRepaint(HammerIconPainter oldDelegate) => false;
}

/// Icon đổi quả: hai mũi tên cong xanh lá và xanh dương đuổi nhau thành vòng.
class SwapIconPainter extends CustomPainter {
  const SwapIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    _arrow(canvas, c, s, 200, 140, const Color(0xFF66BB6A));
    _arrow(canvas, c, s, 20, 140, const Color(0xFF42A5F5));
  }

  /// Vẽ một mũi tên cong quanh tâm [c], bắt đầu ở góc [startDeg] và quét
  /// [sweepDeg] độ theo chiều kim đồng hồ, đầu mũi tên ở cuối cung.
  void _arrow(
    Canvas canvas,
    Offset c,
    double s,
    double startDeg,
    double sweepDeg,
    Color color,
  ) {
    final radius = s * 0.28;
    final start = startDeg * math.pi / 180;
    final end = (startDeg + sweepDeg) * math.pi / 180;
    final arc = Path()
      ..addArc(Rect.fromCircle(center: c, radius: radius), start, end - start);

    // Đầu mũi tên: tam giác hướng theo tiếp tuyến tại cuối cung.
    final p = c + Offset(math.cos(end), math.sin(end)) * radius;
    final along = Offset(-math.sin(end), math.cos(end));
    final across = Offset(math.cos(end), math.sin(end));
    final head = Path()
      ..moveTo(p.dx + along.dx * s * 0.16, p.dy + along.dy * s * 0.16)
      ..lineTo(p.dx + across.dx * s * 0.14, p.dy + across.dy * s * 0.14)
      ..lineTo(p.dx - across.dx * s * 0.14, p.dy - across.dy * s * 0.14)
      ..close();

    final body = s * 0.13;
    // Vẽ viền trước rồi tô màu đè lên, để thân và đầu mũi tên liền một khối.
    canvas.drawPath(arc, _outlinePaint(s)..strokeWidth = body + s * 0.1);
    canvas.drawPath(head, _outlinePaint(s)..strokeWidth = s * 0.1);
    canvas.drawPath(
      arc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = body
        ..color = color,
    );
    canvas.drawPath(head, Paint()..color = color);
    // Vệt sáng mảnh chạy dọc thân mũi tên.
    canvas.drawPath(
      Path()..addArc(
        Rect.fromCircle(center: c, radius: radius - body * 0.2),
        start + 0.25,
        (end - start) * 0.55,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = body * 0.3
        ..color = const Color(0x88FFFFFF),
    );
  }

  @override
  bool shouldRepaint(SwapIconPainter oldDelegate) => false;
}

/// Icon lắc bình: cái bình nhỏ nghiêng có hai quả bên trong, hai bên có
/// vạch chuyển động.
class ShakeIconPainter extends CustomPainter {
  const ShakeIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.translate(size.width / 2, size.height / 2);

    // Vạch chuyển động hình ngoặc ở hai bên bình.
    final motion = _outlinePaint(s)..strokeWidth = s * 0.05;
    for (final side in [-1.0, 1.0]) {
      for (final k in [0.36, 0.46]) {
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(side * s * (k - 0.2), 0),
            radius: s * 0.2,
          ),
          side < 0 ? math.pi * 0.8 : -math.pi * 0.2,
          math.pi * 0.4,
          false,
          motion,
        );
      }
    }

    canvas.rotate(0.2);
    final jar = RRect.fromRectAndCorners(
      Rect.fromCenter(
        center: Offset(0, s * 0.05),
        width: s * 0.48,
        height: s * 0.58,
      ),
      topLeft: Radius.circular(s * 0.04),
      topRight: Radius.circular(s * 0.04),
      bottomLeft: Radius.circular(s * 0.12),
      bottomRight: Radius.circular(s * 0.12),
    );
    canvas.drawRRect(jar, Paint()..color = const Color(0xFFBBDEFB));
    // Hai quả nhỏ trong bình, dùng lại hàm vẽ quả của game.
    canvas.save();
    canvas.clipRRect(jar);
    canvas.save();
    canvas.translate(-s * 0.08, s * 0.2);
    drawFruit(canvas, 0, s * 0.11);
    canvas.restore();
    canvas.save();
    canvas.translate(s * 0.1, s * 0.12);
    drawFruit(canvas, 2, s * 0.1);
    canvas.restore();
    canvas.restore();
    canvas.drawRRect(jar, _outlinePaint(s));
    // Miệng bình.
    _drawBlock(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -s * 0.25),
          width: s * 0.56,
          height: s * 0.1,
        ),
        Radius.circular(s * 0.04),
      ),
      const Color(0xFF90CAF9),
      const Color(0xFF5C7A99),
      s,
    );
  }

  @override
  bool shouldRepaint(ShakeIconPainter oldDelegate) => false;
}
