import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/features/bullvault/data/bip138_codec.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_event.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_envelope.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_relay_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup_key.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/fetch_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/publish_descriptor_backup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'support/bip138_prototype_fixture.dart';
import 'support/descriptor_backup_identity_fixture.dart';

void main() {
  test(
    'real Nostr stores and returns the descriptor for every cosigner',
    () async {
      final fixture = Bip138PrototypeFixture();
      const relayUrl = String.fromEnvironment(
        'BIP138_RELAY',
        defaultValue: 'wss://nos.lol',
      );
      final relay = Uri.parse(relayUrl);
      final repository = DescriptorBackupRepositoryImpl(
        Bip138Codec(),
        DescriptorBackupRelayDatasource(
          connect: (uri) => _RecordedChannel(WebSocketChannel.connect(uri)),
        ),
      );
      final publisher = PublishDescriptorBackupUsecase(
        repository,
        descriptorPrototypeIdentity(fixture.publishingRoot),
      );
      final publicationSession = DescriptorBackupSession();
      final published = await publisher.execute(
        descriptor: fixture.descriptor(),
        relay: relay,
        session: publicationSession,
      );
      publicationSession.cancel();
      expect(published, isA<Ok<List<String>, BullVaultFailure>>());
      final publishedIds =
          (published as Ok<List<String>, BullVaultFailure>).value;
      final expected = BdkFacade.parsePublicTwoPathDescriptor(
        descriptor: fixture.descriptor(),
        isTestnet: true,
      );
      final records = <Map<String, dynamic>>[];
      for (final signer in fixture.signers) {
        final receivedEvents = <Map<String, dynamic>>[];
        // New repository/use case per role: no publisher or ciphertext cache exists.
        final fetcher = FetchDescriptorBackupUsecase(
          DescriptorBackupRepositoryImpl(
            Bip138Codec(),
            DescriptorBackupRelayDatasource(
              connect: (uri) => _RecordedChannel(
                WebSocketChannel.connect(uri),
                receivedEvents,
              ),
            ),
          ),
        );
        final session = DescriptorBackupSession();
        final fetched = await fetcher.execute(
          input: signer.accountKey.xpub,
          relay: relay,
          session: session,
        );
        session.cancel();
        expect(fetched, isA<Ok<DescriptorBackupFetch, BullVaultFailure>>());
        final result =
            (fetched as Ok<DescriptorBackupFetch, BullVaultFailure>).value;
        expect(
          result.candidates.map((c) => c.descriptor),
          contains(expected.descriptor),
        );
        final candidate = result.candidates.firstWhere(
          (c) => c.descriptor == expected.descriptor,
        );
        // Equivalent policies are deduplicated by the repository. Separately
        // verify this run's exact signed event, even if an older copy came first.
        final key = DescriptorBackupKey.parse(signer.accountKey.xpub);
        final codec = Bip138Codec();
        final envelope = DescriptorBackupEnvelope(codec);
        final fresh = DescriptorBackupEvent.parse(
          receivedEvents.firstWhere((e) => publishedIds.contains(e['id'])),
          envelope.lookup(key),
        );
        expect(codec.decode(envelope.open(fresh.content, key), key.xOnly), [
          expected.descriptor,
        ]);
        final actual = BdkFacade.parsePublicTwoPathDescriptor(
          descriptor: candidate.descriptor,
          isTestnet: true,
        );
        expect(actual.externalDescriptor, expected.externalDescriptor);
        expect(actual.internalDescriptor, expected.internalDescriptor);
        records.add({
          'role': signer.role.name,
          'eventId': candidate.eventId,
          'newlyPublishedEventId': fresh.id,
          'incomplete': result.incomplete,
        });
        final output = Directory('build/bip138-prototype')
          ..createSync(recursive: true);
        File('${output.path}/fixture.bip138').writeAsBytesSync(candidate.bytes);
      }
      File('build/bip138-prototype/live.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'relay': relayUrl,
          'at': DateTime.now().toUtc().toIso8601String(),
          'descriptor': expected.descriptor,
          'xpubs': fixture.signers.map((s) => s.accountKey.xpub).toList(),
          'publishedEventIds': publishedIds,
          'recovered': records,
        }),
      );
    },
    skip: !const bool.fromEnvironment('BIP138_LIVE'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RecordedChannel extends Mock implements WebSocketChannel {
  final WebSocketChannel inner;
  final List<Map<String, dynamic>>? receivedEvents;
  _RecordedChannel(this.inner, [this.receivedEvents]);
  @override
  Future<void> get ready async {
    try {
      await inner.ready;
    } on Exception catch (error) {
      stdout.writeln('Synthetic relay connection failed: $error');
      rethrow;
    }
  }

  @override
  WebSocketSink get sink => inner.sink;
  @override
  Stream<dynamic> get stream => inner.stream.map((raw) {
    if (raw is String) {
      final value = jsonDecode(raw);
      if (value is List &&
          value.length == 3 &&
          value.first == 'EVENT' &&
          value[2] is Map<String, dynamic>) {
        receivedEvents?.add(value[2] as Map<String, dynamic>);
      }
      if (value is List &&
          value.isNotEmpty &&
          ['OK', 'NOTICE', 'CLOSED', 'AUTH'].contains(value.first)) {
        // Public synthetic test records only; never print encrypted EVENT frames.
        stdout.writeln('Relay response: $raw');
      }
    }
    return raw;
  });
}
