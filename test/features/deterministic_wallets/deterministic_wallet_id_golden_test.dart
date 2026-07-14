import 'dart:typed_data';

import 'package:bb_mobile/core/utils/uint_8_list_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mnemonic = bip39.Mnemonic.fromWords(
    words: List.generate(11, (_) => 'zoo') + ['wrong'],
  );

  String masterFingerprint() {
    final seedBytes = Uint8List.fromList(mnemonic.seed);
    return bip32.Bip32Keys.fromSeed(seedBytes).fingerprint.toHexString();
  }

  String walletId(Network network, ScriptType scriptType) {
    return WalletMetadataService.encodeOrigin(
      fingerprint: masterFingerprint(),
      network: network,
      scriptType: scriptType,
    );
  }

  test('fixed mnemonic derives the pinned master fingerprint', () {
    expect(masterFingerprint(), '3f635a63');
  });

  test('network and script type derive append-only wallet ID goldens', () {
    expect(
      walletId(Network.bitcoinMainnet, ScriptType.bip84),
      'wpkh([3f635a63/84h/0h/0h])',
    );
    expect(
      walletId(Network.bitcoinMainnet, ScriptType.bip49),
      'sh(wpkh([3f635a63/49h/0h/0h]))',
    );
    expect(
      walletId(Network.bitcoinMainnet, ScriptType.bip44),
      'pkh([3f635a63/44h/0h/0h])',
    );
    expect(
      walletId(Network.bitcoinTestnet, ScriptType.bip84),
      'wpkh([3f635a63/84h/1h/0h])',
    );
    expect(
      walletId(Network.liquidMainnet, ScriptType.bip84),
      'elwpkh([3f635a63/84h/1776h/0h])',
    );
  });
}
