import 'package:flutter/material.dart';

import 'outlined_text.dart';

const _gold = Color(0xFFFFC83D);
const _goldDark = Color(0xFFE09A12);

/// Icon vương miện vàng viền nâu, đặt cạnh điểm BEST.
class CrownIconPainter extends CustomPainter {
  const CrownIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Ba chóp nhọn và thân vương miện, đi theo chiều kim đồng hồ.
    final crown = Path()
      ..moveTo(w * 0.08, h * 0.3)
      ..lineTo(w * 0.3, h * 0.52)
      ..lineTo(w * 0.5, h * 0.18)
      ..lineTo(w * 0.7, h * 0.52)
      ..lineTo(w * 0.92, h * 0.3)
      ..lineTo(w * 0.84, h * 0.82)
      ..lineTo(w * 0.16, h * 0.82)
      ..close();
    canvas.drawPath(
      crown,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_gold, _goldDark],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      crown,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = w * 0.09
        ..color = cartoonBrown,
    );
    // Viên ngọc tròn trên mỗi chóp.
    final gem = Paint()..color = const Color(0xFFE53935);
    for (final p in [
      Offset(w * 0.08, h * 0.26),
      Offset(w * 0.5, h * 0.14),
      Offset(w * 0.92, h * 0.26),
    ]) {
      canvas.drawCircle(p, w * 0.08, gem);
      canvas.drawCircle(
        p,
        w * 0.08,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.05
          ..color = cartoonBrown,
      );
    }
  }

  @override
  bool shouldRepaint(CrownIconPainter oldDelegate) => false;
}

/// Icon đồng coin vàng: viền nâu, vành trong đậm hơn và vệt sáng bóng.
class CoinIconPainter extends CustomPainter {
  const CoinIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      c,
      r * 0.92,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [const Color(0xFFFFE58A), _gold, _goldDark],
          stops: const [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.58,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14
        ..color = _goldDark,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.3, -r * 0.4),
        width: r * 0.5,
        height: r * 0.26,
      ),
      Paint()..color = const Color(0xAAFFFFFF),
    );
    canvas.drawCircle(
      c,
      r * 0.92,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16
        ..color = cartoonBrown,
    );
  }

  @override
  bool shouldRepaint(CoinIconPainter oldDelegate) => false;
}

/// Icon "bỏ quảng cáo": chữ ADS trên nền trắng, gạch chéo bởi vòng cấm đỏ.
class NoAdsIconPainter extends CustomPainter {
  const NoAdsIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final r = s * 0.46;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    final text = TextPainter(
      text: TextSpan(
        text: 'ADS',
        style: TextStyle(
          fontSize: s * 0.3,
          fontWeight: FontWeight.w900,
          color: cartoonBrown,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, c - Offset(text.width / 2, text.height / 2));
    // Vòng cấm đỏ và vạch chéo từ trên trái xuống dưới phải.
    final red = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.1
      ..color = const Color(0xFFE53935);
    canvas.drawCircle(c, r * 0.85, red);
    final d = r * 0.6;
    canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), red);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.06
        ..color = cartoonBrown,
    );
  }

  @override
  bool shouldRepaint(NoAdsIconPainter oldDelegate) => false;
}
