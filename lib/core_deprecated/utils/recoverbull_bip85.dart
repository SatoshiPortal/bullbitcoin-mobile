import 'dart:math';

import 'package:bip85_entropy/bip85_entropy.dart';
import 'package:hex/hex.dart';

class RecoverbullBip85Utils {
  static final CustomApplication recoverbullApplication =
      CustomApplication.fromNumber(1608);

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
    return formatRecoverBullPath(randomIndex).toString();
  }

  static Bip85HardenedPath formatRecoverBullPath(int index) {
    return Bip85HardenedPath("${recoverbullApplication.number}'/0'/$index'");
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
    final derivation = Bip85Entropy.derive(
      xprvBase58: xprv,
      application: recoverbullApplication,
      path: clearedPath,
    );
    final octets32 = derivation.sublist(0, 32);
    return HEX.encode(octets32);
  }

  static int _getRandomIndex() {
    final random = Random.secure();
    return random.nextInt((1 << 31) - 1);
  }
}
