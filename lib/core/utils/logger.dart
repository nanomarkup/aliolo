import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppLogger {
  static File? _logFile;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final alioloDir = Directory(p.join(dir.path, '.aliolo'));
      if (!await alioloDir.exists()) await alioloDir.create(recursive: true);
      _logFile = File(p.join(alioloDir.path, 'debug.log'));

      // Overwrite the file on startup
      await _logFile!.writeAsString(
        '--- App Started at ${DateTime.now()} ---\n',
        mode: FileMode.write,
      );
    } catch (e) {
      print('Failed to initialize logger: $e');
    }
  }

  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] $message\n';
    print(logLine); // Keep terminal output too

    if (!kIsWeb && _logFile != null) {
      try {
        _logFile!.writeAsStringSync(
          logLine,
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {}
    }
  }
}
