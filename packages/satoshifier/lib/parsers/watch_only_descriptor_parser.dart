import 'package:satoshifier/satoshifier.dart';

class WatchOnlyDescriptorParser {
  static Future<Satoshifier> parse(String data) async {
    try {
      final descriptor = Descriptor.parse(data);
      return Satoshifier.watchOnlyDescriptor(descriptor: descriptor);
    } catch (_) {}

    throw 'Invalid watch only descriptor';
  }

  static Future<Satoshifier?> tryParse(String data) async {
    try {
      return await parse(data);
    } catch (_) {
      return null;
    }
  }
}
