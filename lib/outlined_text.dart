import 'package:flutter/material.dart';

/// Màu nâu đậm dùng cho viền và bóng các chi tiết hoạt hình.
const cartoonBrown = Color(0xFF4E342E);

/// Chữ to kiểu hoạt hình: viền dày, bóng đổ đặc và ruột màu [color].
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    required this.color,
    this.size = 84,
    this.outline = cartoonBrown,
  });

  final String text;
  final Color color;
  final double size;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size / 7
              ..strokeJoin = StrokeJoin.round
              ..color = outline,
            shadows: [Shadow(color: outline, offset: Offset(0, size / 14))],
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
