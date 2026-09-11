import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/bip138_codec.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_event.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_relay_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../support/bip138_prototype_fixture.dart';
import '../support/descriptor_backup_identity_fixture.dart';

class _Channel extends Mock implements WebSocketChannel {}

class _Sink extends Mock implements WebSocketSink {}

void main() {
  final relay = Uri.parse('wss://relay.example');
  final fixture = Bip138PrototypeFixture();
  late _Channel channel;
  late _Sink sink;
  late StreamController<dynamic> incoming;
  late List<List<dynamic>> sent;
  late DescriptorBackupRelayDatasource datasource;

  setUp(() {
    channel = _Channel();
    sink = _Sink();
    incoming = StreamController<dynamic>();
    sent = [];
    when(() => channel.ready).thenAnswer((_) async {});
    when(() => channel.stream).thenAnswer((_) => incoming.stream);
    when(() => channel.sink).thenReturn(sink);
    when(() => sink.add(any())).thenAnswer((call) {
      sent.add(jsonDecode(call.positionalArguments.first as String) as List);
    });
    when(() => sink.close()).thenAnswer((_) async {
      unawaited(incoming.close());
    });
    datasource = DescriptorBackupRelayDatasource(
      connect: (_) => channel,
      timeout: const Duration(milliseconds: 50),
    );
  });

  Future<String> subscription() async {
    await Future<void>.delayed(Duration.zero);
    return sent.first[1] as String;
  }

  for (final hint in [null, 'more', 'auth']) {
    test(
      'EOSE $hint preserves partial events and reports completion honestly',
      () async {
        final result = datasource.fetch(
          'lookup',
          relay,
          DescriptorBackupSession(),
        );
        final id = await subscription();
        incoming.add(
          jsonEncode([
            'EVENT',
            'another-subscription',
            {'id': 'ignored'},
          ]),
        );
        incoming.add(
          jsonEncode([
            'EVENT',
            id,
            {'id': 'received'},
          ]),
        );
        incoming.add(
          jsonEncode([
            'EOSE',
            id,
            if (hint != null) [hint],
          ]),
        );
        final response = await result;
        expect(response.events, [
          {'id': 'received'},
        ]);
        expect(response.incomplete, hint != null);
        expect(sent.last, ['CLOSE', id]);
        expect((sent.first[2] as Map).containsKey('authors'), isFalse);
        verify(() => sink.close()).called(1);
      },
    );
  }

  test('timeout retains received events as incomplete', () async {
    final future = datasource.fetch('lookup', relay, DescriptorBackupSession());
    final id = await subscription();
    incoming.add(
      jsonEncode([
        'EVENT',
        id,
        {'id': 'received'},
      ]),
    );
    final response = await future;
    expect(response.incomplete, isTrue);
    expect(response.events.length, 1);
  });

  test('event count stops an unbounded relay response', () async {
    final future = datasource.fetch('lookup', relay, DescriptorBackupSession());
    final id = await subscription();
    for (var i = 0; i < 40; i++) {
      incoming.add(
        jsonEncode([
          'EVENT',
          id,
          {'id': '$i'},
        ]),
      );
    }
    final response = await future;
    expect(response.events.length, DescriptorBackupRelayDatasource.maxEvents);
    expect(response.incomplete, isTrue);
  });

  test('cancel before connection ready prevents sending a request', () async {
    final ready = Completer<void>();
    when(() => channel.ready).thenAnswer((_) => ready.future);
    final session = DescriptorBackupSession();
    final future = datasource.fetch('lookup', relay, session);
    final assertion = expectLater(future, throwsFormatException);
    session.cancel();
    ready.complete();
    await assertion;
    expect(sent, isEmpty);
  });

  test(
    'single-key descriptors and key expressions resolve the same lookup',
    () async {
      final key = fixture.signers.first.accountKey.xpub;
      final lookups = <String>[];
      for (final input in [
        key,
        '$key/0/*',
        '[12345678/48h/1h/0h/2h]$key/<0;1>/*',
        'wpkh($key/*)',
        'wpkh($key/1/*)',
      ]) {
        final stream = StreamController<dynamic>();
        when(() => channel.stream).thenAnswer((_) => stream.stream);
        when(() => sink.close()).thenAnswer((_) async {
          unawaited(stream.close());
        });
        when(() => sink.add(any())).thenAnswer((call) {
          final request =
              jsonDecode(call.positionalArguments.first as String) as List;
          if (request.first == 'REQ') {
            lookups.add((request[2]['#d'] as List).single as String);
            stream.add(jsonEncode(['EOSE', request[1]]));
          }
        });
        final repo = DescriptorBackupRepositoryImpl(Bip138Codec(), datasource);
        final result = await repo.fetch(
          input,
          relay,
          DescriptorBackupSession(),
        );
        expect(
          result,
          isA<Ok<DescriptorBackupFetch, BullVaultFailure>>(),
          reason: input,
        );
      }
      expect(lookups.length, 5);
      expect(lookups.toSet().length, 1);
    },
  );

  test('malformed/private/multi-account input never queries a relay', () async {
    final repo = DescriptorBackupRepositoryImpl(Bip138Codec(), datasource);
    for (final input in [
      'invalid',
      fixture.publishingRoot,
      'wpkh(${fixture.publishingRoot}/0/*)',
      fixture.descriptor(),
    ]) {
      expect(
        await repo.fetch(input, relay, DescriptorBackupSession()),
        isA<Err<DescriptorBackupFetch, BullVaultFailure>>(),
      );
    }
    expect(sent, isEmpty);
  });

  test(
    'a forged duplicate cannot suppress a later signed decryptable event',
    () async {
      final repo = DescriptorBackupRepositoryImpl(Bip138Codec(), datasource);
      final backup =
          (repo.prepare(fixture.descriptor())
                  as Ok<DescriptorBackup, BullVaultFailure>)
              .value;
      final recipient = backup.recipients.first;
      final identity = descriptorPrototypeIdentity(fixture.publishingRoot);
      final author =
          (await identity.descriptorBackupPublicKey(recipient.lookup)
                  as Ok<String, NostrIdentityFailure>)
              .value;
      final request = repo.signingRequest(recipient, author, 1);
      final signature =
          (await identity.signDescriptorBackupHash(
                    lookup: recipient.lookup,
                    hashHex: request.hash,
                    expectedPublicKey: author,
                  )
                  as Ok<String, NostrIdentityFailure>)
              .value;
      final valid = DescriptorBackupEvent.signed(request, signature).toJson();
      final future = repo.fetch(
        recipient.key.xpub,
        relay,
        DescriptorBackupSession(),
      );
      final subscriptionId = await subscription();
      incoming.add(
        jsonEncode([
          'EVENT',
          subscriptionId,
          {...valid, 'sig': '0' * 128},
        ]),
      );
      incoming.add(jsonEncode(['EVENT', subscriptionId, valid]));
      incoming.add(jsonEncode(['EVENT', subscriptionId, valid]));
      incoming.add(jsonEncode(['EOSE', subscriptionId]));
      final result =
          (await future as Ok<DescriptorBackupFetch, BullVaultFailure>).value;
      expect(result.rejectedEvents, 1);
      expect(result.candidates.single.descriptor, backup.descriptor);
      expect(result.candidates.single.eventId, valid['id']);
      for (final altered in [
        {...valid, 'content': '${valid['content']}a'},
        {...valid, 'kind': 30078},
        {
          ...valid,
          'tags': [
            ['d', '0' * 64],
          ],
        },
        {...valid, 'created_at': -1},
      ]) {
        expect(
          () => DescriptorBackupEvent.parse(altered, recipient.lookup),
          throwsFormatException,
        );
      }
    },
  );
}
