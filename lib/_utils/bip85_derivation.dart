import 'dart:math';
import 'dart:typed_data';

import 'package:bip85/bip85.dart' as bip85;

class Bip85Derivation {
  static List<int> derive(String xprv, String path) {
    final backupKey = bip85.derive(xprv: xprv, path: path);
    return backupKey;
  }

  static String generateBackupKeyPath() {
    final randomIndex = _randomIndex();
    return "m/1608'/0'/$randomIndex";
  }

  static int _randomIndex() {
    final random = Uint8List(4);
    final secureRandom = Random.secure();
    for (int i = 0; i < 4; i++) {
      random[i] = secureRandom.nextInt(256);
    }
    final randomIndex =
        ByteData.view(random.buffer).getUint32(0, Endian.little) & 0x7FFFFFFF;

    return randomIndex;
  }
}
