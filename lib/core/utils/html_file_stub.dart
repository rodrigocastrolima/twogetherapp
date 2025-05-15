// lib/core/utils/html_file_stub.dart

// This is a stub implementation for dart:io File functionality for web.
// It allows code that uses File (guarded by !kIsWeb) to compile for web,
// even though these methods won't actually be called on web.

class File {
  final String path;

  File(this.path);

  Future<File> writeAsBytes(List<int> bytes, {bool flush = false}) async {
    // This is a stub, it doesn't actually write files on the web side.
    // The real dart:io version is used on mobile.
    print(
      'File stub: writeAsBytes called on web for $path. This should not happen if kIsWeb checks are correct.',
    );
    return this;
  }

  String get absolute => path; // Stub for path property if needed

  Future<bool> exists() async => false; // Stub for exists method

  // Add other stubs for methods/properties of dart:io.File that your mobile code might use
  // within sections that are NOT perfectly guarded by kIsWeb, if they cause compilation errors.
  // For example:
  // Future<DateTime> lastModified() async => DateTime.now();
  // Future<int> length() async => 0;
  // Stream<List<int>> openRead([int? start, int? end]) => Stream.empty();
} 