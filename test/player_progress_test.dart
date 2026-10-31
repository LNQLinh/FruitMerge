import 'package:flutter_test/flutter_test.dart';
import 'package:fruit_fusion/game/player_progress.dart';
import 'package:fruit_fusion/game/power_up.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('starts at level 1 with nothing saved', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await PlayerProgress.load();
    expect(p.level.value, 1);
    expect(p.xp.value, 0);
    expect(p.coins.value, 0);
    expect(p.best.value, 0);
  });

  test('levels up and grants coins, carrying leftover xp', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await PlayerProgress.load();
    p.addPoints(60, score: 60);
    expect(p.level.value, 1);
    expect(p.xp.value, 60);

    // 60 + 50 = 110: crosses the 100 needed for level 1, 10 carried over.
    p.addPoints(50, score: 110);
    expect(p.level.value, 2);
    expect(p.xp.value, 10);
    expect(p.coins.value, coinsPerLevel);
    expect(p.levelUps.value, 1);
  });

  test('a big gain can skip several levels at once', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await PlayerProgress.load();
    // Level 1 needs 100, level 2 needs 200, level 3 needs 300: 600 in total.
    p.addPoints(650, score: 650);
    expect(p.level.value, 4);
    expect(p.xp.value, 50);
    expect(p.coins.value, 3 * coinsPerLevel);
  });

  test('progress survives an app restart', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await PlayerProgress.load();
    p.addPoints(150, score: 150);

    final reopened = await PlayerProgress.load();
    expect(reopened.level.value, 2);
    expect(reopened.xp.value, 50);
    expect(reopened.coins.value, coinsPerLevel);
    expect(reopened.best.value, 150);
  });

  test('best only goes up', () async {
    SharedPreferences.setMockInitialValues({'best_score': 500});
    final p = await PlayerProgress.load();
    p.addPoints(10, score: 10);
    expect(p.best.value, 500);
  });

  test(
    'spending coins fails without enough and saves when it succeeds',
    () async {
      SharedPreferences.setMockInitialValues({'coins': 300});
      final p = await PlayerProgress.load();
      expect(p.spendCoins(225), isTrue);
      expect(p.coins.value, 75);
      expect(p.spendCoins(225), isFalse);
      expect(p.coins.value, 75);
      p.addCoins(100);
      expect((await PlayerProgress.load()).coins.value, 175);
    },
  );

  test('remembers how many coins the last level-up gave', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await PlayerProgress.load();
    p.addPoints(650, score: 650);
    expect(p.lastLevelUpCoins, 3 * coinsPerLevel);
  });

  test('reset goes back to a fresh install, also after reopening', () async {
    SharedPreferences.setMockInitialValues({
      'best_score': 900,
      'level': 7,
      'level_xp': 120,
      'coins': 450,
    });
    final p = await PlayerProgress.load();
    p.reset();
    expect(p.level.value, 1);
    expect(p.xp.value, 0);
    expect(p.coins.value, 0);
    expect(p.best.value, 0);

    final reopened = await PlayerProgress.load();
    expect(reopened.level.value, 1);
    expect(reopened.coins.value, 0);
    expect(reopened.best.value, 0);
  });

  test('power-ups start at 1 each and are saved when they change', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await PlayerProgress.load();
    for (final count in p.powerUps.values) {
      expect(count.value, startingPowerUps);
    }
    p.powerUps[PowerUp.hammer]!.value = 0;
    p.powerUps[PowerUp.swap]!.value += 3;

    final reopened = await PlayerProgress.load();
    expect(reopened.powerUps[PowerUp.hammer]!.value, 0);
    expect(reopened.powerUps[PowerUp.swap]!.value, 4);
    expect(reopened.powerUps[PowerUp.shake]!.value, 1);

    reopened.reset();
    expect((await PlayerProgress.load()).powerUps[PowerUp.hammer]!.value, 1);
  });

  test('no-ads: forever and 24h pass, saved across restarts', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await PlayerProgress.load();
    expect(p.isAdFree, isFalse);

    p.grantNoAdsPass();
    expect(p.isAdFree, isTrue);
    final reopened = await PlayerProgress.load();
    expect(reopened.isAdFree, isTrue);
    expect(reopened.noAdsForever.value, isFalse);

    reopened.grantNoAdsForever();
    expect((await PlayerProgress.load()).noAdsForever.value, isTrue);
  });

  test(
    'a second 24h pass extends the time left instead of replacing it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final p = await PlayerProgress.load();
      final now = DateTime(2026, 1, 1, 12);
      p.grantNoAdsPass(now: now);
      p.grantNoAdsPass(now: now.add(const Duration(hours: 5)));
      expect(p.noAdsUntil.value, now.add(const Duration(hours: 48)));
    },
  );

  test('an expired 24h pass no longer removes ads', () async {
    final past = DateTime.now().subtract(const Duration(hours: 1));
    SharedPreferences.setMockInitialValues({
      'no_ads_until': past.millisecondsSinceEpoch,
    });
    final p = await PlayerProgress.load();
    expect(p.isAdFree, isFalse);
  });
}
