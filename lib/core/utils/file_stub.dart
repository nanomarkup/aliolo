// File-like stub for web
class File {
  final String path;
  File(this.path);
  Future<bool> exists() async => false;
  bool existsSync() => false;
  Future<String> readAsString() async => '';
  String readAsStringSync() => '';
  Future<void> writeAsString(String content, {dynamic mode, bool flush = false}) async {}
  void writeAsStringSync(String content, {dynamic mode, bool flush = false}) {}
  Future<List<int>> readAsBytes() async => [];
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Directory {
  final String path;
  Directory(this.path);
  Future<bool> exists() async => false;
  bool existsSync() => false;
  Future<void> create({bool recursive = false}) async {}
  Stream<dynamic> list() => const Stream.empty();
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FileMode { 
  static const write = 0; 
  static const append = 1; 
}

class Platform {
  static Map<String, String> get environment => {};
  static String get localeName => 'en_US';
}

dynamic dynamicFile(String path) => File(path);
dynamic dynamicDirectory(String path) => Directory(path);

class LocationStub {
  String get href => '';
  void reload() {}
}

class HistoryStub {
  void replaceState(dynamic data, String title, String? url) {}
}

class MessageEventStub {
  final dynamic data;
  MessageEventStub(this.data);
}

class WindowStub {
  final LocationStub location = LocationStub();
  final HistoryStub history = HistoryStub();
  Stream<MessageEventStub> get onMessage => const Stream.empty();
}

final window = WindowStub();
