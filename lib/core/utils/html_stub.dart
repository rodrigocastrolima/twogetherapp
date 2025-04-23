// Stub file for dart:html when not running on web.
// This prevents compilation errors on non-web platforms.

// You might need to add dummy classes/methods here if the code
// tries to access specific properties even after kIsWeb checks
// (though ideally kIsWeb prevents this).

// For now, an empty file might suffice if kIsWeb guards are robust.

// Define a minimal stub for the 'window' object to satisfy the analyzer.
// The actual methods won't be called on non-web platforms due to kIsWeb checks.

final WindowStub window = WindowStub();

class WindowStub {
  // Add dummy properties/methods for anything accessed via html.window
  // For now, just providing something basic.
  SessionStorageStub get sessionStorage => SessionStorageStub();
  LocationStub get location => LocationStub();
  HistoryStub get history => HistoryStub();
}

class SessionStorageStub {
  String? operator [](String key) => null; // Dummy implementation
  void operator []=(String key, String value) {} // Dummy implementation
  void remove(String key) {} // Dummy implementation
}

class LocationStub {
  set href(String? value) {} // Dummy implementation
}

class HistoryStub {
  void replaceState(
    dynamic data,
    String title,
    String? url,
  ) {} // Dummy implementation
}
