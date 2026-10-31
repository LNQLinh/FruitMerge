import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'power_up.dart';

const _bestKey = 'best_score';
const _levelKey = 'level';
const _xpKey = 'level_xp';
const _coinsKey = 'coins';
const _noAdsForeverKey = 'no_ads_forever';
const _noAdsUntilKey = 'no_ads_until';

/// Thời hạn của một gói bỏ quảng cáo ngắn hạn.
const noAdsPassDuration = Duration(hours: 24);

/// Số lượt mỗi trợ giúp được tặng một lần duy nhất khi mới cài app.
const startingPowerUps = 1;

/// Key lưu số lượt còn lại của trợ giúp [p].
String _powerUpKey(PowerUp p) => 'powerup_${p.name}';

/// Số coin thưởng mỗi lần lên level.
const coinsPerLevel = 100;

/// Số điểm kinh nghiệm cần để đi từ [level] lên level kế tiếp.
int xpForLevel(int level) => 100 * level;

/// Tiến trình lâu dài của người chơi, lưu trong máy để không mất khi tắt app:
/// điểm cao nhất, level, kinh nghiệm trong level hiện tại và số coin.
/// Kinh nghiệm chính là điểm ghi được, cộng dồn qua mọi ván.
class PlayerProgress {
  PlayerProgress._(this._prefs)
    : best = ValueNotifier(_prefs.getInt(_bestKey) ?? 0),
      level = ValueNotifier(_prefs.getInt(_levelKey) ?? 1),
      xp = ValueNotifier(_prefs.getInt(_xpKey) ?? 0),
      coins = ValueNotifier(_prefs.getInt(_coinsKey) ?? 0),
      noAdsForever = ValueNotifier(_prefs.getBool(_noAdsForeverKey) ?? false),
      noAdsUntil = ValueNotifier(_readTime(_prefs.getInt(_noAdsUntilKey))),
      powerUps = {
        for (final p in PowerUp.values)
          p: ValueNotifier(_prefs.getInt(_powerUpKey(p)) ?? startingPowerUps),
      } {
    // Mỗi khi số lượt trợ giúp thay đổi (dùng, mua, xem quảng cáo) thì lưu
    // ngay, để mở lại app vẫn còn đúng số lượt.
    for (final MapEntry(key: p, value: count) in powerUps.entries) {
      count.addListener(() => _prefs.setInt(_powerUpKey(p), count.value));
    }
  }

  /// Đọc tiến trình đã lưu từ bộ nhớ máy.
  static Future<PlayerProgress> load() async =>
      PlayerProgress._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  final ValueNotifier<int> best;
  final ValueNotifier<int> level;

  /// Kinh nghiệm đã có trong level hiện tại (từ 0 tới [xpForLevel]).
  final ValueNotifier<int> xp;
  final ValueNotifier<int> coins;

  /// Số lượt còn lại của từng trợ giúp.
  final Map<PowerUp, ValueNotifier<int>> powerUps;

  /// Đã mua gói bỏ quảng cáo vĩnh viễn.
  final ValueNotifier<bool> noAdsForever;

  /// Thời điểm hết hạn gói bỏ quảng cáo 24h (null nếu chưa từng mua).
  final ValueNotifier<DateTime?> noAdsUntil;

  static DateTime? _readTime(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);

  /// Đang được miễn quảng cáo: đã mua vĩnh viễn hoặc gói 24h còn hạn.
  bool get isAdFree =>
      noAdsForever.value ||
      (noAdsUntil.value?.isAfter(DateTime.now()) ?? false);

  /// Kích hoạt gói bỏ quảng cáo vĩnh viễn và lưu lại.
  void grantNoAdsForever() {
    noAdsForever.value = true;
    _prefs.setBool(_noAdsForeverKey, true);
  }

  /// Cộng thêm [noAdsPassDuration] miễn quảng cáo. Gói cũ còn hạn thì nối
  /// tiếp vào sau, không bị mất phần thời gian còn lại.
  void grantNoAdsPass({DateTime? now}) {
    now ??= DateTime.now();
    final current = noAdsUntil.value;
    final start = current != null && current.isAfter(now) ? current : now;
    noAdsUntil.value = start.add(noAdsPassDuration);
    _prefs.setInt(_noAdsUntilKey, noAdsUntil.value!.millisecondsSinceEpoch);
  }

  /// Tăng 1 mỗi lần lên level, để giao diện biết mà hiện thông báo.
  final levelUps = ValueNotifier<int>(0);

  /// Số coin đã thưởng ở lần lên level gần nhất (một lần có thể lên nhiều
  /// level), dùng để hiện popup và tính phần thưởng gấp đôi khi xem quảng cáo.
  int lastLevelUpCoins = 0;

  /// Ghi nhận [points] điểm vừa kiếm được trong ván có tổng điểm [score]:
  /// cập nhật kỷ lục, cộng kinh nghiệm, lên level (có thể nhiều level một lúc)
  /// và thưởng coin cho mỗi level, rồi lưu lại.
  void addPoints(int points, {required int score}) {
    if (score > best.value) {
      best.value = score;
      _prefs.setInt(_bestKey, score);
    }
    var newXp = xp.value + points;
    var gained = 0;
    while (newXp >= xpForLevel(level.value)) {
      newXp -= xpForLevel(level.value);
      level.value++;
      gained++;
    }
    xp.value = newXp;
    _prefs.setInt(_xpKey, newXp);
    if (gained > 0) {
      lastLevelUpCoins = gained * coinsPerLevel;
      _prefs.setInt(_levelKey, level.value);
      addCoins(lastLevelUpCoins);
      levelUps.value++;
    }
  }

  /// Xoá toàn bộ tiến trình về như lúc mới cài app (dùng khi dev để test).
  void reset() {
    for (final key in [
      _bestKey,
      _levelKey,
      _xpKey,
      _coinsKey,
      _noAdsForeverKey,
      _noAdsUntilKey,
    ]) {
      _prefs.remove(key);
    }
    noAdsForever.value = false;
    noAdsUntil.value = null;
    best.value = 0;
    level.value = 1;
    xp.value = 0;
    coins.value = 0;
    for (final count in powerUps.values) {
      count.value = startingPowerUps;
    }
  }

  /// Cộng [amount] coin và lưu lại.
  void addCoins(int amount) {
    coins.value += amount;
    _prefs.setInt(_coinsKey, coins.value);
  }

  /// Trừ [amount] coin nếu đủ và lưu lại; không đủ coin thì trả về false.
  bool spendCoins(int amount) {
    if (coins.value < amount) return false;
    addCoins(-amount);
    return true;
  }
}
