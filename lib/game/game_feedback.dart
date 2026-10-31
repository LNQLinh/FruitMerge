import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'fruit_types.dart';

/// Âm thanh và rung phản hồi của game. File âm thanh nằm trong assets/audio/.
class GameFeedback {
  /// Thiết lập phiên âm thanh và nạp sẵn mọi file để phát không bị trễ.
  /// Lỗi âm thanh chỉ được ghi log, không làm hỏng game.
  static Future<void> load() async {
    try {
      await _load();
    } catch (e) {
      debugPrint('Could not load sounds: $e');
    }
  }

  static Future<void> _load() async {
    // Âm thanh game: tôn trọng nút gạt im lặng trên iOS và không làm dừng
    // nhạc đang phát từ app khác.
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );
    await FlameAudio.audioCache.loadAll([
      for (var i = 0; i < fruitTypes.length; i++) 'merge_$i.wav',
      'drop.wav',
      'smash.wav',
      'swap.wav',
      'shake.wav',
      'game_over.wav',
      'reward.wav',
    ]);
  }

  /// Phát một file âm thanh ngắn, không chờ phát xong; lỗi thì bỏ qua.
  static void _play(String name, {double volume = 1}) {
    FlameAudio.play('$name.wav', volume: volume).ignore();
  }

  /// Gộp quả thành loại [tier]: âm thanh trầm dần và rung mạnh dần theo độ
  /// lớn của quả.
  static void merge(int tier) {
    _play('merge_$tier', volume: 0.8);
    if (tier >= 8) {
      HapticFeedback.heavyImpact();
    } else if (tier >= 4) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  static void drop() => _play('drop', volume: 0.5);

  static void smash() {
    _play('smash');
    HapticFeedback.heavyImpact();
  }

  static void swap() {
    _play('swap', volume: 0.7);
    HapticFeedback.selectionClick();
  }

  static void shake() {
    _play('shake', volume: 0.8);
    HapticFeedback.mediumImpact();
  }

  static void gameOver() {
    _play('game_over', volume: 0.8);
    HapticFeedback.heavyImpact();
  }

  static void reward() => _play('reward', volume: 0.7);

  static void levelUp() {
    _play('reward');
    HapticFeedback.mediumImpact();
  }
}
