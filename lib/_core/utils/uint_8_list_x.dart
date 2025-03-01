import 'dart:typed_data';

extension Uint8ListX on Uint8List {
  String toHexString() {
    return map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
