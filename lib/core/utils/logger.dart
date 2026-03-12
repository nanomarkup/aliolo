import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppLogger {
  static File? _logFile;

  static Future<void> init() async {
    try {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final dir = Directory(p.join(home, '.aliolo'));
        if (!await dir.exists()) await dir.create(recursive: true);
        _logFile = File(p.join(dir.path, 'debug.log'));
        
        // Overwrite the file on startup
        await _logFile!.writeAsString('--- App Started at ${DateTime.now()} ---\n', mode: FileMode.write);
      }
    } catch (e) {
      print('Failed to initialize logger: $e');
    }
  }

  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] $message\n';
    print(logLine); // Keep terminal output too
    
    if (_logFile != null) {
      _logFile!.writeAsStringSync(logLine, mode: FileMode.append, flush: true);
    }
  }
}
