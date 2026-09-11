import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/bip138_codec.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_relay_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/descriptor_backup_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/fetch_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/publish_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/bip138_prototype_fixture.dart';

class _Repository extends Mock implements DescriptorBackupRepository {}

class _Identity extends Mock implements NostrIdentityFacade {}

void main() {
  final fixture = Bip138PrototypeFixture();
  final real = DescriptorBackupRepositoryImpl(
    Bip138Codec(),
    const DescriptorBackupRelayDatasource(),
  );
  final prepared = real.prepare(fixture.descriptor());
  final backup = (prepared as Ok<DescriptorBackup, BullVaultFailure>).value;
  final relay = Uri.parse('wss://example.com');
  late _Repository repository;
  late _Identity identity;
  late DescriptorBackupSession session;
  setUp(() {
    repository = _Repository();
    identity = _Identity();
    session = DescriptorBackupSession();
    when(() => repository.prepare('descriptor')).thenReturn(prepared);
  });

  test('cancelled publishing never resolves identity or sends', () async {
    session.cancel();
    final result = await PublishDescriptorBackupUsecase(
      repository,
      identity,
    ).execute(descriptor: 'descriptor', relay: relay, session: session);
    expect(result, isA<Err<List<String>, BullVaultFailure>>());
    verifyZeroInteractions(identity);
  });

  test('invalid descriptor never resolves identity', () async {
    when(
      () => repository.prepare('descriptor'),
    ).thenReturn(const Err(BullVaultInvalidRecoveryFailure()));
    expect(
      await PublishDescriptorBackupUsecase(
        repository,
        identity,
      ).execute(descriptor: 'descriptor', relay: relay, session: session),
      isA<Err<List<String>, BullVaultFailure>>(),
    );
    verifyZeroInteractions(identity);
  });

  test('identity failure stops before publication', () async {
    when(
      () => identity.descriptorBackupPublicKey(backup.recipients.first.lookup),
    ).thenAnswer((_) async => const Err(NostrIdentityUnavailableFailure()));
    expect(
      await PublishDescriptorBackupUsecase(
        repository,
        identity,
      ).execute(descriptor: 'descriptor', relay: relay, session: session),
      isA<Err<List<String>, BullVaultFailure>>(),
    );
    verify(() => repository.prepare('descriptor')).called(1);
    verifyNoMoreInteractions(repository);
  });

  test('signing failure never sends the prepared event', () async {
    final recipient = backup.recipients.first;
    final author = '01' * 32;
    final request = real.signingRequest(recipient, author, 1);
    when(
      () => identity.descriptorBackupPublicKey(recipient.lookup),
    ).thenAnswer((_) async => Ok(author));
    when(
      () => repository.signingRequest(recipient, author, any()),
    ).thenReturn(request);
    when(
      () => identity.signDescriptorBackupHash(
        lookup: recipient.lookup,
        hashHex: request.hash,
        expectedPublicKey: author,
      ),
    ).thenAnswer((_) async => const Err(NostrIdentityUnavailableFailure()));
    expect(
      await PublishDescriptorBackupUsecase(
        repository,
        identity,
      ).execute(descriptor: 'descriptor', relay: relay, session: session),
      isA<Err<List<String>, BullVaultFailure>>(),
    );
    verifyNever(() => repository.publish(request, any(), relay, session));
  });

  test(
    'fetch forwards an isolated session with no identity dependency',
    () async {
      final expected = DescriptorBackupFetch(
        [],
        incomplete: true,
        rejectedEvents: 1,
      );
      when(
        () => repository.fetch('xpub', relay, session),
      ).thenAnswer((_) async => Ok(expected));
      final result = await FetchDescriptorBackupUsecase(
        repository,
      ).execute(input: 'xpub', relay: relay, session: session);
      expect(
        (result as Ok<DescriptorBackupFetch, BullVaultFailure>).value,
        same(expected),
      );
      verifyZeroInteractions(identity);
    },
  );
}
