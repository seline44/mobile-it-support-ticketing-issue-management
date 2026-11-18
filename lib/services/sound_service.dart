import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService extends ChangeNotifier {
  static final SoundService instance = SoundService._();
  SoundService._();

  static const String _keySoundEnabled = 'triagedesk_notification_sound_enabled';
  bool _soundEnabled = true;
  AudioPlayer? _player;

  bool get soundEnabled => _soundEnabled;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(_keySoundEnabled) ?? true;
      _player = AudioPlayer();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySoundEnabled, enabled);
    } catch (_) {}
  }

  Future<void> playNotificationSound() async {
    if (!_soundEnabled) return;
    try {
      HapticFeedback.mediumImpact();
      _player ??= AudioPlayer();
      await _player!.stop();
      await _player!.play(AssetSource('sounds/notification.wav'));
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }
}
