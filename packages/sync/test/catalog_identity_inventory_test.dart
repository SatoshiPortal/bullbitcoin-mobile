import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';
import 'package:sync/inventory.dart';
import 'package:sync/sync.dart';

import '../../secrets/test/support/view_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real admitted inventory projects historical and regtest identities',
    () async {
      final fixture = await ViewFixture.create();
      addTearDown(fixture.close);
      final authority = SessionAuthority();
      final inventory = ok(
        await SecretsInventory.open(
          file: fixture.file,
          admission: fixture.admission,
          authority: authority,
        ),
      );
      addTearDown(inventory.close);
      replaceGrant(authority, 'all');
      const vectors = <(String, Network, String, ScriptType)>[
        (
          'wpkh([aabbccdd/84h/0h/0h])',
          BitcoinNetwork.mainnet,
          'bitcoinMainnet',
          ScriptType.bip84,
        ),
        (
          'sh(wpkh([aabbccdd/49h/1h/0h]))',
          BitcoinNetwork.testnet,
          'bitcoinTestnet',
          ScriptType.bip49,
        ),
        (
          'elwpkh([aabbccdd/84h/1776h/0h])',
          LiquidNetwork.mainnet,
          'liquidMainnet',
          ScriptType.bip84,
        ),
        (
          'elpkh([aabbccdd/44h/1h/0h])',
          LiquidNetwork.testnet,
          'liquidTestnet',
          ScriptType.bip44,
        ),
        (
          'wpkh([aabbccdd/84h/1h/0h]):regtest',
          BitcoinNetwork.regtest,
          'bitcoinRegtest',
          ScriptType.bip84,
        ),
        (
          'elwpkh([aabbccdd/84h/1h/0h]):regtest',
          LiquidNetwork.regtest,
          'liquidRegtest',
          ScriptType.bip84,
        ),
      ];
      const confidential = 'ct(slip77(PRIVACY_PLACEHOLDER),elwpkh(public))';
      for (final (id, network, code, _) in vectors) {
        ok(
          await inventory.registerWallet(
            RegisteredWallet(
              id: id,
              secretFingerprint: null,
              masterFingerprint: '',
              signer: 'none',
              network: code,
              xpub: 'public',
              externalDescriptor: network is LiquidNetwork
                  ? confidential
                  : 'wpkh(public)',
              internalDescriptor: 'wpkh(change)',
              label: null,
              birthday: null,
              isDefault: false,
            ),
          ),
        );
      }
      final catalog = SecretsWalletCatalog.foreground(inventory);
      final list = ok(await catalog.list());
      expect(list, hasLength(6));
      expect(() => list.clear(), throwsUnsupportedError);
      for (final (id, network, _, script) in vectors) {
        final descriptor = ok(
          await catalog.find(WalletKey(id: id, network: network)),
        );
        expect(descriptor.scriptType, script);
        expect(descriptor.origin, id.replaceAll(':regtest', ''));
        if (descriptor case LiquidWalletDescriptor(
          :final combinedCtDescriptor,
        )) {
          expect(combinedCtDescriptor, confidential);
          expect(descriptor.toString(), isNot(contains('PRIVACY_PLACEHOLDER')));
        }
      }
      expect(
        await catalog.find(
          WalletKey(id: vectors.first.$1, network: BitcoinNetwork.signet),
        ),
        isA<Err>(),
      );
    },
  );
}
