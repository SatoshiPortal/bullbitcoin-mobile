import 'package:bb_mobile/init.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';

import 'initialization_result.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) {
    requireSuccessfulBullInitialization(await Bull.init());
  }

  test(
    'registers, renames and removes a public wallet in the live inventory',
    () async {
      final inventory = locator<SecretsInventory>();
      final index = DateTime.now().microsecondsSinceEpoch % 0x80000000;
      final origin = '[abcd1234/84h/0h/${index}h]';
      final id = 'wpkh($origin)';
      final wallet = RegisteredWallet(
        id: id,
        secretFingerprint: null,
        masterFingerprint: 'abcd1234',
        signer: 'none',
        network: 'bitcoinMainnet',
        xpub: 'xpub',
        externalDescriptor: 'wpkh(${origin}xpub/0/*)',
        internalDescriptor: 'wpkh(${origin}xpub/1/*)',
        label: 'Watch only',
        birthday: null,
        isDefault: false,
      );
      expect(await inventory.registerWallet(wallet), isA<Ok>());
      addTearDown(() async {
        if (await inventory.findWallet(id) case Ok(value: final value?)
            when value.id == id) {
          expect(await inventory.removeWallet(id), isA<Ok>());
        }
      });
      expect(
        await inventory.findWallet(id),
        isA<Ok<RegisteredWallet?, Failure>>().having(
          (result) => result.value?.label,
          'label',
          'Watch only',
        ),
      );
      expect(
        await inventory.setWalletProperties(
          id: id,
          label: 'Renamed',
          birthday: DateTime.utc(2023, 1, 1),
          isDefault: false,
        ),
        isA<Ok>(),
      );
      expect(
        await inventory.findWallet(id),
        isA<Ok<RegisteredWallet?, Failure>>().having(
          (result) => result.value?.label,
          'label',
          'Renamed',
        ),
      );
      expect(await inventory.removeWallet(id), isA<Ok>());
      expect(
        await inventory.findWallet(id),
        isA<Ok<RegisteredWallet?, Failure>>().having(
          (result) => result.value,
          'removed wallet',
          isNull,
        ),
      );
    },
  );
}
