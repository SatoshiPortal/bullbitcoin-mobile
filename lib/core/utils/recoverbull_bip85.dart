import 'dart:math';
import 'dart:typed_data';

import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:hex/hex.dart';

class RecoverbullBip85Utils {
  static final bip85.CustomApplication recoverbullApplication = bip85
      .CustomApplication.fromNumber(1608);

  static int findApplicationNumber(String path) {
    // Old format was using `m/` prefix, which was unnecessarirly added by rust-bip85 before I forked it.
    final trimmed = path.replaceAll("'", "").replaceAll("m/", "");
    return int.parse(trimmed.split('/').first);
  }

  static int findIndex(String path) {
    final trimmed = path.replaceAll("'", "").replaceAll("m/", "");
    return int.parse(trimmed.split('/').last);
  }

  static String generateBackupKeyPath() {
    final randomIndex = _getRandomIndex();
    return formatRecoverBullPath(randomIndex);
  }

  static String formatRecoverBullPath(int index) {
    // /!\ The bip85 path should be finished by a single quote /!\
    // /!\ We keep this typo to ensure encryption keys derived today are still valid with old vaults. /!\
    return "${recoverbullApplication.number}'/0'/$index"; // <--- this should be $index'
  }

  // m/1608'/0'/586053381' -> 0'/586053381
  // 1608'/0'/586053381' -> 0'/586053381
  static String clearPathFromPrefixAndAppNumber(String path) {
    return path
        .replaceAll("m/", "")
        .replaceAll("${recoverbullApplication.number}'/", "");
  }

  static String deriveBackupKey(String xprv, String path) {
    final clearedPath = clearPathFromPrefixAndAppNumber(path);
    final derivation = bip85.Bip85Entropy.derive(
      xprvBase58: xprv,
      application: recoverbullApplication,
      path: clearedPath,
    );
    final octets32 = derivation.sublist(0, 32);
    return HEX.encode(octets32);
  }

  static int _getRandomIndex() {
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
