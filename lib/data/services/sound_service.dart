import 'package:aliolo/core/utils/io_utils.dart' if (dart.library.html) 'package:aliolo/core/utils/file_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'auth_service.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  final _authService = AuthService();

  // Desktop paths
  String? _correctPath;
  String? _wrongPath;
  String? _completedPath;
  String? _greatPath;
  String? _goodPath;

  // Asset paths (Web & Fallback)
  static const String assetCorrect = 'media/correct.mp3';
  static const String assetWrong = 'media/wrong.mp3';
  static const String assetCompleted = 'media/completed.mp3';
  static const String assetGreat = 'media/completed.mp3'; // Placeholder
  static const String assetGood = 'media/completed.mp3'; // Placeholder

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _correctPath = p.join(dir.path, '.aliolo', 'media', 'correct.mp3');
      _wrongPath = p.join(dir.path, '.aliolo', 'media', 'wrong.mp3');
      _completedPath = p.join(dir.path, '.aliolo', 'media', 'completed.mp3');
      _greatPath = p.join(dir.path, '.aliolo', 'media', 'great.mp3');
      _goodPath = p.join(dir.path, '.aliolo', 'media', 'good.mp3');
    } catch (e) {
      debugPrint('SoundService init error: $e');
    }
  }

  Future<void> _playSound(String assetPath, String? devicePath) async {
    if (!(_authService.currentUser?.soundEnabled ?? true)) return;

    try {
      Source source;
      if (kIsWeb) {
        source = AssetSource(assetPath);
      } else {
        if (devicePath != null && await dynamicFile(devicePath).exists()) {
          source = DeviceFileSource(devicePath);
        } else {
          source = AssetSource(assetPath);
        }
      }

      await _player.stop();
      await _player.play(source);
    } catch (e) {
      debugPrint('Error playing sound $assetPath: $e');
    }
  }

  Future<void> playCorrect() async {
    await _playSound(assetCorrect, _correctPath);
  }

  Future<void> playWrong() async {
    await _playSound(assetWrong, _wrongPath);
  }

  Future<void> playCompleted() async {
    await _playSound(assetCompleted, _completedPath);
  }

  Future<void> playGreat() async {
    await _playSound(assetGreat, _greatPath);
  }

  Future<void> playGood() async {
    await _playSound(assetGood, _goodPath);
  }
}
