import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

/// The cohort whose secrets are not there any more, and what they must be told.
///
/// Android installs from 6.5.2 kept their secrets in Jetpack Security's EncryptedSharedPreferences, read through the `flutter_secure_storage` 9 plugin. That plugin is gone and there is **no fallback** — the decision of 2026-09-15. So the guarantee is not that those entries can be read; it is that the app can tell the difference between "your seed is gone, import your backup" and everything else, and never offers a restore to a user whose seed is intact.
///
/// The two shapes this actually takes on a device, and the failure each must produce.
void main() {
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];
  const fingerprint = '73c5da0a';

  /// A value as the fss9 plugin wrote it: an fss10 read either does not see
  /// the entry at all, or hands back the stored bytes, which are not this
  /// package's JSON. Base64 of an AES-GCM blob, shaped like the real thing.
  const fss9Value =
      'AXKQkVYRs0w4nNFCwvDlKQyDU3sJbHZ5bU5pZ0FBQUFBQUFBQUFBQUFBQUFB'
      'QUFBQUFBQUFBQUFBQUFBQUFBPT0=';

  Secrets secretsWith(FakeSecureStoragePlatform storage) {
    storage.install();
    return Secrets(scratchDirectory: () async => '/tmp');
  }

  group('the entries are invisible — the common case', () {
    test('listing is empty, and is not a failure', () async {
      // What the wallet list is drawn from. An empty `Ok` is "you have no
      // secrets", which is true and actionable; an `Err` here would render
      // "something went wrong" over a user who needs to be told to restore.
      final secrets = secretsWith(FakeSecureStoragePlatform());

      expect(ok(await secrets.list()), isEmpty);
    });

    test('a wallet metadata still points at a fingerprint: not found', () async {
      // The SQLite metadata survived the plugin change, so the app asks for a
      // secret that is no longer there. Not-found is the one failure that
      // means "import your backup" — and it costs the full retry budget
      // first, because the signal that says "absent" is the untrustworthy one.
      final storage = FakeSecureStoragePlatform();
      final secrets = secretsWith(storage);

      expect(
        err(await secrets.fetch(Fingerprint(fingerprint))),
        isA<SecretNotFoundFailure>(),
      );
      expect(storage.reads, 5, reason: 'concluded only after the full budget');
    });
  });

  group('the entries are visible but unreadable', () {
    test('listing steps over them rather than failing', () async {
      // One fss9 value under this package's own prefix. It is not JSON, so it
      // cannot be a secret — and it must not cost the user sight of the
      // wallets that are still intact.
      final storage = FakeSecureStoragePlatform(
        entries: {
          'seed_$fingerprint': fss9Value,
          'seed_deadbeef': jsonEncode({
            'mnemonicWords': words,
            'passphrase': null,
            'runtimeType': 'mnemonic',
          }),
        },
      );
      final secrets = secretsWith(storage);

      final listed = ok(await secrets.list());

      expect(listed, hasLength(1));
      expect(listed.single.id.hex, 'deadbeef');
    });

    test('asking for one is a read failure, never an absence', () async {
      // The distinction that decides whether the app offers to replace a
      // seed. An unreadable value might still be recoverable — a plugin
      // regression, a bad migration — so it must never read as "gone".
      final secrets = secretsWith(
        FakeSecureStoragePlatform(entries: {'seed_$fingerprint': fss9Value}),
      );

      final failure = err(await secrets.fetch(Fingerprint(fingerprint)));

      expect(failure, isA<SecretFetchFailure>());
      expect(failure, isNot(isA<SecretNotFoundFailure>()));
    });

    test('nothing is written over them', () async {
      // The cohort's only path back is a backup, so the bytes stay exactly as
      // they are: if the plugin ever reads them again, they are still there.
      final storage = FakeSecureStoragePlatform(
        entries: {'seed_$fingerprint': fss9Value},
      );
      final secrets = secretsWith(storage);

      await secrets.fetch(Fingerprint(fingerprint));
      await secrets.list();

      expect(storage.entries['seed_$fingerprint'], fss9Value);
    });
  });

  test('a restore from a backup puts the cohort back where it was', () async {
    // The whole point of the path. The words come from the user's vault, not
    // from the old entry, and the wallet lands under the same identity — so
    // the metadata that survived still joins.
    final storage = FakeSecureStoragePlatform(
      entries: {'seed_$fingerprint': fss9Value},
    );
    final secrets = secretsWith(storage);

    // An unreadable entry under the very key the import will use: the write
    // must refuse rather than destroy what might still be recoverable.
    expect(
      err(await secrets.import(words: words)),
      isA<SecretStoreFailure>(),
      reason: 'a foreign value under that key is never overwritten',
    );
    expect(storage.entries['seed_$fingerprint'], fss9Value);

    // On a clean device — the reinstall the cohort was told to do — the same
    // words restore the same wallet.
    final fresh = secretsWith(FakeSecureStoragePlatform());
    expect(ok(await fresh.import(words: words)).id.hex, fingerprint);
  });
}
