import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/utils/uint_8_list_x.dart';
import 'package:bb_mobile/features/pos/application/ports/merchant_key_provider_port.dart';
import 'package:bb_mobile/features/pos/domain/pos_domain_error.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;

class SeedDerivedMerchantKeyProvider implements MerchantKeyProviderPort {
  const SeedDerivedMerchantKeyProvider({required SeedDatasource seedDatasource})
    : _seedDatasource = seedDatasource;

  static const merchantPath = "m/44'/1237'/0'/0/0";
  static const recoveryPath = "m/44'/1237'/1'/0/0";

  final SeedDatasource _seedDatasource;

  @override
  Future<PosMerchantKeys> derive(String masterFingerprint) async {
    try {
      final seed = await _seedDatasource.get(masterFingerprint);
      final root = Bip32Keys.fromSeed(Uint8List.fromList(seed.bytes));
      final merchantPrivkey = _privateKeyHex(root.derivePath(merchantPath));
      final recoveryPrivkey = _privateKeyHex(root.derivePath(recoveryPath));
      return PosMerchantKeys(
        merchantPrivkey: merchantPrivkey,
        merchantPubkey: nostr.publicKeyFromPrivateKey(merchantPrivkey),
        recoveryPrivkey: recoveryPrivkey,
        recoveryPubkey: nostr.publicKeyFromPrivateKey(recoveryPrivkey),
      );
    } catch (error) {
      throw PosKeyDerivationFailure('$error');
    }
  }

  String _privateKeyHex(Bip32Keys key) {
    final privateKey = key.private;
    if (privateKey == null || privateKey.length != 32) {
      throw const PosKeyDerivationFailure('Missing derived private key.');
    }
    return privateKey.toHexString();
  }
}
