import 'dart:io';
export 'dart:io' show Platform, File, Directory, FileMode;

File dynamicFile(String path) => File(path);
Directory dynamicDirectory(String path) => Directory(path);
