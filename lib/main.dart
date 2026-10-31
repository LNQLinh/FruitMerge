import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/fruit_fusion_game.dart';
import 'game/fruit_types.dart';
import 'game/player_progress.dart';
import 'hud_icons.dart';
import 'outlined_text.dart';
import 'power_up_icons.dart';
import 'purchases.dart';
import 'ads.dart';
import 'shop_dialogs.dart';
import 'splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const FruitFusionApp());
}

class FruitFusionApp extends StatelessWidget {
  const FruitFusionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fruit Fusion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFFFF8C1A)),
      home: const SplashScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.progress});

  final PlayerProgress progress;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final _game = FruitFusionGame(widget.progress);
  final _ads = GameAds();
  late final _purchases = Purchases(widget.progress);

  /// Đang chiếu quảng cáo trước khi chơi lại, chặn bấm chơi lại nhiều lần.
  bool _restarting = false;

  @override
  void initState() {
    super.initState();
    _ads.init();
    _purchases.init();
    widget.progress.levelUps.addListener(_onLevelUp);
  }

  @override
  void dispose() {
    widget.progress.levelUps.removeListener(_onLevelUp);
    _purchases.dispose();
    super.dispose();
  }

  /// Chơi lại (bấm ↻ hoặc "Play again" khi thua): người chơi thường phải xem
  /// quảng cáo xen kẽ trước, người đã mua gói bỏ quảng cáo thì vào ván mới ngay.
  void _restart() {
    if (_restarting) return;
    if (widget.progress.isAdFree) {
      _game.restart();
      return;
    }
    _restarting = true;
    _game.pauseEngine();
    _ads.showInterstitial(() {
      _restarting = false;
      _game.restart();
      _game.resumeEngine();
    });
  }

  /// Mở popup mua gói bỏ quảng cáo.
  void _openNoAds() =>
      showNoAdsOffer(context, game: _game, purchases: _purchases);

  /// Lên level thì mở popup chọn nhận coin hoặc xem quảng cáo nhận gấp đôi.
  void _onLevelUp() => showLevelUpReward(context, game: _game, ads: _ads);

  /// Hết lượt trợ giúp [p] thì mở popup mua thêm.
  void _openShop(PowerUp p) =>
      showPowerUpShop(context, game: _game, ads: _ads, powerUp: p);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Drag to aim, release (or tap) to drop.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _game.aimAt(d.localPosition),
            onPanUpdate: (d) => _game.aimAt(d.localPosition),
            onPanEnd: (_) => _game.drop(),
            onTapUp: (d) => _game.tapAt(d.localPosition),
            child: GameWidget(
              game: _game,
              overlayBuilderMap: {
                FruitFusionGame.gameOverOverlay: (context, game) =>
                    _GameOverPanel(game: _game, onRestart: _restart),
              },
            ),
          ),
          Center(child: _ComboBanner(combo: _game.combo)),
          SafeArea(
            child: _Hud(game: _game, onRestart: _restart, onNoAds: _openNoAds),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: _PowerUpBar(game: _game, onShop: _openShop),
            ),
          ),
        ],
      ),
    );
  }
}

/// HUD phía trên: trái là kỷ lục (vương miện) và số coin, giữa là bảng level
/// kèm điểm ván hiện tại, phải là nút chơi lại và các quả sắp tới.
class _Hud extends StatelessWidget {
  const _Hud({
    required this.game,
    required this.onRestart,
    required this.onNoAds,
  });

  final FruitFusionGame game;
  final VoidCallback onRestart;
  final VoidCallback onNoAds;

  @override
  Widget build(BuildContext context) {
    final progress = game.progress;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hai cột hai bên chia đều phần còn lại để bảng level luôn ở giữa;
          // nội dung tự thu nhỏ nếu màn hình hẹp.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IgnorePointer(
                    child: ValueListenableBuilder<int>(
                      valueListenable: progress.best,
                      builder: (_, best, _) => _IconNumber(
                        icon: const CrownIconPainter(),
                        value: best,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    child: ValueListenableBuilder<int>(
                      valueListenable: progress.coins,
                      builder: (_, coins, _) => _CoinPill(coins: coins),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Nút mua gói bỏ quảng cáo, ẩn khi đã mua vĩnh viễn.
                  ValueListenableBuilder<bool>(
                    valueListenable: progress.noAdsForever,
                    builder: (_, owned, _) => owned
                        ? const SizedBox.shrink()
                        : _NoAdsButton(onTap: onNoAds),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IgnorePointer(child: _LevelPanel(game: game)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton.filled(
                  onPressed: onRestart,
                  tooltip: 'Restart',
                  icon: const Icon(Icons.refresh),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8C1A),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                IgnorePointer(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ValueListenableBuilder<List<int>>(
                      valueListenable: game.nextTiers,
                      builder: (_, tiers, _) => _NextQueue(tiers: tiers),
                    ),
                  ),
                ),
                // Chỉ có ở bản debug: xoá level, coin, best để test lại từ đầu.
                if (kDebugMode)
                  TextButton(
                    onPressed: () {
                      progress.reset();
                      game.restart();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE53935),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Reset',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút vàng nổi khối có icon "bỏ quảng cáo", mở popup mua gói.
class _NoAdsButton extends StatelessWidget {
  const _NoAdsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 50,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE77A), Color(0xFFFFC107)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _brown, width: 3),
          boxShadow: const [BoxShadow(color: _brown, offset: Offset(0, 4))],
        ),
        child: const CustomPaint(painter: NoAdsIconPainter()),
      ),
    );
  }
}

/// Icon nhỏ kèm con số to màu nâu, dùng cho điểm kỷ lục.
class _IconNumber extends StatelessWidget {
  const _IconNumber({required this.icon, required this.value});

  final CustomPainter icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: const Size(28, 24), painter: icon),
        const SizedBox(width: 4),
        Text('$value', style: _numberStyle),
      ],
    );
  }
}

const _numberStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w900,
  color: cartoonBrown,
);

/// Viên hiển thị số coin: nền kem viền nâu, đồng coin ở đầu. Mỗi khi số coin
/// thay đổi thì viên nảy nhẹ để người chơi chú ý.
class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(coins),
      tween: Tween(begin: 1.25, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.centerLeft,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(3, 3, 12, 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3D6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cartoonBrown, width: 2.5),
          boxShadow: const [
            BoxShadow(color: cartoonBrown, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CustomPaint(
              size: Size.square(24),
              painter: CoinIconPainter(),
            ),
            const SizedBox(width: 6),
            Text('$coins', style: _numberStyle.copyWith(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

/// Bảng level ở giữa HUD: "Level N", thanh kinh nghiệm chạy dần tới level kế
/// tiếp và điểm của ván hiện tại.
class _LevelPanel extends StatelessWidget {
  const _LevelPanel({required this.game});

  final FruitFusionGame game;

  @override
  Widget build(BuildContext context) {
    final progress = game.progress;
    return ListenableBuilder(
      listenable: Listenable.merge([progress.level, progress.xp, game.score]),
      builder: (context, _) {
        final level = progress.level.value;
        final ratio = (progress.xp.value / xpForLevel(level)).clamp(0.0, 1.0);
        return Container(
          width: 136,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3D6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cartoonBrown, width: 3),
            boxShadow: const [
              BoxShadow(color: cartoonBrown, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Level $level', style: _numberStyle.copyWith(fontSize: 16)),
              const SizedBox(height: 4),
              // Thanh kinh nghiệm: rãnh nâu, phần đã đạt màu xanh lá.
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF8D5524),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: cartoonBrown, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      widthFactor: ratio,
                      heightFactor: 1,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFA5DD6A), Color(0xFF5DA82E)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                '${game.score.value}',
                style: _numberStyle.copyWith(fontSize: 30, height: 1.2),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Thanh trợ giúp ở đáy màn hình, kèm dòng hướng dẫn khi đang bật búa.
class _PowerUpBar extends StatelessWidget {
  const _PowerUpBar({required this.game, required this.onShop});

  final FruitFusionGame game;

  /// Gọi khi bấm vào trợ giúp đã hết lượt, để mở popup mua thêm.
  final void Function(PowerUp) onShop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: game.hammerArmed,
            builder: (_, armed, _) => Text(
              armed ? 'Tap a fruit to smash it' : '',
              style: _labelStyle,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PowerUpButton(
                game: game,
                onShop: onShop,
                powerUp: PowerUp.hammer,
                icon: const HammerIconPainter(),
                label: 'Hammer',
              ),
              const SizedBox(width: 24),
              _PowerUpButton(
                game: game,
                onShop: onShop,
                powerUp: PowerUp.swap,
                icon: const SwapIconPainter(),
                label: 'Swap',
              ),
              const SizedBox(width: 24),
              _PowerUpButton(
                game: game,
                onShop: onShop,
                powerUp: PowerUp.shake,
                icon: const ShakeIconPainter(),
                label: 'Shake',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nút một trợ giúp kiểu hoạt hình: nút tròn nổi khối có viền nâu dày, số
/// lượt còn lại ở góc và đổi màu khi búa đang bật. Hết lượt thì huy hiệu đổi
/// thành dấu "+" xanh, bấm vào sẽ mở popup mua thêm lượt.
class _PowerUpButton extends StatelessWidget {
  const _PowerUpButton({
    required this.game,
    required this.onShop,
    required this.powerUp,
    required this.icon,
    required this.label,
  });

  final FruitFusionGame game;
  final void Function(PowerUp) onShop;
  final PowerUp powerUp;
  final CustomPainter icon;
  final String label;

  /// Còn lượt thì dùng trợ giúp, hết lượt thì mở popup mua (trừ khi đã thua).
  void _onTap() {
    if (game.isGameOver) return;
    if (game.powerUps[powerUp]!.value > 0) {
      game.usePowerUp(powerUp);
    } else {
      onShop(powerUp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = game.powerUps[powerUp]!;
    return ListenableBuilder(
      listenable: Listenable.merge([count, game.hammerArmed]),
      builder: (context, _) {
        final left = count.value;
        final active = powerUp == PowerUp.hammer && game.hammerArmed.value;
        final base = active ? const Color(0xFF81D4FA) : const Color(0xFFFFE0A3);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: _onTap,
                  child: Container(
                    width: 60,
                    height: 60,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        colors: [Color.lerp(base, Colors.white, 0.5)!, base],
                      ),
                      border: Border.all(color: _brown, width: 3),
                      // Bóng đặc lệch xuống dưới tạo cảm giác nút nổi khối.
                      boxShadow: const [
                        BoxShadow(color: _brown, offset: Offset(0, 4)),
                      ],
                    ),
                    child: CustomPaint(painter: icon),
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -6,
                  child: left > 0
                      ? _Badge(
                          color: const Color(0xFFE53935),
                          child: Text('$left', style: _badgeTextStyle),
                        )
                      : const _Badge(
                          color: Color(0xFF43A047),
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: _labelStyle),
          ],
        );
      },
    );
  }
}

const _badgeTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 12,
  fontWeight: FontWeight.w900,
);

/// Huy hiệu tròn viền trắng ở góc nút trợ giúp: số lượt còn lại (đỏ) hoặc
/// dấu "+" mua thêm (xanh).
class _Badge extends StatelessWidget {
  const _Badge({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [BoxShadow(color: _brown, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }
}

/// Màu chữ combo, nóng dần khi combo tăng: vàng, cam, đỏ, hồng, tím.
const _comboColors = [
  Color(0xFFFFD54F),
  Color(0xFFFFA726),
  Color(0xFFFF7043),
  Color(0xFFE53935),
  Color(0xFFD81B60),
  Color(0xFF8E24AA),
];

/// Chữ combo "x2, x3, x4…" to ở giữa màn hình. Mỗi lần combo tăng thì chữ
/// phồng lên rồi nảy về; hết combo thì mờ dần (vẫn giữ số cuối trong lúc mờ).
class _ComboBanner extends StatefulWidget {
  const _ComboBanner({required this.combo});

  final ValueNotifier<int> combo;

  @override
  State<_ComboBanner> createState() => _ComboBannerState();
}

class _ComboBannerState extends State<_ComboBanner> {
  /// Số combo đang hiển thị, giữ lại cả khi combo đã về 0 để chữ mờ dần.
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    widget.combo.addListener(_onComboChanged);
  }

  @override
  void dispose() {
    widget.combo.removeListener(_onComboChanged);
    super.dispose();
  }

  /// Cập nhật số hiển thị khi combo từ 2 trở lên, và vẽ lại để ẩn/hiện chữ.
  void _onComboChanged() {
    setState(() {
      if (widget.combo.value >= 2) _shown = widget.combo.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.combo.value >= 2;
    final color = _comboColors[(_shown - 2).clamp(0, _comboColors.length - 1)];
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Duration(milliseconds: visible ? 80 : 400),
        child: _shown < 2
            ? const SizedBox.shrink()
            : TweenAnimationBuilder<double>(
                // Đổi key mỗi lần combo tăng để chạy lại hiệu ứng phồng.
                key: ValueKey(_shown),
                tween: Tween(begin: 1.8, end: 1),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Transform.rotate(
                  angle: -0.08,
                  child: OutlinedText('x$_shown', color: color),
                ),
              ),
      ),
    );
  }
}

const _brown = cartoonBrown;

const _labelStyle = TextStyle(
  fontWeight: FontWeight.w700,
  color: Color(0xFF8A6D3B),
);

/// Hiển thị hàng đợi các quả sắp thả: quả kế tiếp to nhất, các quả sau nhỏ
/// dần để người chơi biết thứ tự.
class _NextQueue extends StatelessWidget {
  const _NextQueue({required this.tiers});

  final List<int> tiers;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('NEXT', style: _labelStyle),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < tiers.length; i++)
              Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                child: CustomPaint(
                  size: Size.square(i == 0 ? 40 : 28),
                  painter: _FruitIconPainter(tiers[i]),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FruitIconPainter extends CustomPainter {
  _FruitIconPainter(this.tier);

  final int tier;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2 + 2);
    drawFruit(canvas, tier, size.width * 0.38);
  }

  @override
  bool shouldRepaint(_FruitIconPainter oldDelegate) => oldDelegate.tier != tier;
}

class _GameOverPanel extends StatelessWidget {
  const _GameOverPanel({required this.game, required this.onRestart});

  final FruitFusionGame game;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Game Over',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Score: ${game.score.value}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onRestart,
                child: const Text('Play again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
