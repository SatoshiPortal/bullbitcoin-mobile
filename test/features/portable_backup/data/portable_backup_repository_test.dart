import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/nostr/nostr_event.dart';
import 'package:bb_mobile/core/nostr/nostr_relay_datasource.dart';
import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/recoverbull_encryption.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/portable_backup/data/backup_password_material.dart';
import 'package:bb_mobile/features/portable_backup/data/portable_backup_model.dart';
import 'package:bb_mobile/features/portable_backup/data/portable_backup_repository_impl.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/derive_backup_password_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/fetch_portable_vault_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/open_portable_backup_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/prepare_portable_backups_usecase.dart';
import 'package:bb_mobile/features/portable_backup/domain/usecases/publish_portable_vault_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../bullvault/support/bip138_prototype_fixture.dart';
import '../../wallet_backup/support/canonical_backup_snapshot.dart';

// Independently computed with Python hashlib/hmac and cryptography's secp256k1:
// fixture root seed = 32 bytes of 99; m/83696968'/1642'/0'/1'; BIP85 HMAC,
// then HKDF-SHA256 with the documented salt and mnemonic/encryption labels.
const _words =
    'abandon differ wave love claim impact beach put bunker polar fragile crop';
const _entropy = '0007bbdfc2329ae384dd761e74ed7199';
const _author =
    '0e4567d2c920d4bd991a9e472391cc429464f8c621d92c6e87c005800c998c7b';
const _otherWords =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

class _Channel extends Mock implements WebSocketChannel {}

class _Sink extends Mock implements WebSocketSink {}

class _Relay {
  final published = <Map<String, dynamic>>[];
  final filters = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> events = [];
  String? rawEventJson;
  bool incomplete = false;
  bool fail = false;
  int connections = 0;
  late final datasource = NostrRelayDatasource(connect: _connect);

  WebSocketChannel _connect(Uri _) {
    connections++;
    final channel = _Channel();
    final sink = _Sink();
    final stream = StreamController<dynamic>();
    when(() => channel.ready).thenAnswer((_) async {});
    when(() => channel.stream).thenAnswer((_) => stream.stream);
    when(() => channel.sink).thenReturn(sink);
    when(() => sink.close()).thenAnswer((_) async {
      unawaited(stream.close());
    });
    when(() => sink.add(any())).thenAnswer((call) {
      final frame =
          jsonDecode(call.positionalArguments.first as String) as List;
      if (frame.first == 'EVENT') {
        final event = frame[1] as Map<String, dynamic>;
        published.add(event);
        stream.add(jsonEncode(['OK', event['id'], !fail]));
      } else if (frame.first == 'REQ') {
        filters.add(frame[2] as Map<String, dynamic>);
        if (rawEventJson != null) {
          stream.add('["EVENT",${jsonEncode(frame[1])},$rawEventJson]');
        }
        for (final event in events) {
          stream.add(jsonEncode(['EVENT', frame[1], event]));
        }
        if (fail) {
          stream.addError(const FormatException('Relay failed'));
        } else {
          stream.add(
            jsonEncode([
              'EOSE',
              frame[1],
              if (incomplete) ['more'],
            ]),
          );
        }
      }
    });
    return channel;
  }
}

T _value<T>(Result<T, PortableBackupFailure> result) {
  expect(result, isA<Ok<T, PortableBackupFailure>>());
  return (result as Ok<T, PortableBackupFailure>).value;
}

void main() {
  final fixture = Bip138PrototypeFixture();
  final descriptor = fixture.descriptor();
  final metadata = canonicalCodec().encode(canonicalFullSnapshot());
  const encryption = RecoverBullEncryption();
  final relayUri = Uri.parse('wss://relay.example');
  late PortableBackupFiles files;
  late _Relay relay;
  late PortableBackupRepositoryImpl repository;

  setUp(() {
    relay = _Relay();
    repository = PortableBackupRepositoryImpl(
      encryption,
      relay.datasource,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
    );
  });

  setUpAll(() async {
    final setup = PortableBackupRepositoryImpl(encryption, _Relay().datasource);
    files = _value(
      await PreparePortableBackupsUsecase(setup).execute(
        words: _words,
        metadataJson: metadata,
        descriptor: descriptor,
        network: 'testnet4',
      ),
    );
    const evidenceDirectory = String.fromEnvironment(
      'PORTABLE_BACKUP_EVIDENCE_DIR',
    );
    if (evidenceDirectory.isNotEmpty) {
      await Directory(evidenceDirectory).create(recursive: true);
      await File(
        '$evidenceDirectory/metadata.bin',
      ).writeAsBytes(files.metadata);
      await File('$evidenceDirectory/vault.bin').writeAsBytes(files.vault);
      await File('$evidenceDirectory/metadata.json').writeAsString(metadata);
      await File('$evidenceDirectory/descriptor.txt').writeAsString(descriptor);
    }
  });

  Map<String, dynamic> signed(
    Uint8List file, {
    String words = _words,
    int createdAt = 1,
    int kind = PortableBackupRepositoryImpl.eventKind,
    List<List<String>>? tags,
  }) {
    final material = BackupPasswordMaterial.parse(words);
    final eventTags =
        tags ??
        [
          ['d', PortableBackupRepositoryImpl.lookupTag],
        ];
    final content = base64Encode(file);
    final id = NostrEvent.hash(
      author: material.author,
      createdAt: createdAt,
      kind: kind,
      tags: eventTags,
      content: content,
    );
    return NostrEvent(
      id: id,
      author: material.author,
      createdAt: createdAt,
      kind: kind,
      tags: eventTags,
      content: content,
      signature: material.signHash(id),
    ).toJson();
  }

  Future<Result<PortableBackupFetch, PortableBackupFailure>> fetch({
    String words = _words,
    String network = 'testnet4',
    NostrSession? session,
  }) => FetchPortableVaultUsecase(repository).execute(
    words: words,
    network: network,
    relay: relayUri,
    session: session ?? NostrSession(),
  );

  test(
    'reserved derivation matches an independent 12-word and author vector',
    () async {
      expect(Bip85Reservations.walletBackupEncryptionKey.path, "1642'/0'/1'");
      final actual = _value(
        await DeriveBackupPasswordUsecase(
          repository,
        ).execute(fixture.publishingRoot),
      );
      expect(actual, _words);
      expect(
        hex.encode(
          bip39.Mnemonic.fromSentence(actual, bip39.Language.english).entropy,
        ),
        _entropy,
      );
      expect(BackupPasswordMaterial.parse(actual).author, _author);
      expect(
        BackupPasswordMaterial.deriveWords(fixture.publishingRoot),
        _words,
      );
      expect(
        BackupPasswordMaterial.parse(
          '  ${_words.toUpperCase().replaceAll(' ', '\n\t')}  ',
        ).author,
        _author,
      );
    },
  );

  test(
    'bad length, unknown words and checksum failures never reach the relay',
    () async {
      for (final words in ['', 'abandon ' * 12, 'invalid ' * 12, 'x' * 257]) {
        expect(
          await fetch(words: words),
          isA<Err<PortableBackupFetch, PortableBackupFailure>>(),
        );
        expect(
          () => BackupPasswordMaterial.parse(words),
          throwsA(isA<InvalidBackupPasswordException>()),
        );
      }
      expect(relay.connections, 0);
      expect(
        BackupPasswordMaterial.parse(_words).toString(),
        isNot(contains(_words)),
      );
    },
  );

  test(
    'one password opens two independent RecoverBull files with exact contents',
    () async {
      expect(files.metadata, isNot(orderedEquals(files.vault)));
      for (final entry in [
        (PortableBackupKind.metadata, files.metadata, metadata),
        (PortableBackupKind.vault, files.vault, descriptor),
      ]) {
        final result = _value(
          await OpenPortableBackupUsecase(repository).execute(
            words: _words,
            encodedFile: base64Encode(entry.$2),
            network: 'testnet4',
            kind: entry.$1,
          ),
        );
        expect(result.contents, entry.$3);
        expect(result.kind, entry.$1);
        expect(result.network, 'testnet4');
      }
      final repeated = await BackupPasswordMaterial.parse(_words).encrypt(
        encryption,
        PortableBackupModel(
          PortableBackupKind.vault,
          'testnet4',
          descriptor,
        ).encode(),
      );
      expect(repeated, isNot(orderedEquals(files.vault)));
    },
  );

  test(
    'wrong valid password, artifact kind and network are rejected',
    () async {
      final open = OpenPortableBackupUsecase(repository);
      expect(
        await open.execute(
          words: _otherWords,
          encodedFile: base64Encode(files.vault),
          network: 'testnet4',
          kind: PortableBackupKind.vault,
        ),
        isA<Err<PortableBackupArtifact, PortableBackupFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<PortableBackupDecryptFailure>(),
        ),
      );
      for (final expected in [
        ('bitcoin', PortableBackupKind.vault),
        ('testnet4', PortableBackupKind.metadata),
      ]) {
        expect(
          await open.execute(
            words: _words,
            encodedFile: base64Encode(files.vault),
            network: expected.$1,
            kind: expected.$2,
          ),
          isA<Err<PortableBackupArtifact, PortableBackupFailure>>().having(
            (r) => r.failure,
            'failure',
            isA<PortableBackupInvalidDataFailure>(),
          ),
        );
      }
    },
  );

  test(
    'deeply nested untrusted tags are rejected without recursive encoding',
    () async {
      relay.rawEventJson =
          '{"pubkey":"$_author",'
          '"kind":${PortableBackupRepositoryImpl.eventKind},'
          '"tags":${'[' * 20000}${']' * 20000}}';
      expect(
        relay.rawEventJson!.length,
        lessThan(NostrRelayDatasource.maxFrameBytes),
      );
      final result = _value(await fetch());
      expect(result.rejectedEvents, 1);
      expect(result.candidates, isEmpty);
    },
  );

  test(
    'encoded input limits apply before password parsing or decryption',
    () async {
      const maxEncodedBytes =
          ((RecoverBullEncryption.maxCiphertextBytes + 2) ~/ 3) * 4;
      for (final words in [_words, 'invalid words']) {
        final result = await OpenPortableBackupUsecase(repository).execute(
          words: words,
          encodedFile: 'A' * (maxEncodedBytes + 1),
          network: 'testnet4',
          kind: PortableBackupKind.metadata,
        );
        expect(
          result,
          isA<Err<PortableBackupArtifact, PortableBackupFailure>>().having(
            (error) => error.failure,
            'failure',
            isA<PortableBackupInvalidDataFailure>(),
          ),
        );
      }
      expect(relay.connections, 0);
    },
  );

  test('publication authenticates and sends one immutable snapshot', () async {
    final mutableFile = Uint8List.fromList(files.vault);
    final publication = repository.publish(
      words: _words,
      encryptedFile: mutableFile,
      relay: relayUri,
      session: NostrSession(),
    );
    // The asynchronous decryption must not create a gap between validating the vault
    // and selecting the bytes actually sent to the public relay.
    mutableFile.fillRange(0, mutableFile.length, 0);
    _value(await publication);
    expect(
      base64Decode(relay.published.single['content'] as String),
      files.vault,
    );
  });

  test(
    'metadata cannot be published; vault preserves exact encrypted bytes',
    () async {
      final publish = PublishPortableVaultUsecase(repository);
      expect(
        await publish.execute(
          words: _words,
          encryptedFile: files.metadata,
          relay: relayUri,
          session: NostrSession(),
        ),
        isA<Err<String, PortableBackupFailure>>(),
      );
      expect(relay.connections, 0);
      final id = _value(
        await publish.execute(
          words: _words,
          encryptedFile: files.vault,
          relay: relayUri,
          session: NostrSession(),
        ),
      );
      final event = NostrEvent.parse(relay.published.single);
      expect(event.id, id);
      expect(event.author, _author);
      expect(base64Decode(event.content), files.vault);
    },
  );

  test(
    'password alone queries expected author/profile and recovers after partial transport failure',
    () async {
      relay.events = [signed(files.vault)];
      relay.fail = true;
      final result = _value(await fetch());
      expect(result.incomplete, isTrue);
      expect(result.candidates.single.artifact.contents, descriptor);
      expect(result.candidates.single.encryptedFile, files.vault);
      expect(relay.filters.single, {
        'authors': [_author],
        'kinds': [PortableBackupRepositoryImpl.eventKind],
        '#d': [PortableBackupRepositoryImpl.lookupTag],
        'limit': 32,
      });
    },
  );

  test(
    'forged duplicate cannot suppress a valid event; valid repeats are deduplicated',
    () async {
      final valid = signed(files.vault);
      relay.events = [
        {...valid, 'sig': '0' * 128},
        valid,
        valid,
      ];
      relay.incomplete = true;
      final result = _value(await fetch());
      expect(result.candidates.length, 1);
      expect(result.rejectedEvents, 1);
      expect(result.incomplete, isTrue);
    },
  );

  test(
    'validly signed foreign authors, kinds, profiles and metadata are rejected',
    () async {
      relay.events = [
        signed(files.vault, words: _otherWords),
        signed(files.vault, kind: 1090),
        signed(
          files.vault,
          tags: [
            ['d', 'foreign-profile'],
          ],
        ),
        signed(files.metadata),
        signed(files.vault),
      ];
      final result = _value(await fetch());
      expect(result.candidates.length, 1);
      expect(result.rejectedEvents, 4);
      expect(result.incomplete, isFalse);
      relay.events = [signed(files.vault)];
      final mismatched = _value(await fetch(network: 'bitcoin'));
      expect(mismatched.candidates, isEmpty);
      expect(mismatched.rejectedEvents, 1);
    },
  );

  test('cancelled recovery and publication never contact a relay', () async {
    final cancelled = NostrSession()..cancel();
    expect(
      await fetch(session: cancelled),
      isA<Err<PortableBackupFetch, PortableBackupFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<PortableBackupCancelledFailure>(),
      ),
    );
    final session = NostrSession();
    final future = PublishPortableVaultUsecase(repository).execute(
      words: _words,
      encryptedFile: files.vault,
      relay: relayUri,
      session: session,
    );
    session.cancel();
    expect(
      await future,
      isA<Err<String, PortableBackupFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<PortableBackupCancelledFailure>(),
      ),
    );
    expect(relay.connections, 0);
  });

  test(
    'model rejects compressed expansion bombs and unsupported manifests',
    () {
      final bomb = Uint8List.fromList(
        gzip.encode(List.filled(PortableBackupModel.maxBytes + 1, 32)),
      );
      expect(bomb.length, lessThan(2000));
      expect(() => PortableBackupModel.decode(bomb), throwsFormatException);
      for (final change in [
        {'format': 'future-profile'},
        {'kind': 'seed'},
        {'contents': 12},
      ]) {
        final compressed = Uint8List.fromList(
          gzip.encode(
            utf8.encode(
              jsonEncode({
                'format': PortableBackupModel.profile,
                'kind': 'vault',
                'network': 'testnet4',
                'contents': descriptor,
                ...change,
              }),
            ),
          ),
        );
        expect(
          () => PortableBackupModel.decode(compressed),
          throwsFormatException,
        );
      }
      expect(
        () => const PortableBackupModel(
          PortableBackupKind.metadata,
          'unknown',
          '{}',
        ).encode(),
        throwsFormatException,
      );
    },
  );

  test(
    'repository validates descriptor network and metadata structure before encryption',
    () async {
      for (final input in [('bitcoin', metadata), ('testnet4', '[]')]) {
        expect(
          await PreparePortableBackupsUsecase(repository).execute(
            words: _words,
            metadataJson: input.$2,
            descriptor: descriptor,
            network: input.$1,
          ),
          isA<Err<PortableBackupFiles, PortableBackupFailure>>(),
        );
      }
      expect(relay.connections, 0);
    },
  );

  test(
    'artifact containers defensively copy files and reject invalid identity',
    () {
      final original = Uint8List.fromList([1, 2]);
      final copy = PortableBackupFiles(metadata: original, vault: original);
      original[0] = 99;
      expect(copy.metadata, [1, 2]);
      expect(() => copy.vault[0] = 99, throwsUnsupportedError);
      expect(
        () => PortableBackupArtifact(
          kind: PortableBackupKind.vault,
          network: 'testnet4',
          contents: 'x' * 24001,
        ),
        throwsFormatException,
      );
      expect(
        () => PortableBackupArtifact(
          kind: PortableBackupKind.vault,
          network: 'unknown',
          contents: descriptor,
        ),
        throwsFormatException,
      );
      expect(
        () => PortableBackupArtifact(
          kind: PortableBackupKind.metadata,
          network: 'testnet4',
          contents: '',
        ),
        throwsFormatException,
      );
    },
  );
}
