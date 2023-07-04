import 'dart:convert';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/interface.dart';

class WalletDelete {
  Future<Err?> deleteWallet({
    required String saveDir,
    required IStorage storage,
  }) async {
    try {
      final (walletsJsn, err) = await storage.getValue(StorageKeys.wallets);
      if (err != null) throw err;

      final walletsObjs = jsonDecode(walletsJsn!)['wallets'] as List<dynamic>;

      final List<String> fingerprints = [];
      for (final w in walletsObjs) {
        fingerprints.add(w as String);
      }

      fingerprints.remove(saveDir);

      final jsn = jsonEncode({
        'wallets': [...fingerprints]
      });
      final _ = await storage.saveValue(
        key: StorageKeys.wallets,
        value: jsn,
      );

      await storage.deleteValue(saveDir);

      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }
}
