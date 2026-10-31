import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game/fruit_types.dart';
import 'game/player_progress.dart';
import 'main.dart';
import 'outlined_text.dart';

/// Thời gian tối thiểu hiển thị màn splash, kể cả khi tải xong sớm hơn.
const _minSplashTime = Duration(milliseconds: 2200);

const _stripeLight = Color(0xFFEAD7FB);
const _stripeDark = Color(0xFFE2CCF6);

/// Màn chờ lúc mở app: nền sọc tím, quả dưa hấu lớn cùng các quả nhỏ nhún
/// nhảy và chữ "Loading". Đọc tiến trình người chơi xong thì chuyển vào game.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _loadAndEnterGame();
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  /// Tải tiến trình (song song với thời gian chờ tối thiểu) rồi mờ dần sang
  /// màn chơi.
  Future<void> _loadAndEnterGame() async {
    final (progress, _) = await (
      PlayerProgress.load(),
      Future<void>.delayed(_minSplashTime),
    ).wait;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => GameScreen(progress: progress),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomPaint(
        painter: const _StripesPainter(),
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = math.min(constraints.maxWidth * 0.95, 420.0);
              return Stack(
                children: [
                  Center(
                    child: AnimatedBuilder(
                      animation: _bob,
                      builder: (_, _) => CustomPaint(
                        size: Size.square(side),
                        painter: _SplashArtPainter(_bob.value),
                      ),
                    ),
                  ),
                  const Align(
                    alignment: Alignment(0, 0.78),
                    child: OutlinedText(
                      'Loading',
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Nền sọc dọc hai tông tím nhạt.
class _StripesPainter extends CustomPainter {
  const _StripesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _stripeLight);
    final stripe = Paint()..color = _stripeDark;
    final w = size.width / 6;
    for (var x = w; x < size.width; x += w * 2) {
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), stripe);
    }
  }

  @override
  bool shouldRepaint(_StripesPainter oldDelegate) => false;
}

/// Cụm quả trên màn splash. [t] chạy từ 0 tới 1 lặp lại, dùng để mỗi quả
/// nhún lên xuống lệch nhịp nhau.
class _SplashArtPainter extends CustomPainter {
  const _SplashArtPainter(this.t);

  final double t;

  /// Độ nhún của một quả, lệch pha [phase] (0..1) so với các quả khác.
  double _bob(double s, double phase, double amount) =>
      math.sin((t + phase) * 2 * math.pi) * s * amount;

  /// Vẽ quả loại [tier] bán kính [r] tại [at], hơi nghiêng một góc [tilt].
  void _fruit(Canvas canvas, int tier, Offset at, double r, double tilt) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(tilt);
    drawFruit(canvas, tier, r);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.translate(size.width / 2, size.height / 2);

    // Hai vệt chuyển động màu trắng mờ quanh cụm quả.
    final swoosh = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.03
      ..color = const Color(0x77FFFFFF);
    final ring = Rect.fromCircle(center: Offset.zero, radius: s * 0.43);
    canvas.drawArc(ring, -2.1, 0.7, false, swoosh);
    canvas.drawArc(ring, 1.2, 0.8, false, swoosh);

    _fruit(
      canvas,
      1,
      Offset(s * 0.3, -s * 0.24 + _bob(s, 0.25, 0.02)),
      s * 0.11,
      0.25,
    );
    _fruit(canvas, 10, Offset(0, _bob(s, 0, 0.012)), s * 0.3, -0.05);
    _fruit(
      canvas,
      3,
      Offset(-s * 0.31, s * 0.19 + _bob(s, 0.5, 0.018)),
      s * 0.13,
      -0.2,
    );
    _fruit(
      canvas,
      2,
      Offset(-s * 0.13, s * 0.3 + _bob(s, 0.75, 0.022)),
      s * 0.09,
      0.1,
    );
  }

  @override
  bool shouldRepaint(_SplashArtPainter oldDelegate) => oldDelegate.t != t;
}
