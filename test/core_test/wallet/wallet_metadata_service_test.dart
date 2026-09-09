import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("decodes h and apostrophe hardened origin notation", () {
    const expected = (
      fingerprint: '0f36572d',
      network: Network.bitcoinTestnet,
      script: ScriptType.bip84,
      account: '0h',
    );

    expect(
      WalletMetadataService.decodeOrigin(origin: 'wpkh([0f36572d/84h/1h/0h])'),
      expected,
    );
    expect(
      WalletMetadataService.decodeOrigin(origin: "wpkh([0f36572d/84'/1'/0'])"),
      expected,
    );
  });

  test(
    'records the standard descriptor path for a Bitcoin seed wallet',
    () async {
      final wallet = await WalletMetadataService.deriveFromSeed(
        seed: Seed.bytes(
          bytes: Uint8List.fromList(
            List<int>.generate(32, (index) => index + 1),
          ),
          masterFingerprint: '01020304',
        ),
        network: Network.bitcoinTestnet,
        scriptType: ScriptType.bip84,
        isDefault: false,
      );

      expect(
        wallet.signers.single.descriptorKeys.single.descriptorPath,
        standardSingleSignatureDescriptorPath,
      );
    },
  );
}
