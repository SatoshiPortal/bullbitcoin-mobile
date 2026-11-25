import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/metadata_backup.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';

import 'support/open_inventory.dart';

const _external = "wpkh([01234567/84'/1'/0']tpubMarker/0/*)";
const _internal = "wpkh([01234567/84'/1'/0']tpubMarker/1/*)";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late RuntimeAdmission admission;
  late SecretsInventory inventory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('public-wallet-');
    final opened = await openFreshInventory(directory);
    inventory = opened.inventory;
    admission = opened.admission;
  });

  tearDown(() async {
    await inventory.close();
    await admission.close();
    await directory.delete(recursive: true);
  });

  const id = 'wpkh([01234567/84h/1h/0h])';

  test(
    'the backup projection lists a watch-only wallet by its public descriptors',
    () async {
      valueOf(
        await inventory.registerWallet(
          watchOnlyWallet(id, label: 'Cold', birthday: '2026-11-21T00:00:00Z'),
        ),
      );
      final secrets = Secrets(scratchDirectory: () async => directory.path);
      final wallet = valueOf(await inventory.metadataBackupWallets(secrets))
          .single;
      expect(wallet.isWatchOnly, isTrue);
      expect(wallet.secret, isNull);
      expect(wallet.network, BitcoinNetwork.testnet);
      expect(wallet.scriptType, ScriptType.bip84);
      expect(wallet.label, 'Cold');
      expect(wallet.birthday, DateTime.utc(2026, 11, 21));
      expect(wallet.bitcoinPublicDescriptors, [_external, _internal]);
    },
  );

  test(
    'a match needs the network and both descriptors, never an identifier',
    () async {
      valueOf(await inventory.registerWallet(watchOnlyWallet(id)));
      Future<Result<String, SecretFailure>> match({
        BitcoinNetwork network = BitcoinNetwork.testnet,
        String external = _external,
        String internal = _internal,
      }) => inventory.matchPublicWallet(
        network: network,
        external: external,
        internal: internal,
      );

      expect(valueOf(await match()), id);
      expect(valueOf(await match(external: '$_external#abcd1234')), id);
      // The identifier collides but the public material differs.
      expect(
        (await match(internal: "wpkh([01234567/84'/1'/0']tpubOther/1/*)")),
        isA<Err<String, SecretFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<WalletRegistrationNotFoundFailure>(),
        ),
      );
      expect(
        await match(network: BitcoinNetwork.mainnet),
        isA<Err<String, SecretFailure>>(),
      );
    },
  );

  test('two wallets with the same public material are ambiguous', () async {
    valueOf(await inventory.registerWallet(watchOnlyWallet(id)));
    valueOf(
      await inventory.registerWallet(
        watchOnlyWallet('wpkh([89abcdef/84h/1h/0h])'),
      ),
    );
    final result = await inventory.matchPublicWallet(
      network: BitcoinNetwork.testnet,
      external: _external,
      internal: _internal,
    );
    expect(
      result,
      isA<Err<String, SecretFailure>>().having(
        (error) => error.failure,
        'failure',
        isA<UnreadableWalletFailure>(),
      ),
    );
  });

  test(
    'restoring fills blanks only and never touches signer or default',
    () async {
      valueOf(
        await inventory.registerWallet(
          watchOnlyWallet(id, label: '', birthday: null, isDefault: false),
        ),
      );
      final applied = valueOf(
        await inventory.restorePublicWalletProperties(
          network: BitcoinNetwork.testnet,
          external: _external,
          internal: _internal,
          label: 'From backup',
          birthday: DateTime.utc(2025, 1, 2),
        ),
      );
      expect(applied, (label: true, birthday: true));
      var registration = valueOf(await inventory.readWallet(id));
      expect(registration.label, 'From backup');
      expect(registration.birthday, DateTime.utc(2025, 1, 2));
      expect(registration.isDefault, isFalse);
      expect(registration.signer, WalletSigner.remote);

      final again = valueOf(
        await inventory.restorePublicWalletProperties(
          network: BitcoinNetwork.testnet,
          external: _external,
          internal: _internal,
          label: 'Other',
          birthday: DateTime.utc(2020),
        ),
      );
      expect(again, (label: false, birthday: false));
      registration = valueOf(await inventory.readWallet(id));
      expect(registration.label, 'From backup');
      expect(registration.birthday, DateTime.utc(2025, 1, 2));

      final missing = await inventory.restorePublicWalletProperties(
        network: BitcoinNetwork.testnet,
        external: "wpkh([aaaaaaaa/84'/1'/0']tpubZ/0/*)",
        internal: "wpkh([aaaaaaaa/84'/1'/0']tpubZ/1/*)",
        label: 'x',
        birthday: null,
      );
      expect(missing, isA<Err>());
    },
  );

  test(
    'the view scope is opaque and fails when the inventory is locked',
    () async {
      expect(valueOf(await inventory.backupViewScope()), isNotEmpty);
      inventory.lock();
      expect(await inventory.backupViewScope(), isA<Err>());
    },
  );
}
