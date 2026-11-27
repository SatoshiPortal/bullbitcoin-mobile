import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/metadata_backup.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/src/data/inventory_repository.dart' show recipientKeys;

import 'support/open_inventory.dart';

const _external = "wpkh([01234567/84'/1'/0']tpubMarker/0/*)";
const _internal = "wpkh([01234567/84'/1'/0']tpubMarker/1/*)";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late RuntimeAdmission admission;
  late SecretsInventory inventory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('backup-session-');
    final opened = await openFreshInventory(directory);
    inventory = opened.inventory;
    admission = opened.admission;
  });

  tearDown(() async {
    await inventory.close();
    await admission.close();
    await directory.delete(recursive: true);
  });

  test('a session never survives a lock, even when the view reopens', () async {
    final first = valueOf(await inventory.backupSession());
    valueOf(
      await inventory.registerWallet(
        watchOnlyWallet('wpkh([01234567/84h/1h/0h])'),
      ),
    );
    expect(
      await inventory.matchPublicWallet(
        session: first,
        network: BitcoinNetwork.testnet,
        external: _external,
        internal: _internal,
      ),
      isA<Ok>(),
    );

    await inventory.lock();
    valueOf(await inventory.resumeUnprotected());
    final second = valueOf(await inventory.backupSession());
    expect(second.view, first.view, reason: 'same durable view');
    expect(second.isCurrent, isTrue);
    expect(first.isCurrent, isFalse, reason: 'a new generation');

    for (final result in [
      await inventory.matchPublicWallet(
        session: first,
        network: BitcoinNetwork.testnet,
        external: _external,
        internal: _internal,
      ),
      await inventory.restorePublicWalletProperties(
        session: first,
        network: BitcoinNetwork.testnet,
        external: _external,
        internal: _internal,
        label: 'x',
        birthday: null,
      ),
      await inventory.backupCandidates(first, BitcoinNetwork.testnet),
    ]) {
      expect(result, isA<Err>());
    }
    expect(
      await inventory.backupCandidates(second, BitcoinNetwork.testnet),
      isA<Ok>(),
    );
  });

  test(
    'a registry merge refuses a revoked session and writes nothing',
    () async {
      final parent = Fingerprint('01234567');
      valueOf(await inventory.registerWallet(localWallet('one', parent.hex)));
      final session = valueOf(await inventory.backupSession());
      await inventory.lock();
      valueOf(await inventory.resumeUnprotected());
      final merged = await inventory.mergeDerivationArchive(
        session: session,
        parent: parent,
        records: [
          RecordedDerivation(
            path: "128169'/32'/3'",
            parentFingerprint: parent.hex,
            application: 'hex',
            status: 'active',
            alias: null,
          ),
        ],
      );
      expect(merged, isA<Err>());
      expect(valueOf(await inventory.listDerivations()), isEmpty);
    },
  );

  test('a lock during a merge rolls it back', () async {
    final parent = Fingerprint('01234567');
    valueOf(await inventory.registerWallet(localWallet('one', parent.hex)));
    final session = valueOf(await inventory.backupSession());
    final merge = inventory.mergeDerivationArchive(
      session: session,
      parent: parent,
      records: [
        RecordedDerivation(
          path: "128169'/32'/3'",
          parentFingerprint: parent.hex,
          application: 'hex',
          status: 'active',
          alias: null,
        ),
      ],
    );
    final locking = inventory.lock();
    final result = await merge;
    await locking;
    valueOf(await inventory.resumeUnprotected());
    if (result is Ok) {
      // The merge committed before the lock: its result is the true one.
      expect(valueOf(await inventory.listDerivations()), hasLength(1));
    } else {
      expect(valueOf(await inventory.listDerivations()), isEmpty);
    }
  });

  // Real keys: the BIP138 test vector's tpub and the BIP32 vector's xpub.
  const sharedKey =
      'tpubDC5FSnBiZDMmhiuCmWAYsLwgLYrrT9rAqvTySfuCCrgsWz8wxMXUS9Tb9iVMvcRbvFcAHGkMD5Kx8koh4GquNGNTfohfk7pgjhaPCdXpoba';
  const otherKey =
      'xpub661MyMwAqRbcEYS8w7XLSVeEsBXy79zSzH1J8vCdxAZningWLdN3zgtU6RpmZnd4aqWHHnM5UyKSsvyBgU61Xo1DJ8wYJfuTHfCzDdfJhT4';

  RegisteredWallet account(String id, String key, {String script = 'wpkh'}) =>
      watchOnlyWallet(
        id,
        external: "$script([01234567/84'/1'/0']$key/0/*)",
        internal: "$script([01234567/84'/1'/0']$key/1/*)",
      );

  Future<Map<String, bool>> verdicts(BackupSession session) async => {
    for (final candidate in valueOf(
      await inventory.backupCandidates(session, BitcoinNetwork.testnet),
    ))
      candidate.walletId: candidate.exclusive,
  };

  test('a wallet row visible in two views is not exclusive', () async {
    valueOf(
      await inventory.registerWallet(
        account('wpkh([01234567/84h/1h/0h])', sharedKey),
      ),
    );
    valueOf(
      await inventory.registerWallet(
        account('wpkh([89abcdef/84h/1h/0h])', otherKey),
      ),
    );
    final session = valueOf(await inventory.backupSession());
    expect(await verdicts(session), {
      'wpkh([01234567/84h/1h/0h])': true,
      'wpkh([89abcdef/84h/1h/0h])': true,
    });

    await inventory.shareWalletWithViewForTesting(
      view: 'other',
      walletId: 'wpkh([01234567/84h/1h/0h])',
    );
    expect(await verdicts(session), {
      'wpkh([01234567/84h/1h/0h])': false,
      'wpkh([89abcdef/84h/1h/0h])': true,
    });
  });

  test(
    'two different descriptors sharing a recipient key are neither exclusive',
    () async {
      // Same extended key, another script and another derivation text: the
      // descriptors differ, the BIP138 recipient key does not.
      valueOf(
        await inventory.registerWallet(
          account('wpkh([01234567/84h/1h/0h])', sharedKey),
        ),
      );
      valueOf(
        await inventory.registerWallet(
          account('wpkh([01234567/49h/1h/0h])', sharedKey, script: 'sh(wpkh'),
        ),
      );
      valueOf(
        await inventory.registerWallet(
          account('wpkh([89abcdef/84h/1h/0h])', otherKey),
        ),
      );
      final session = valueOf(await inventory.backupSession());
      expect(await verdicts(session), {
        'wpkh([01234567/84h/1h/0h])': false,
        'wpkh([01234567/49h/1h/0h])': false,
        'wpkh([89abcdef/84h/1h/0h])': true,
      });
      // A checksum on one copy changes nothing.
      expect(
        recipientKeys("wpkh([01234567/84'/1'/0']$sharedKey/0/*)#abcd1234"),
        recipientKeys("wpkh([01234567/84'/1'/0']$sharedKey/0/*)"),
      );
      expect(recipientKeys("wpkh(tprvNotAKey/0/*)"), isEmpty);
    },
  );

  test('a wallet of another view is never returned, nor its descriptors', () async {
    valueOf(
      await inventory.registerWallet(
        account('wpkh([01234567/84h/1h/0h])', sharedKey),
      ),
    );
    // Another view's own wallet, with a key of its own.
    await inventory.insertWalletInViewForTesting(
      view: 'other',
      wallet: account('wpkh([cafebabe/84h/1h/0h])', otherKey),
    );
    final session = valueOf(await inventory.backupSession());
    final candidates = valueOf(
      await inventory.backupCandidates(session, BitcoinNetwork.testnet),
    );
    expect(candidates.map((candidate) => candidate.walletId), [
      'wpkh([01234567/84h/1h/0h])',
    ]);
    expect(candidates.single.exclusive, isTrue);

    // Another view holding the *same key*: the verdict flips, still nothing of
    // that view is named.
    await inventory.insertWalletInViewForTesting(
      view: 'third',
      wallet: account('wpkh([deadbeef/84h/1h/0h])', sharedKey),
    );
    final again = valueOf(
      await inventory.backupCandidates(session, BitcoinNetwork.testnet),
    );
    expect(again.map((candidate) => candidate.walletId), [
      'wpkh([01234567/84h/1h/0h])',
    ]);
    expect(again.single.exclusive, isFalse);
  });

  test('the same recipient key on two networks is not exclusive', () async {
    valueOf(
      await inventory.registerWallet(
        account('wpkh([01234567/84h/1h/0h])', sharedKey),
      ),
    );
    // The same extended key, held by a regtest wallet: the network filters
    // what is returned, never who the holders are.
    valueOf(
      await inventory.registerWallet(
        watchOnlyWallet(
          'wpkh([01234567/84h/1h/0h]):regtest',
          network: 'bitcoinRegtest',
          external: "wpkh([01234567/84'/1'/0']$sharedKey/0/*)",
          internal: "wpkh([01234567/84'/1'/0']$sharedKey/1/*)",
        ),
      ),
    );
    final session = valueOf(await inventory.backupSession());
    expect(await verdicts(session), {'wpkh([01234567/84h/1h/0h])': false});
  });

  test('no verdict is positive when no key could be extracted', () async {
    // Public-looking descriptors with no extended key at all.
    valueOf(
      await inventory.registerWallet(
        watchOnlyWallet(
          'wpkh([01234567/84h/1h/0h])',
          external: "wpkh([01234567/84'/1'/0']tpubMarker/0/*)",
          internal: "wpkh([01234567/84'/1'/0']tpubMarker/1/*)",
        ),
      ),
    );
    // An extended-key-shaped token that does not parse: the failure is not
    // swallowed, it makes the wallet not exclusive.
    final broken = 'tpub${'1' * 107}';
    valueOf(
      await inventory.registerWallet(
        account('wpkh([89abcdef/84h/1h/0h])', broken),
      ),
    );
    // A healthy control.
    valueOf(
      await inventory.registerWallet(
        account('wpkh([cafebabe/84h/1h/0h])', otherKey),
      ),
    );
    final session = valueOf(await inventory.backupSession());
    expect(await verdicts(session), {
      'wpkh([01234567/84h/1h/0h])': false,
      'wpkh([89abcdef/84h/1h/0h])': false,
      'wpkh([cafebabe/84h/1h/0h])': true,
    });
  });
}
