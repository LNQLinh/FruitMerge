import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart';

import 'fruit.dart';
import 'fruit_types.dart';
import 'game_feedback.dart';
import 'jar.dart';
import 'merge_effect.dart';
import 'player_progress.dart';
import 'power_up.dart';

export 'power_up.dart';

/// Y position of the fruit waiting to be dropped.
const _previewY = 0.4;

/// Minimum time between two drops.
const _dropCooldown = 0.6;

/// How long a fruit may stay above the danger line before the game ends.
const _overflowGrace = 2.0;

/// Số quả sắp tới được hiển thị ở mục NEXT.
const nextCount = 3;

/// Số lần tối đa được xem quảng cáo để nhận thêm mỗi loại trợ giúp trong
/// một ván (3 loại x 2 = 6 lượt xem mỗi ván).
const _adRewardsPerPowerUp = 2;

/// Thời gian lắc bình và khoảng cách giữa hai lần hất quả.
const _shakeDuration = 1.2;
const _shakeInterval = 0.2;

/// Sau khi lắc xong, chờ thêm chừng này giây cho quả rơi xuống hết rồi mới
/// tính lại việc tràn bình.
const _shakeSettle = 1.5;

/// Giá (coin) và số lượt của một gói trợ giúp mua bằng coin.
const powerUpPackPrice = 225;
const powerUpPackSize = 3;

/// Hai lần gộp cách nhau không quá chừng này giây thì được tính là combo.
const _comboWindow = 1.0;

class FruitFusionGame extends Forge2DGame {
  FruitFusionGame(this.progress) : super(gravity: Vector2(0, 20));

  static const gameOverOverlay = 'gameOver';

  /// Tiến trình lâu dài của người chơi (best, level, coin).
  final PlayerProgress progress;

  final score = ValueNotifier<int>(0);

  /// Hàng đợi các quả sắp thả, phần tử đầu tiên là quả kế tiếp.
  final nextTiers = ValueNotifier<List<int>>(const []);

  /// Số lượt còn lại của từng trợ giúp, lưu lâu dài cùng tiến trình.
  Map<PowerUp, ValueNotifier<int>> get powerUps => progress.powerUps;

  /// Đang bật búa: lần chạm tiếp theo vào bình sẽ đập quả thay vì thả quả.
  final hammerArmed = ValueNotifier<bool>(false);

  /// Số lần còn được xem quảng cáo để nhận thêm từng trợ giúp trong ván này.
  final adRewardsLeft = {
    for (final p in PowerUp.values) p: ValueNotifier<int>(_adRewardsPerPowerUp),
  };

  final _random = math.Random();
  late final _Preview _preview;
  double _cooldown = 0;
  double _overflowTime = 0;
  bool isGameOver = false;
  double _shakeTime = 0;
  double _shakePulse = 0;
  double _shakeDirection = 1;

  /// Tâm camera khi không rung màn hình.
  final _cameraCenter = Vector2(0, 4.3);
  double _quakeTime = 0;
  double _quakeDuration = 0;
  double _quakeStrength = 0;

  /// Số lần gộp liên tiếp trong combo hiện tại (0 khi không có combo).
  final combo = ValueNotifier<int>(0);

  /// Thời gian còn lại để lần gộp tiếp theo được nối vào combo.
  double _comboTime = 0;

  @override
  Color backgroundColor() => const Color(0xFFFFF4E0);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _preview = _Preview(_randomTier());
    nextTiers.value = _randomQueue();
    await world.addAll([Jar(), _preview]);
    await GameFeedback.load();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Fit the jar plus room for the HUD above it and the power-up bar below.
    metersToPixels = math.min(size.x / 6.8, size.y / 13.5);
    camera.viewfinder.position = _cameraCenter;
  }

  int _randomTier() => _random.nextInt(droppableTiers);

  /// Tạo hàng đợi [nextCount] quả ngẫu nhiên mới.
  List<int> _randomQueue() => List.generate(nextCount, (_) => _randomTier());

  /// Moves the waiting fruit horizontally to follow the finger.
  void aimAt(Offset screenPosition) {
    if (isGameOver || hammerArmed.value) return;
    final x = screenToWorld(Vector2(screenPosition.dx, screenPosition.dy)).x;
    final r = fruitTypes[_preview.tier].radius;
    _preview.position.x = x.clamp(-jarHalfWidth + r, jarHalfWidth - r);
  }

  /// Xử lý một lần chạm: đang bật búa thì đập quả tại chỗ chạm, ngược lại
  /// thả quả như bình thường.
  void tapAt(Offset screenPosition) {
    if (hammerArmed.value) {
      _smashAt(screenPosition);
    } else {
      drop();
    }
  }

  /// Thả quả đang chờ xuống bình, rồi lấy quả đầu hàng đợi làm quả chờ mới
  /// và bổ sung một quả ngẫu nhiên vào cuối hàng đợi.
  void drop() {
    if (isGameOver || hammerArmed.value || _cooldown > 0) return;
    world.add(Fruit(_preview.tier, _preview.position.clone()));
    GameFeedback.drop();
    final queue = nextTiers.value;
    _setHeldTier(queue.first);
    nextTiers.value = [...queue.skip(1), _randomTier()];
    _cooldown = _dropCooldown;
  }

  /// Đổi loại quả đang cầm, đồng thời kéo nó vào trong bình nếu quả mới to
  /// hơn và bị lòi ra ngoài thành bình.
  void _setHeldTier(int tier) {
    _preview.tier = tier;
    final r = fruitTypes[tier].radius;
    _preview.position.x = _preview.position.x.clamp(
      -jarHalfWidth + r,
      jarHalfWidth - r,
    );
  }

  /// Dùng trợ giúp [p] nếu còn lượt. Búa chỉ bật/tắt chế độ đập, lượt chỉ bị
  /// trừ khi đập trúng quả, nên bấm lại nút búa là huỷ mà không mất lượt.
  void usePowerUp(PowerUp p) {
    if (isGameOver || powerUps[p]!.value == 0) return;
    switch (p) {
      case PowerUp.hammer:
        hammerArmed.value = !hammerArmed.value;
        return;
      case PowerUp.swap:
        // Chọn ngẫu nhiên một loại khác loại đang cầm.
        var tier = _random.nextInt(droppableTiers - 1);
        if (tier >= _preview.tier) tier++;
        _setHeldTier(tier);
        GameFeedback.swap();
      case PowerUp.shake:
        if (_shakeTime > 0) return;
        _shakeTime = _shakeDuration + _shakeSettle;
        _shakePulse = 0;
        _quake(0.2, _shakeDuration);
        GameFeedback.shake();
    }
    powerUps[p]!.value--;
  }

  /// Mua gói [powerUpPackSize] lượt trợ giúp [p] với giá [powerUpPackPrice]
  /// coin. Trả về false nếu không đủ coin.
  bool buyPowerUpPack(PowerUp p) {
    if (!progress.spendCoins(powerUpPackPrice)) return false;
    powerUps[p]!.value += powerUpPackSize;
    GameFeedback.reward();
    return true;
  }

  /// Thưởng thêm 1 lượt trợ giúp [p] sau khi người chơi xem xong quảng cáo.
  void rewardPowerUp(PowerUp p) {
    final adsLeft = adRewardsLeft[p]!;
    if (adsLeft.value == 0) return;
    adsLeft.value--;
    powerUps[p]!.value++;
    GameFeedback.reward();
  }

  /// Đập vỡ quả nằm dưới điểm chạm (nếu có) và trừ một lượt búa.
  void _smashAt(Offset screenPosition) {
    final point = screenToWorld(Vector2(screenPosition.dx, screenPosition.dy));
    for (final f in world.children.whereType<Fruit>()) {
      if (!f.isMounted || f.merged) continue;
      if (f.body.position.distanceTo(point) > f.radius) continue;
      f.merged = true;
      f.removeFromParent();
      world.add(
        MergeEffect(
          position: f.body.position.clone(),
          color: fruitTypes[f.tier].color,
          radius: f.radius,
        ),
      );
      _quake(0.1, 0.25);
      GameFeedback.smash();
      powerUps[PowerUp.hammer]!.value--;
      hammerArmed.value = false;
      return;
    }
  }

  /// Lắc bình: cứ mỗi [_shakeInterval] giây hất mạnh mọi quả sang trái/phải
  /// xen kẽ, tung cao lên và xoay tít cho quả bay tán loạn. Hết thời gian lắc
  /// thì chỉ chờ quả rơi xuống ([_shakeSettle]).
  void _shake(List<Fruit> fruits, double dt) {
    _shakeTime -= dt;
    _shakePulse -= dt;
    if (_shakeTime <= _shakeSettle || _shakePulse > 0) return;
    _shakePulse = _shakeInterval;
    _shakeDirection = -_shakeDirection;
    for (final f in fruits) {
      final kick = Vector2(
        _shakeDirection * (4 + _random.nextDouble() * 5) +
            (_random.nextDouble() * 4 - 2),
        -(7 + _random.nextDouble() * 7),
      );
      // Nhân với khối lượng để quả to nhỏ đều bị hất với cùng vận tốc.
      f.body.applyLinearImpulse(kick..scale(f.body.mass));
      f.body.angularVelocity = (_random.nextDouble() * 2 - 1) * 12;
    }
  }

  /// Rung màn hình với biên độ [strength] (mét) trong [duration] giây. Nếu
  /// đang rung mạnh hơn thì giữ cú rung đang có.
  void _quake(double strength, double duration) {
    final current = _quakeDuration > 0
        ? _quakeStrength * (_quakeTime / _quakeDuration)
        : 0.0;
    if (strength < current) return;
    _quakeStrength = strength;
    _quakeDuration = duration;
    _quakeTime = duration;
  }

  /// Lệch camera ngẫu nhiên quanh tâm, yếu dần tới khi hết thời gian rung.
  void _updateQuake(double dt) {
    if (_quakeTime <= 0) return;
    _quakeTime -= dt;
    if (_quakeTime <= 0) {
      camera.viewfinder.position = _cameraCenter;
      return;
    }
    final a = _quakeStrength * (_quakeTime / _quakeDuration);
    camera.viewfinder.position =
        _cameraCenter +
        Vector2(
          (_random.nextDouble() * 2 - 1) * a,
          (_random.nextDouble() * 2 - 1) * a,
        );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateQuake(dt);
    if (isGameOver) return;
    _cooldown = math.max(0, _cooldown - dt);
    // Quá thời gian mà không có lần gộp mới thì kết thúc combo.
    if (_comboTime > 0) {
      _comboTime -= dt;
      if (_comboTime <= 0) combo.value = 0;
    }
    _preview.isVisible = _cooldown == 0;

    final fruits = world.children
        .whereType<Fruit>()
        .where((f) => f.isMounted && !f.merged)
        .toList();
    _mergeTouching(fruits);
    if (_shakeTime > 0) {
      // Quả bị hất lên khi lắc không được tính là tràn bình.
      _shake(fruits, dt);
      _overflowTime = 0;
    } else {
      _checkOverflow(fruits, dt);
    }
  }

  void _mergeTouching(List<Fruit> fruits) {
    for (var i = 0; i < fruits.length; i++) {
      final a = fruits[i];
      if (a.merged) continue;
      for (var j = i + 1; j < fruits.length; j++) {
        final b = fruits[j];
        if (b.merged || a.tier != b.tier) continue;
        final touchDistance = a.radius + b.radius + 0.03;
        if (a.body.position.distanceTo(b.body.position) > touchDistance) {
          continue;
        }
        a.merged = true;
        b.merged = true;
        a.removeFromParent();
        b.removeFromParent();

        final mid = (a.body.position + b.body.position)..scale(0.5);
        final next = a.tier + 1;
        if (next < fruitTypes.length) {
          world.add(Fruit(next, mid, popIn: true));
          _addScore(fruitTypes[next].points);
        } else {
          // Two of the biggest fruit clear each other for a bonus.
          _addScore(fruitTypes.last.points * 2);
        }
        _mergeFeedback(math.min(next, fruitTypes.length - 1), mid);
        break;
      }
    }
  }

  /// Hiệu ứng, âm thanh và rung khi gộp ra quả loại [tier] tại [at]. Quả càng
  /// lớn thì hiệu ứng càng to và màn hình rung càng mạnh, càng lâu.
  void _mergeFeedback(int tier, Vector2 at) {
    final type = fruitTypes[tier];
    world.add(
      MergeEffect(position: at.clone(), color: type.color, radius: type.radius),
    );
    _quake(0.03 + 0.015 * tier, 0.12 + 0.025 * tier);
    GameFeedback.merge(tier);
    // Gộp trong lúc combo còn hiệu lực thì tăng combo, không thì bắt đầu lại.
    combo.value = _comboTime > 0 ? combo.value + 1 : 1;
    _comboTime = _comboWindow;
  }

  void _checkOverflow(List<Fruit> fruits, double dt) {
    final overflowing = fruits.any(
      (f) => f.age > 1.5 && f.body.position.y - f.radius < dangerLineY,
    );
    _overflowTime = overflowing ? _overflowTime + dt : 0;
    if (_overflowTime > _overflowGrace) {
      isGameOver = true;
      hammerArmed.value = false;
      _quake(0.15, 0.5);
      combo.value = 0;
      _comboTime = 0;
      GameFeedback.gameOver();
      overlays.add(gameOverOverlay);
    }
  }

  /// Cộng điểm vào ván hiện tại và vào tiến trình (kỷ lục, kinh nghiệm level).
  /// Lên level thì phát âm thanh thưởng.
  void _addScore(int points) {
    score.value += points;
    final level = progress.level.value;
    progress.addPoints(points, score: score.value);
    if (progress.level.value > level) GameFeedback.levelUp();
  }

  void restart() {
    world.children.whereType<Fruit>().toList().forEach(
      (f) => f.removeFromParent(),
    );
    score.value = 0;
    _overflowTime = 0;
    _cooldown = 0;
    _preview.tier = _randomTier();
    nextTiers.value = _randomQueue();
    for (final adsLeft in adRewardsLeft.values) {
      adsLeft.value = _adRewardsPerPowerUp;
    }
    hammerArmed.value = false;
    _shakeTime = 0;
    combo.value = 0;
    _comboTime = 0;
    isGameOver = false;
    overlays.remove(gameOverOverlay);
  }
}

/// The fruit hovering above the jar, waiting to be dropped.
class _Preview extends PositionComponent {
  _Preview(this.tier) : super(position: Vector2(0, _previewY));

  int tier;
  bool isVisible = true;

  @override
  void render(Canvas canvas) {
    if (!isVisible) return;
    // Guide line showing where the fruit will fall.
    canvas.drawLine(
      Offset.zero,
      const Offset(0, jarHeight - _previewY),
      Paint()
        ..strokeWidth = 0.03
        ..color = const Color(0x335C7A99),
    );
    drawFruit(canvas, tier, fruitTypes[tier].radius);
  }
}
