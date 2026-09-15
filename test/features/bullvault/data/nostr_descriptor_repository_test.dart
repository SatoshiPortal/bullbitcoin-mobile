import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/nostr/nostr_relay_datasource.dart';
import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/recoverbull_encryption.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_artifact_codec.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_parser.dart';
import 'package:bb_mobile/features/bullvault/data/nostr_descriptor_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/nostr_descriptor_backup.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart' as nostr;

import '../support/bullvault_descriptor_fixture.dart';
import '../support/fake_nostr_relay.dart';

/// The frozen public vectors: the words a synthetic seed derives, and a second
/// unrelated set. Neither holds funds.
const _words =
    'abandon differ wave love claim impact beach put bunker polar fragile crop';
const _otherWords =
    'smoke merit develop rug defy when swallow pink raven negative twin glass';

void main() {
  final fixture = BullVaultDescriptorFixture();
  final descriptor = fixture.descriptor();
  final canonical = DescriptorBackupParser.parseDescriptor(
    descriptor,
  ).descriptor;
  final credential = BackupCredential.fromWords(_words);
  final stranger = BackupCredential.fromWords(_otherWords);

  late List<FakeNostrRelay> relays;
  late NostrDescriptorRepository repository;

  NostrDescriptorRepository repositoryOver(
    List<FakeNostrRelay> network, {
    DateTime? now,
  }) => NostrDescriptorRepository(
    const RecoverBullEncryption(),
    NostrRelayDatasource(
      connect: fakeRelayNetwork(network),
      timeout: const Duration(milliseconds: 500),
    ),
    relays: network.map((relay) => relay.uri).toList(),
    now: () => now ?? DateTime.utc(2027, 3, 4, 5, 6, 7),
  );

  setUp(() {
    relays = [
      FakeNostrRelay('wss://one.example'),
      FakeNostrRelay('wss://two.example'),
    ];
    repository = repositoryOver(relays);
  });

  Future<nostr.Event> sealed({String? source, Network? network}) =>
      repository.seal(
        credential: credential,
        descriptor: source ?? descriptor,
        network: network ?? Network.bitcoinTestnet,
      );

  test(
    'the event shows a relay nothing but a purpose tag and ciphertext',
    () async {
      final event = await sealed();

      expect(event.kind, 1089);
      expect(event.tags, [
        ['t', DescriptorArtifact.profile],
      ]);
      expect(event.pubkey, credential.nostrPublicKeyHex);
      expect(event.isValid(), isTrue);
      // Everything a relay can read, apart from the ciphertext itself.
      final envelope = jsonEncode(event.toMap()..remove('content'));
      for (final secret in [
        descriptor,
        canonical,
        'tpub',
        'testnet',
        for (final signer in fixture.signers) signer.accountKey.xpub,
        for (final signer in fixture.signers)
          signer.accountKey.masterFingerprint,
      ]) {
        expect(envelope, isNot(contains(secret)), reason: secret);
      }
      // The content is the sealed frame, not the frame.
      final ciphertext = base64Decode(event.content);
      expect(
        utf8.decode(ciphertext, allowMalformed: true),
        isNot(contains('tpub')),
      );
      expect(
        DescriptorArtifact.decode(
          await const RecoverBullEncryption().decrypt(
            Uint8List.fromList(hex.decode(credential.encryptionKeyHex)),
            ciphertext,
          ),
        ).descriptor,
        descriptor,
      );
    },
  );

  test('two sealings of one descriptor are two different events', () async {
    expect((await sealed()).id, isNot((await sealed()).id));
  });

  test(
    'a publication reaches every relay and each answers for itself',
    () async {
      relays[1].rejects = true;
      final publication = await repository.publish(
        await sealed(),
        NostrSession(),
      );

      expect(publication.outcomes, {
        relays[0].uri: NostrRelayOutcome.accepted,
        relays[1].uri: NostrRelayOutcome.rejected,
      });
      expect(publication.accepted, isTrue);
      expect(relays[0].events, hasLength(1));
      expect(relays[1].events, isEmpty);
      expect(relays[1].publications, 1, reason: 'the refusal was the relay\'s');
    },
  );

  test(
    'an unreachable relay is not a refusal and does not stop the rest',
    () async {
      relays[0].unreachable = true;
      final publication = await repository.publish(
        await sealed(),
        NostrSession(),
      );

      expect(
        publication.outcomes[relays[0].uri],
        NostrRelayOutcome.unreachable,
      );
      expect(publication.outcomes[relays[1].uri], NostrRelayOutcome.accepted);
      expect(publication.accepted, isTrue);
    },
  );

  test('no relay accepting leaves a publication with no route', () async {
    for (final relay in relays) {
      relay.unreachable = true;
    }
    final publication = await repository.publish(
      await sealed(),
      NostrSession(),
    );

    expect(publication.accepted, isFalse);
    expect(
      publication.outcomes.values,
      everyElement(NostrRelayOutcome.unreachable),
    );
  });

  test('a published descriptor reads back canonical and complete', () async {
    await repository.publish(await sealed(), NostrSession());

    final search = await repository.discover(
      credential: credential,
      session: NostrSession(),
    );

    expect(search.incomplete, isFalse);
    expect(search.descriptors, hasLength(1));
    expect(search.descriptors.single.descriptor, canonical);
    expect(search.descriptors.single.network, Network.bitcoinTestnet);
    expect(
      search.descriptors.single.createdAt,
      DateTime.utc(2027, 3, 4, 5, 6, 7),
    );
  });

  test(
    'the same descriptor on both relays is one result, dated first',
    () async {
      final first = await repositoryOver(relays, now: DateTime.utc(2027, 1, 1))
          .seal(
            credential: credential,
            descriptor: descriptor,
            network: Network.bitcoinTestnet,
          );
      final later = await repositoryOver(relays, now: DateTime.utc(2027, 6, 1))
          .seal(
            credential: credential,
            descriptor: descriptor,
            network: Network.bitcoinTestnet,
          );
      relays[0].events.add(later.toMap());
      relays[1].events.add(first.toMap());

      final search = await repository.discover(
        credential: credential,
        session: NostrSession(),
      );

      expect(search.descriptors, hasLength(1));
      expect(search.descriptors.single.createdAt, DateTime.utc(2027, 1, 1));
    },
  );

  test('a second generation is kept beside the first', () async {
    await repository.publish(await sealed(), NostrSession());
    await repository.publish(
      await sealed(source: fixture.descriptor(generation: 1)),
      NostrSession(),
    );

    final search = await repository.discover(
      credential: credential,
      session: NostrSession(),
    );

    expect(search.descriptors, hasLength(2));
    expect(search.incomplete, isFalse);
  });

  test('another wallet\'s words open nothing and report nothing', () async {
    await repository.publish(await sealed(), NostrSession());

    final search = await repository.discover(
      credential: stranger,
      session: NostrSession(),
    );

    expect(search.descriptors, isEmpty);
    // The relays answered, so an empty result is an honest absence.
    expect(search.incomplete, isFalse);
  });

  test('a forged, tampered or foreign event is never believed', () async {
    final event = await sealed();
    final foreignKey = ECPrivate.fromHex('1' * 63 + '3');
    final json = event.toMap();

    relays[0].events.addAll([
      // Signature over somebody else's key.
      {
        ...json,
        'sig': foreignKey.signBip340(hex.decode(event.id), tweak: false),
      },
      // Content swapped, so the ID no longer covers it.
      {...json, 'content': base64Encode(List.filled(80, 9))},
      // A different author, correctly signed by that author.
      _reauthored(event, foreignKey),
      // The right author and a wrong purpose tag.
      _resigned(
        event,
        credential,
        tags: const [
          ['t', 'something-else'],
        ],
      ),
      // The right author and a wrong kind.
      _resigned(event, credential, kind: 1090),
    ]);

    final search = await repository.discover(
      credential: credential,
      session: NostrSession(),
    );

    expect(search.descriptors, isEmpty);
    expect(search.incomplete, isFalse);
  });

  test('a relay that fills its page leaves the search incomplete', () async {
    await repository.publish(await sealed(), NostrSession());
    relays[0]
      ..pageSize = 1
      ..hasMore = true;

    final search = await repository.discover(
      credential: credential,
      session: NostrSession(),
    );

    expect(search.descriptors, hasLength(1));
    expect(search.incomplete, isTrue);
  });

  test('a full page is incomplete even when every event is valid', () async {
    final event = await sealed();
    for (var index = 0; index < NostrRelayDatasource.maxEvents; index++) {
      relays[0].events.add(
        _resigned(event, credential, createdAt: event.createdAt - index),
      );
    }

    final search = await repository.discover(
      credential: credential,
      session: NostrSession(),
    );

    expect(relays[0].events, hasLength(NostrRelayDatasource.maxEvents));
    // One descriptor, republished: the cap says nothing was proved about what
    // else that relay holds.
    expect(search.descriptors, hasLength(1));
    expect(search.incomplete, isTrue);
  });

  test('a search no relay answered is incomplete, not an absence', () async {
    for (final relay in relays) {
      relay.unreachable = true;
    }

    final search = await repository.discover(
      credential: credential,
      session: NostrSession(),
    );

    expect(search.descriptors, isEmpty);
    expect(search.incomplete, isTrue);
  });

  test(
    'one silent relay never turns the other\'s answer into absence',
    () async {
      await repository.publish(await sealed(), NostrSession());
      relays[0].unreachable = true;

      final search = await repository.discover(
        credential: credential,
        session: NostrSession(),
      );

      expect(search.descriptors, hasLength(1));
      expect(
        search.incomplete,
        isTrue,
        reason: 'one relay was never heard from',
      );
    },
  );

  test('a cancelled search reports what it has as incomplete', () async {
    await repository.publish(await sealed(), NostrSession());
    final session = NostrSession()..cancel();

    final search = await repository.discover(
      credential: credential,
      session: session,
    );

    expect(search.incomplete, isTrue);
  });

  test(
    'a descriptor sealed for another chain is refused on read-back',
    () async {
      // The frame says mainnet; every account key in it is a testnet key.
      final event = await repository.seal(
        credential: credential,
        descriptor: descriptor,
        network: Network.bitcoinMainnet,
      );
      relays[0].events.add(event.toMap());

      final search = await repository.discover(
        credential: credential,
        session: NostrSession(),
      );

      expect(search.descriptors, isEmpty);
    },
  );
}

/// The same content under a different author, signed by that author.
Map<String, dynamic> _reauthored(nostr.Event event, ECPrivate key) =>
    nostr.Event.from(
      kind: event.kind,
      content: event.content,
      secretKey: key.toHex(),
      createdAt: event.createdAt,
      tags: event.tags,
    ).toMap();

/// The same author and content under a changed profile, correctly signed.
Map<String, dynamic> _resigned(
  nostr.Event event,
  BackupCredential credential, {
  List<List<String>>? tags,
  int? kind,
  int? createdAt,
}) => credential
    .signNostrEvent(
      kind: kind ?? event.kind,
      content: event.content,
      createdAt: createdAt ?? event.createdAt,
      tags: tags ?? event.tags,
    )
    .toMap();
