import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Watch Only', () {
    test('change only descriptor', () async {
      final watchOnly = await Satoshifier.parse(TestValue.descriptorChangeOnly);
      expect(watchOnly, isA<WatchOnlyDescriptor>());
      final descriptor = (watchOnly as WatchOnlyDescriptor).descriptor;
      expect(descriptor.operand, ScriptOperand.shwpkh);
      expect(descriptor.fingerprint, TestValue.walletMasterFingerprint);
      expect(descriptor.network, Network.bitcoinMainnet);
      expect(descriptor.derivation, Derivation.bip49);
      expect(descriptor.account, 0);

      expect(descriptor.pubkey, TestValue.xpub);
    });

    test('descriptor: bip44', () async {
      final watchOnly = await Satoshifier.parse(TestValue.descriptorP2pkhBip44);
      expect((watchOnly as WatchOnlyDescriptor), isA<WatchOnlyDescriptor>());
      expect(watchOnly.extendedPubkey.pubBase58, TestValue.xpub);
      expect(watchOnly.extendedPubkey.fingerprint, TestValue.xpubFingerprint);
      expect(
        watchOnly.descriptor.fingerprint,
        TestValue.walletMasterFingerprint,
      );
    });

    test('descriptor: bip49', () async {
      final watchOnly = await Satoshifier.parse(TestValue.descriptorP2shBip49);

      expect((watchOnly as WatchOnlyDescriptor), isA<WatchOnlyDescriptor>());
      final extendedPubkey = watchOnly.extendedPubkey;
      expect(extendedPubkey.pubBase58, TestValue.xpub);
      expect(watchOnly.pubkeyFingerprint, TestValue.xpubFingerprint);
      expect(watchOnly.masterFingerprint, TestValue.walletMasterFingerprint);
    });

    test('descriptor: bip84', () async {
      final watchOnly = await Satoshifier.parse(
        TestValue.descriptorP2wpkhBip84,
      );

      expect((watchOnly as WatchOnlyDescriptor), isA<WatchOnlyDescriptor>());
      expect(watchOnly.extendedPubkey.pubBase58, TestValue.xpub);
      expect(watchOnly.pubkeyFingerprint, TestValue.xpubFingerprint);
      expect(watchOnly.masterFingerprint, TestValue.walletMasterFingerprint);
    });
  });
}
