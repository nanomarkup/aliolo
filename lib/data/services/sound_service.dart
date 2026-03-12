import 'dart:io';
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
  String? _correctPath;
  String? _wrongPath;
  String? _completedPath;

  Future<void> init() async {
    if (kIsWeb) return;
    final dir = await getApplicationDocumentsDirectory();
    // Path provider Documents/.aliolo/media
    _correctPath = p.join(dir.path, '.aliolo', 'media', 'correct.mp3');
    _wrongPath = p.join(dir.path, '.aliolo', 'media', 'wrong.mp3');
    _completedPath = p.join(dir.path, '.aliolo', 'media', 'completed.mp3');
  }

  Future<void> playCorrect() async {
    if (kIsWeb) return;
    if ((_authService.currentUser?.soundEnabled ?? true) &&
        _correctPath != null) {
      if (await File(_correctPath!).exists()) {
        await _player.stop();
        await _player.play(DeviceFileSource(_correctPath!));
      }
    }
  }

  Future<void> playWrong() async {
    if (kIsWeb) return;
    if ((_authService.currentUser?.soundEnabled ?? true) &&
        _wrongPath != null) {
      if (await File(_wrongPath!).exists()) {
        await _player.stop();
        await _player.play(DeviceFileSource(_wrongPath!));
      }
    }
  }

  Future<void> playCompleted() async {
    if (kIsWeb) return;
    if ((_authService.currentUser?.soundEnabled ?? true) &&
        _completedPath != null) {
      if (await File(_completedPath!).exists()) {
        await _player.stop();
        await _player.play(DeviceFileSource(_completedPath!));
      }
    }
  }
}
