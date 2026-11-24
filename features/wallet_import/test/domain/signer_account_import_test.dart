import 'package:wallet_import/wallet_import.dart';
import 'package:signers/signers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  // Public account fixture already used by watch_only_input_test.dart.
  const xpub =
      'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';
  for (final device in [SignerDevice.ledgerNanoX, SignerDevice.bitbox02]) {
    SignerAccount account(NetworkEnv environment) => SignerAccount(
      masterFingerprint: '86241f88',
      derivationPath: "m/84'/0'/0'",
      xpub: xpub,
      scriptType: ScriptType.bip84,
      device: device,
      network: environment,
    );

    test('${device.name} reports a captured network mismatch', () {
      final result = WatchOnlyInput.fromSignerAccount(
        account(NetworkEnv.testnet),
      );
      expect((result as Err).failure, isA<WatchOnlyNetworkMismatchFailure>());
    });

    test('${device.name} import preserves the captured account', () {
      final signer = account(NetworkEnv.mainnet);
      final result = WatchOnlyInput.fromSignerAccount(signer);
      final wallet = (result as Ok).value as WatchOnlyDescriptorInput;
      expect(wallet.value.descriptor.fingerprint, signer.masterFingerprint);
      expect(wallet.pubkey, xpub);
      expect(wallet.scriptType, signer.scriptType);
      expect(wallet.selectedNetwork, BitcoinNetwork.mainnet);
      expect(wallet.signerDevice, device);
    });
  }
}
