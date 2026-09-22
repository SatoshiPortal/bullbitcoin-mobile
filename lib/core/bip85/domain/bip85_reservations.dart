import 'package:bb_mobile/core/utils/recoverbull_bip85.dart';

final class Bip85Reservation {
  final String id;
  final String path;
  final int index;

  const Bip85Reservation({
    required this.id,
    required this.path,
    required this.index,
  });
}

abstract final class Bip85Reservations {
  static const maxIndex = 0x7fffffff;
  static const _wordsPath = "39'/0'/12'/100'";
  static const backupWords = Bip85Reservation(
    id: 'backup_words',
    path: _wordsPath,
    index: 100,
  );
  static const all = [backupWords];
  static const backupEncryptionKeyPath = "128169'/32'/0'";
  static const backupArtifactIdentityPath = "128002'/100'/1'";
  static const backupServerIdentityPath = "128002'/101'/1'";
  static const backupArtifactIdentityChain = [
    _wordsPath,
    backupArtifactIdentityPath,
  ];
  static const backupServerIdentityChain = [
    _wordsPath,
    backupServerIdentityPath,
  ];

  // Retired paths on the original seed must never expose old backup keys.
  static const reservedPaths = {_wordsPath, "128002'/100'/1'", "1642'/0'/1'"};
  static final _recoverBullPrefix =
      "${RecoverbullBip85Utils.recoverbullApplication.number}'/0'/";

  static bool isReservedPath(String path) {
    final normalized = _normalize(path);
    return normalized != null &&
        (reservedPaths.contains(normalized) ||
            normalized.startsWith(_recoverBullPrefix));
  }

  static int nextMnemonicIndex(int index, {required int words}) {
    if (index < 0 || index > maxIndex) {
      throw const FormatException('BIP85 indices exhausted');
    }
    return words == 12 && index == backupWords.index ? index + 1 : index;
  }

  static String? _normalize(String path) {
    var parts = path.trim().split('/');
    if (parts.first == 'm') parts = parts.sublist(1);
    if (parts.isNotEmpty && RegExp(r"^83696968['hH]$").hasMatch(parts.first)) {
      parts = parts.sublist(1);
    }
    if (parts.isEmpty) return null;
    final normalized = <String>[];
    for (final part in parts) {
      final match = RegExp(r"^(\d+)['hH]$").firstMatch(part);
      final index = match == null ? null : int.tryParse(match.group(1)!);
      if (index == null || index < 0 || index > maxIndex) return null;
      normalized.add("$index'");
    }
    return normalized.join('/');
  }
}
