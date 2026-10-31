import 'package:flutter/material.dart';

import 'game/fruit_fusion_game.dart';
import 'game/game_feedback.dart';
import 'hud_icons.dart';
import 'outlined_text.dart';
import 'ads.dart';
import 'game/player_progress.dart';
import 'power_up_icons.dart';
import 'purchases.dart';

const _cream = Color(0xFFFFF3D6);
const _purple = Color(0xFF9C6ADE);
const _yellow = Color(0xFFFFD43B);
const _green = Color(0xFF3DBE5C);
const _ink = Color(0xFF3B3355);

/// Tên, icon và mô tả của từng trợ giúp hiển thị trong popup mua.
const _powerUpInfo = {
  PowerUp.hammer: (
    title: 'HAMMER',
    icon: HammerIconPainter(),
    text: 'Smash any fruit to clear it from the jar',
  ),
  PowerUp.swap: (
    title: 'SWAP',
    icon: SwapIconPainter(),
    text: 'Change the fruit you are holding',
  ),
  PowerUp.shake: (
    title: 'SHAKE',
    icon: ShakeIconPainter(),
    text: 'Shake the jar to shuffle all the fruits',
  ),
};

/// Mở popup [dialog] trong lúc tạm dừng game, đóng popup thì chơi tiếp.
Future<void> _showPaused(
  BuildContext context,
  FruitFusionGame game,
  Widget dialog,
) async {
  game.pauseEngine();
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => dialog,
  );
  game.resumeEngine();
}

/// Chiếu quảng cáo từ trong popup: xem đủ thì gọi [onReward] ngay, nhưng chỉ
/// đóng popup (và cho game chạy tiếp) khi quảng cáo đã đóng hẳn, để game không
/// chạy ngầm phía sau quảng cáo. Bỏ ngang quảng cáo thì popup vẫn mở.
/// Người đã mua gói bỏ quảng cáo ([adFree]) thì nhận thưởng ngay, không xem.
void _showAdThenClose(
  BuildContext context,
  GameAds ads,
  VoidCallback onReward, {
  required bool adFree,
}) {
  final navigator = Navigator.of(context);
  if (adFree) {
    onReward();
    navigator.pop();
    return;
  }
  var rewarded = false;
  ads.show(
    onReward: () {
      rewarded = true;
      onReward();
    },
    onClosed: () {
      if (rewarded && navigator.mounted) navigator.pop();
    },
  );
}

/// Popup khi hết lượt trợ giúp [powerUp]: xem quảng cáo nhận 1 lượt, hoặc mua
/// [powerUpPackSize] lượt bằng [powerUpPackPrice] coin.
Future<void> showPowerUpShop(
  BuildContext context, {
  required FruitFusionGame game,
  required GameAds ads,
  required PowerUp powerUp,
}) => _showPaused(
  context,
  game,
  _PowerUpShopDialog(game: game, ads: ads, powerUp: powerUp),
);

/// Popup lên level: nhận số coin đã được cộng, hoặc xem quảng cáo để nhận
/// gấp đôi (cộng thêm một lần nữa).
Future<void> showLevelUpReward(
  BuildContext context, {
  required FruitFusionGame game,
  required GameAds ads,
}) => _showPaused(context, game, _LevelUpDialog(game: game, ads: ads));

/// Popup bán hai gói bỏ quảng cáo: vĩnh viễn và 24 giờ.
Future<void> showNoAdsOffer(
  BuildContext context, {
  required FruitFusionGame game,
  required Purchases purchases,
}) => _showPaused(
  context,
  game,
  _NoAdsDialog(progress: game.progress, purchases: purchases),
);

class _PowerUpShopDialog extends StatelessWidget {
  const _PowerUpShopDialog({
    required this.game,
    required this.ads,
    required this.powerUp,
  });

  final FruitFusionGame game;
  final GameAds ads;
  final PowerUp powerUp;

  /// Chiếu quảng cáo; xem đủ thì cộng 1 lượt và đóng popup.
  void _watchAd(BuildContext context) {
    _showAdThenClose(
      context,
      ads,
      () => game.rewardPowerUp(powerUp),
      adFree: game.progress.isAdFree,
    );
  }

  /// Mua gói trợ giúp bằng coin rồi đóng popup.
  void _buy(BuildContext context) {
    if (game.buyPowerUpPack(powerUp)) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final info = _powerUpInfo[powerUp]!;
    final adsLeft = game.adRewardsLeft[powerUp]!;
    return _CartoonDialog(
      title: info.title,
      onClose: () => Navigator.of(context).pop(),
      children: [
        _IconStage(
          child: CustomPaint(size: const Size.square(130), painter: info.icon),
        ),
        const SizedBox(height: 14),
        Text(
          info.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: _ink,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 18),
        ListenableBuilder(
          listenable: Listenable.merge([
            ads.isReady,
            adsLeft,
            game.progress.coins,
          ]),
          builder: (context, _) {
            final adFree = game.progress.isAdFree;
            final canWatch = (adFree || ads.isReady.value) && adsLeft.value > 0;
            final canBuy = game.progress.coins.value >= powerUpPackPrice;
            return Row(
              children: [
                Expanded(
                  child: _CartoonButton(
                    color: _yellow,
                    onTap: canWatch ? () => _watchAd(context) : null,
                    badge: adFree ? null : const _VideoBadge(),
                    child: const OutlinedText(
                      'Get x1',
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CartoonButton(
                    color: _green,
                    onTap: canBuy ? () => _buy(context) : null,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedText(
                          'Get x$powerUpPackSize',
                          color: Colors.white,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        _CoinPrice(powerUpPackPrice),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        // Giải thích vì sao nút bị mờ để người chơi không bấm mãi không được.
        ListenableBuilder(
          listenable: Listenable.merge([ads.isReady, adsLeft]),
          builder: (context, _) => Text(
            adsLeft.value == 0
                ? 'No more video rewards this game'
                : ads.isReady.value || game.progress.isAdFree
                ? ''
                : 'Video is loading…',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A6D3B),
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelUpDialog extends StatelessWidget {
  const _LevelUpDialog({required this.game, required this.ads});

  final FruitFusionGame game;
  final GameAds ads;

  /// Chiếu quảng cáo; xem đủ thì cộng thêm một lần thưởng (thành gấp đôi) và
  /// đóng popup.
  void _watchAd(BuildContext context, int reward) {
    _showAdThenClose(context, ads, () {
      game.progress.addCoins(reward);
      GameFeedback.reward();
    }, adFree: game.progress.isAdFree);
  }

  @override
  Widget build(BuildContext context) {
    final progress = game.progress;
    final reward = progress.lastLevelUpCoins;
    return _CartoonDialog(
      title: 'LEVEL UP!',
      // Coin thường đã được cộng sẵn, đóng popup là nhận 1x.
      onClose: () => Navigator.of(context).pop(),
      children: [
        _IconStage(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CustomPaint(
                size: Size.square(90),
                painter: CoinIconPainter(),
              ),
              const SizedBox(height: 8),
              OutlinedText(
                '+$reward',
                color: const Color(0xFFFFC83D),
                size: 40,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'You reached Level ${progress.level.value}!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        const SizedBox(height: 18),
        ValueListenableBuilder<bool>(
          valueListenable: ads.isReady,
          builder: (context, ready, _) => Row(
            children: [
              Expanded(
                child: _CartoonButton(
                  color: _green,
                  onTap: () => Navigator.of(context).pop(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const OutlinedText(
                        'Claim',
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      _CoinPrice(reward),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CartoonButton(
                  color: _yellow,
                  onTap: ready || progress.isAdFree
                      ? () => _watchAd(context, reward)
                      : null,
                  badge: progress.isAdFree ? null : const _VideoBadge(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const OutlinedText('Get', color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      _CoinPrice(reward * 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoAdsDialog extends StatelessWidget {
  const _NoAdsDialog({required this.progress, required this.purchases});

  final PlayerProgress progress;
  final Purchases purchases;

  /// Thời gian còn lại của gói 24h, ví dụ "23h 15m left"; rỗng nếu hết hạn.
  String _timeLeft() {
    final until = progress.noAdsUntil.value;
    if (until == null) return '';
    final left = until.difference(DateTime.now());
    if (left.isNegative) return '';
    return '${left.inHours}h ${left.inMinutes % 60}m left';
  }

  @override
  Widget build(BuildContext context) {
    return _CartoonDialog(
      title: 'NO ADS',
      onClose: () => Navigator.of(context).pop(),
      children: [
        const Text(
          'No ads after each game & get video rewards instantly!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _ink,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 14),
        ListenableBuilder(
          listenable: Listenable.merge([
            purchases.products,
            purchases.busy,
            progress.noAdsForever,
            progress.noAdsUntil,
          ]),
          builder: (context, _) {
            final products = purchases.products.value;
            final busy = purchases.busy.value;
            final owned = progress.noAdsForever.value;
            final forever = products[noAdsForeverId];
            final pass = products[noAdsPassId];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _OfferCard(
                    caption: 'Forever',
                    captionColor: const Color(0xFF2F80ED),
                    background: const Color(0xFFFFE2BF),
                    status: owned ? 'Owned' : '',
                    price: owned ? '✓' : forever?.price,
                    onBuy: owned || busy || forever == null
                        ? null
                        : () => purchases.buy(noAdsForeverId),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OfferCard(
                    caption: '24 Hours',
                    captionColor: _purple,
                    background: const Color(0xFFEBDDFB),
                    status: owned ? '' : _timeLeft(),
                    price: pass?.price,
                    // Đã có gói vĩnh viễn thì không cần mua gói 24h nữa.
                    onBuy: owned || busy || pass == null
                        ? null
                        : () => purchases.buy(noAdsPassId),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: Listenable.merge([purchases.error, purchases.products]),
          builder: (context, _) {
            final message =
                purchases.error.value ??
                (purchases.products.value.isEmpty
                    ? 'Store is not available right now'
                    : '');
            return Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFC62828),
              ),
            );
          },
        ),
        TextButton(
          onPressed: purchases.restore,
          style: TextButton.styleFrom(foregroundColor: _ink),
          child: const Text(
            'Restore purchases',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

/// Thẻ một gói bỏ quảng cáo: icon, nhãn thời hạn, danh sách quyền lợi, trạng
/// thái (đã sở hữu / thời gian còn lại) và nút giá. [price] null nghĩa là
/// store chưa trả về giá, khi đó nút bị xám.
class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.caption,
    required this.captionColor,
    required this.background,
    required this.status,
    required this.price,
    required this.onBuy,
  });

  final String caption;
  final Color captionColor;
  final Color background;
  final String status;
  final String? price;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: captionColor.withValues(alpha: 0.5),
          width: 3,
        ),
      ),
      child: Column(
        children: [
          const CustomPaint(size: Size.square(72), painter: NoAdsIconPainter()),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: captionColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cartoonBrown, width: 2),
            ),
            child: Text(
              caption,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const _Benefit('No ads after games'),
          const _Benefit('Instant video rewards'),
          SizedBox(
            height: 22,
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
          _CartoonButton(
            color: _green,
            onTap: onBuy,
            child: OutlinedText(price ?? '—', color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}

/// Một dòng quyền lợi có dấu tích xanh.
class _Benefit extends StatelessWidget {
  const _Benefit(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: _green),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung popup hoạt hình: dải tiêu đề tím chữ trắng viền, thân màu kem viền
/// nâu dày, nút đóng tròn đỏ ở góc trên bên phải.
class _CartoonDialog extends StatelessWidget {
  const _CartoonDialog({
    required this.title,
    required this.onClose,
    required this.children,
  });

  final String title;
  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _cream,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: cartoonBrown, width: 4),
                    boxShadow: const [
                      BoxShadow(color: cartoonBrown, offset: Offset(0, 6)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: const BoxDecoration(
                            color: _purple,
                            border: Border(
                              bottom: BorderSide(color: cartoonBrown, width: 4),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: OutlinedText(
                            title,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: children,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: -14,
                  right: -10,
                  child: _CloseButton(onTap: onClose),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô vuông màu đào có các tia sáng toả ra phía sau, làm nền cho icon lớn.
class _IconStage extends StatelessWidget {
  const _IconStage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 190,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE2BF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF5C99A), width: 3),
      ),
      // Cắt các tia sáng gọn trong ô bo góc.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: CustomPaint(
          painter: const _RaysPainter(),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Các tia sáng trắng mờ toả ra từ tâm.
class _RaysPainter extends CustomPainter {
  const _RaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.longestSide * 0.7;
    final paint = Paint()..color = const Color(0x55FFFFFF);
    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * 3.14159265 / rays;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..arcTo(Rect.fromCircle(center: c, radius: r), a, 0.18, false)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) => false;
}

/// Nút chữ nhật bo góc nổi khối kiểu hoạt hình. [onTap] null thì nút xám đi.
/// [badge] (nếu có) gắn ở góc trên bên trái, ví dụ biểu tượng quảng cáo.
class _CartoonButton extends StatelessWidget {
  const _CartoonButton({
    required this.color,
    required this.onTap,
    required this.child,
    this.badge,
  });

  final Color color;
  final VoidCallback? onTap;
  final Widget child;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final base = enabled ? color : const Color(0xFFBDB6AA);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 76,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(base, Colors.white, 0.35)!, base],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cartoonBrown, width: 3),
              boxShadow: const [
                BoxShadow(color: cartoonBrown, offset: Offset(0, 5)),
              ],
            ),
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          ),
        ),
        if (badge != null) Positioned(top: -16, left: -10, child: badge!),
      ],
    );
  }
}

/// Biểu tượng "xem video": ô tím bo góc có nút play trắng.
class _VideoBadge extends StatelessWidget {
  const _VideoBadge();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.15,
      child: Container(
        width: 40,
        height: 34,
        decoration: BoxDecoration(
          color: _purple,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: cartoonBrown, width: 2.5),
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

/// Đồng coin kèm số lượng, dùng trên các nút mua/nhận coin.
class _CoinPrice extends StatelessWidget {
  const _CoinPrice(this.amount);

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CustomPaint(size: Size.square(30), painter: CoinIconPainter()),
        OutlinedText('$amount', color: Colors.white, size: 18),
      ],
    );
  }
}

/// Nút đóng tròn đỏ có dấu X trắng.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE53935),
          border: Border.all(color: Colors.white, width: 3.5),
          boxShadow: const [
            BoxShadow(color: cartoonBrown, offset: Offset(0, 3)),
          ],
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
      ),
    );
  }
}
