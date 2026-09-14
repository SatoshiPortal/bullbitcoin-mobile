import 'dart:math';

import 'package:bb_mobile/core/nostr/nostr_relay_datasource.dart';
import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/recoverbull_encryption.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_parser.dart';
import 'package:bb_mobile/features/bullvault/data/nostr_descriptor_relays.dart';
import 'package:bb_mobile/features/bullvault/data/nostr_descriptor_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/nostr_descriptor_backup.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';

import 'support/bip138_prototype_fixture.dart';

/// Publishes one disposable vault descriptor to the real configured relays and
/// reads it back words-only, the way an heir would.
///
/// It writes to public infrastructure, so it is off unless asked for:
///
///     fvm flutter test --dart-define=BULL_NOSTR_RELAY_PUBLISH=true \
///       test/features/bullvault/nostr_descriptor_relay_test.dart
///
/// This is the one approved public write. The author key is generated for the
/// run and thrown away with it, and the descriptor is the repository's public
/// testnet fixture, which has never held coins. Nothing here belongs to a real
/// wallet, and no relay sees anything but ciphertext under a fresh key.
void main() {
  const enabled = bool.fromEnvironment('BULL_NOSTR_RELAY_PUBLISH');

  test(
    'a disposable descriptor survives a round trip through real relays',
    () async {
      // A fresh identity per run, so nothing accumulates under one author key.
      final random = Random.secure();
      final entropy = List.generate(16, (_) => random.nextInt(256));
      final words = bip39.Mnemonic(entropy, bip39.Language.english).sentence;
      final descriptor = Bip138PrototypeFixture().descriptor();
      final canonical = DescriptorBackupParser.parseDescriptor(
        descriptor,
      ).descriptor;
      final repository = NostrDescriptorRepository(
        const RecoverBullEncryption(),
        const NostrRelayDatasource(),
      );

      final event = await repository.seal(
        credential: BackupCredential.fromWords(words),
        descriptor: descriptor,
        network: Network.bitcoinTestnet,
      );
      final publication = await repository.publish(event, NostrSession());
      for (final relay in NostrDescriptorRelays.configured) {
        // ignore: avoid_print
        print('publish $relay: ${publication.outcomes[relay]?.name}');
      }
      expect(
        publication.outcomes.values,
        contains(NostrRelayOutcome.accepted),
        reason: 'no configured relay accepted the event',
      );

      // A holder of the words alone, with no seed and no local state.
      final search = await repository.discover(
        credential: BackupCredential.fromWords(words),
        session: NostrSession(),
      );
      // ignore: avoid_print
      print(
        'read back ${search.descriptors.length} descriptor(s), '
        'incomplete=${search.incomplete}',
      );
      expect(
        search.descriptors.map((found) => found.descriptor),
        contains(canonical),
      );
      expect(search.descriptors.single.network, Network.bitcoinTestnet);
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: enabled
        ? null
        : 'Opt in with --dart-define=BULL_NOSTR_RELAY_PUBLISH=true: it '
              'publishes to public relays.',
  );
}
