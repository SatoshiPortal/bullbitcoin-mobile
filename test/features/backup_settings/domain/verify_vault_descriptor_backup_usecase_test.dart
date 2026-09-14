import 'dart:typed_data';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/data/vault_backup_test_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/vault_backup_test_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/verify_vault_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/data/bip138_codec.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_metadata_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_mapper.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_repository_impl.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/native.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_backup_test.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart' as verify_ show verify, verifyNever;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../bullvault/bullvault_test_fixture.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';

class _Vaults extends Mock implements BullVaultFacade {}

class _Metadata extends Mock implements WalletBackupFacade {}

class _Files extends Mock implements WalletBackupFileRepository {}

class _History extends Mock implements VaultBackupTestRepository {}

class _Parser extends Fake implements BitcoinDescriptorPort {
  final bool fails;
  _Parser({this.fails = false});

  @override
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  }) {
    if (fails) throw const FormatException('invalid stored descriptor');
    return parseTestBullVaultDescriptor(
      descriptor: descriptor,
      network: network,
    );
  }
}

void main() {
  late _Vaults vaults;
  late _Metadata metadata;
  late _Files files;
  late VaultBackupTestRepositoryImpl history;
  late VerifyVaultDescriptorBackupUsecase verify;
  final now = DateTime.utc(2026, 9, 13, 18);
  final record = testBullVaultCreateResult(includesInheritance: true).record;
  final policy = record.recoveryPackage.policy;
  final descriptorId = VaultBackupTest.identity(
    policy.descriptor,
    policy.network.name,
  );
  final codec = testBullVaultRecoveryPackageCodec();

  setUpAll(() => registerFallbackValue(VaultBackupDestination.nostr));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    vaults = _Vaults();
    metadata = _Metadata();
    files = _Files();
    history = VaultBackupTestRepositoryImpl();
    when(() => vaults.listRecords()).thenAnswer((_) async => Ok([record]));
    when(() => vaults.decodeRecoveryPackage(any())).thenAnswer((call) {
      try {
        return codec.decode(call.positionalArguments.single as String);
      } on FormatException {
        return null;
      }
    });
    when(
      () => vaults.encodeRecoveryPackage(record.recoveryPackage),
    ).thenReturn(codec.encode(record.recoveryPackage));
    when(
      () => vaults.recordDescriptorPublicationVerified(
        walletId: any(named: 'walletId'),
        destination: any(named: 'destination'),
      ),
    ).thenAnswer((_) async => const Ok<void, BullVaultFailure>(null));
    verify = VerifyVaultDescriptorBackupUsecase(
      vaults,
      metadata,
      _Parser(),
      history,
      files,
      now: () => now,
    );
  });

  Future<Map<VaultBackupSource, DateTime>> dates([String? id]) async =>
      (await history.load(id ?? descriptorId)
              as Ok<Map<VaultBackupSource, DateTime>, BackupSettingsFailure>)
          .value;

  test(
    'manual descriptor canonicalization records a genuine matching import',
    () async {
      final withoutChecksum = policy.descriptor.split('#').first;
      expect(
        await verify.verifyManual(record.walletId, withoutChecksum),
        isA<Ok<bool, BackupSettingsFailure>>().having(
          (r) => r.value,
          'matched',
          true,
        ),
      );
      expect(await dates(), {VaultBackupSource.manual: now});
      verifyZeroInteractions(metadata);
    },
  );

  test(
    'recovery package verifies but export alone never records a test',
    () async {
      final inspected =
          (await verify.load(record.walletId)
                  as Ok<VaultBackupInspection, BackupSettingsFailure>)
              .value;
      expect(verify.export(inspected), codec.encode(record.recoveryPackage));
      expect(await dates(), isEmpty);
      await verify.verifyManual(
        record.walletId,
        codec.encode(record.recoveryPackage),
      );
      expect(await dates(), {VaultBackupSource.manual: now});
    },
  );

  test('a renewal descriptor cannot certify the older generation', () async {
    final replacement = testBullVaultRecoveryPackage(
      includesInheritance: true,
      generation: 1,
      lineageId: policy.lineageId,
    );
    expect(
      await verify.verifyManual(record.walletId, replacement.policy.descriptor),
      isA<Ok<bool, BackupSettingsFailure>>().having(
        (r) => r.value,
        'matched',
        false,
      ),
    );
    expect(await dates(), isEmpty);
    expect(
      await dates(
        VaultBackupTest.identity(
          replacement.policy.descriptor,
          replacement.policy.network.name,
        ),
      ),
      isEmpty,
    );
  });

  test(
    'wrong network and malformed input preserve previous successful date',
    () async {
      await verify.verifyManual(record.walletId, policy.descriptor);
      final foreign = testBullVaultRecoveryPackage(
        includesInheritance: true,
        network: Network.bitcoinTestnet,
      );
      expect(
        await verify.verifyManual(record.walletId, codec.encode(foreign)),
        isA<Err>(),
      );
      expect(
        await verify.verifyManual(record.walletId, 'not a descriptor'),
        isA<Err>(),
      );
      expect(await dates(), {VaultBackupSource.manual: now});
    },
  );

  test('file picker cancellation has no result and no write', () async {
    when(() => files.pick(maximumBytes: any(named: 'maximumBytes'))).thenAnswer(
      (_) async => const Ok<Uint8List?, BackupSettingsFailure>(null),
    );
    expect(
      await verify.importFile(record.walletId),
      isA<Ok<bool?, BackupSettingsFailure>>().having(
        (r) => r.value,
        'cancelled',
        null,
      ),
    );
    expect(await dates(), isEmpty);
  });

  test(
    'stored descriptor parse failure is typed and never starts a fetch',
    () async {
      final usecase = VerifyVaultDescriptorBackupUsecase(
        vaults,
        metadata,
        _Parser(fails: true),
        history,
        files,
      );
      expect(
        await usecase.verifyMetadata(record.walletId),
        isA<Err<bool, BackupSettingsFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<BackupSettingsInvalidFileFailure>(),
        ),
      );
      verifyZeroInteractions(metadata);
      expect(await dates(), isEmpty);
    },
  );

  test('remote read-back certifies only the metadata source', () async {
    when(() => metadata.fetchRemoteContents()).thenAnswer(
      (_) async => Ok(
        WalletBackupContents(
          vaults: [
            WalletBackupVaultSummary(
              walletRef: record.walletId,
              status: record.status.name,
              network: policy.network,
              lineageId: policy.lineageId,
              vaultGeneration: policy.vaultGeneration,
              descriptor: policy.descriptor,
              birthHeight: policy.birthHeight,
              recoveryPackage: codec.encode(record.recoveryPackage),
            ),
          ],
          labelCount: 0,
          frozenCoinCount: 0,
          walletPreferenceCount: 0,
        ),
      ),
    );
    expect(
      await verify.verifyMetadata(record.walletId),
      isA<Ok<bool, BackupSettingsFailure>>().having(
        (r) => r.value,
        'matched',
        true,
      ),
    );
    expect(await dates(), {VaultBackupSource.metadata: now});
  });

  test(
    'missing remote descriptor never erases or advances a prior date',
    () async {
      await history.record(
        VaultBackupTest(
          descriptorId: descriptorId,
          source: VaultBackupSource.metadata,
          verifiedAt: now.subtract(const Duration(days: 2)),
        ),
      );
      when(
        () => metadata.fetchRemoteContents(),
      ).thenAnswer((_) async => const Ok(null));
      expect(
        await verify.verifyMetadata(record.walletId),
        isA<Ok<bool, BackupSettingsFailure>>().having(
          (r) => r.value,
          'matched',
          false,
        ),
      );
      expect(
        (await dates())[VaultBackupSource.metadata],
        now.subtract(const Duration(days: 2)),
      );
    },
  );

  test('storage failure is not reported as a successful backup test', () async {
    final failedHistory = _History();
    when(
      () => failedHistory.load(descriptorId),
    ).thenAnswer((_) async => const Ok({}));
    registerFallbackValue(
      VaultBackupTest(
        descriptorId: descriptorId,
        source: VaultBackupSource.manual,
        verifiedAt: now,
      ),
    );
    when(
      () => failedHistory.record(any()),
    ).thenAnswer((_) async => const Err(BackupSettingsStorageFailure()));
    final usecase = VerifyVaultDescriptorBackupUsecase(
      vaults,
      metadata,
      _Parser(),
      failedHistory,
      files,
    );
    expect(
      await usecase.verifyManual(record.walletId, policy.descriptor),
      isA<Err<bool, BackupSettingsFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<BackupSettingsStorageFailure>(),
      ),
    );
  });

  test(
    'receipt survives birthday enrichment of an identical descriptor',
    () async {
      await verify.verifyManual(record.walletId, policy.descriptor);
      final enriched = BullVaultPolicy.build(
        lineageId: policy.lineageId,
        vaultGeneration: 0,
        network: policy.network,
        descriptor: policy.descriptor,
        protection: policy.protection,
        everydayKey: policy.everydayKey,
        coldKey: policy.coldKey,
        secondColdKey: policy.secondColdKey,
        inheritanceKey: policy.inheritanceKey,
        schedule: policy.schedule!,
        timeReference: BullVaultTimeReference(
          deviceTime: policy.createdAt!,
          chainHeight: policy.birthHeight! + 1,
          medianTimePast: policy.chainMedianTimePast!,
        ),
      );
      expect(enriched.id, isNot(policy.id));
      final updated = BullVaultRecord(
        walletId: record.walletId,
        lineageId: enriched.lineageId,
        vaultGeneration: record.vaultGeneration,
        mobileAccount: record.mobileAccount,
        mobileSeedFingerprint: record.mobileSeedFingerprint,
        birthHeight: enriched.birthHeight,
        recoveryPackage: BullVaultRecoveryPackage(policy: enriched),
        status: record.status,
        createdAt: record.createdAt,
      );
      when(() => vaults.listRecords()).thenAnswer((_) async => Ok([updated]));
      final inspection =
          (await verify.load(record.walletId)
                  as Ok<VaultBackupInspection, BackupSettingsFailure>)
              .value;
      expect(inspection.testedAt[VaultBackupSource.manual], now);
      expect(inspection.descriptorId, descriptorId);
    },
  );

  test('independent source writes survive a new repository instance', () async {
    await Future.wait([
      history.record(
        VaultBackupTest(
          descriptorId: descriptorId,
          source: VaultBackupSource.manual,
          verifiedAt: now,
        ),
      ),
      history.record(
        VaultBackupTest(
          descriptorId: descriptorId,
          source: VaultBackupSource.metadata,
          verifiedAt: now,
        ),
      ),
    ]);
    final reloaded = await VaultBackupTestRepositoryImpl().load(descriptorId);
    expect(
      (reloaded as Ok<Map<VaultBackupSource, DateTime>, BackupSettingsFailure>)
          .value
          .keys
          .toSet(),
      {VaultBackupSource.manual, VaultBackupSource.metadata},
    );
  });

  test(
    'damaged test history cannot prevent exporting the descriptor',
    () async {
      SharedPreferences.setMockInitialValues({
        'vault_descriptor_test_v1.$descriptorId.manual': 'damaged',
      });
      final result = await verify.load(record.walletId);
      final inspection =
          (result as Ok<VaultBackupInspection, BackupSettingsFailure>).value;
      expect(inspection.historyFailure, isA<BackupSettingsStorageFailure>());
      expect(inspection.testedAt, isEmpty);
      expect(verify.export(inspection), codec.encode(record.recoveryPackage));
    },
  );

  group('bip138', () {
    late SqliteDatabase descriptorStorage;
    late BullVaultRepositoryImpl codecs;
    late BullVaultDescriptorBackup artifact;
    final asked = <String>[];
    // The same cosigners, one generation on: it decrypts with the same keys
    // but it is not the descriptor this vault is being checked for.
    final otherPolicy = testBullVaultRecoveryPackage(
      previousVaultId: record.walletId,
      lineageId: policy.lineageId,
      generation: 1,
      includesInheritance: true,
    ).policy;

    setUpAll(() => registerFallbackValue(Uint8List(0)));

    setUp(() {
      asked.clear();
      descriptorStorage = SqliteDatabase(NativeDatabase.memory());
      final packageCodec = testBullVaultRecoveryPackageCodec();
      codecs = BullVaultRepositoryImpl(
        BullVaultMetadataDatasource(descriptorStorage),
        BullVaultRecordMapper(packageCodec),
        packageCodec,
        Bip138Codec(),
      );
      artifact =
          (codecs.encodePrivateDescriptorBackup(
                    descriptor: policy.descriptor,
                    network: policy.network,
                  )
                  as Ok<BullVaultDescriptorBackup, BullVaultFailure>)
              .value;
      when(
        () => vaults.encodePrivateDescriptorBackup(record.walletId),
      ).thenAnswer((_) async => Ok(artifact));
      when(
        () => vaults.decodePrivateDescriptorBackup(
          bytes: any(named: 'bytes'),
          accountKeyInput: any(named: 'accountKeyInput'),
        ),
      ).thenAnswer(
        (call) => codecs.decodePrivateDescriptorBackup(
          bytes: call.namedArguments[#bytes] as Uint8List,
          accountKeyInput: call.namedArguments[#accountKeyInput] as String,
        ),
      );
    });
    tearDown(() => descriptorStorage.close());

    void answerLookups(
      Map<String, List<Uint8List>> byRecipient, {
      bool incomplete = false,
    }) {
      when(() => metadata.lookupPrivateDescriptors(any())).thenAnswer((
        call,
      ) async {
        final key = call.positionalArguments.single as String;
        asked.add(key);
        return Ok(
          PrivateDescriptorLookup(
            records: [
              for (final bytes in byRecipient[key] ?? const <Uint8List>[])
                PrivateDescriptorRecord(
                  ciphertext: bytes,
                  ciphertextSha256: 'a' * 64,
                  createdAt: now,
                ),
            ],
            incomplete: incomplete,
          ),
        );
      });
    }

    test('a date is recorded only when every cosigner can recover', () async {
      answerLookups({
        for (final recipient in artifact.recipients)
          recipient: [artifact.bytes],
      });

      final result = await verify.verifyBip138(record.walletId);

      final check =
          (result as Ok<VaultBackupBip138Check, BackupSettingsFailure>).value;
      expect(check.eligibleKeys, artifact.recipients.length);
      expect(check.foundKeys, artifact.recipients.length);
      expect(check.complete, isTrue);
      expect(check.incomplete, isFalse);
      expect(await dates(), {VaultBackupSource.bip138: now});
      // Every eligible cosigner was asked, none was assumed.
      expect(asked, artifact.recipients);
    });

    test('a partial result is reported and never written down', () async {
      answerLookups({
        artifact.recipients.first: [artifact.bytes],
      });

      final result = await verify.verifyBip138(record.walletId);

      final check =
          (result as Ok<VaultBackupBip138Check, BackupSettingsFailure>).value;
      expect(check.foundKeys, 1);
      expect(check.eligibleKeys, artifact.recipients.length);
      expect(check.complete, isFalse);
      expect(await dates(), isEmpty);
    });

    test('a record for another descriptor does not count', () async {
      final elsewhere =
          (codecs.encodePrivateDescriptorBackup(
                    descriptor: otherPolicy.descriptor,
                    network: otherPolicy.network,
                  )
                  as Ok<BullVaultDescriptorBackup, BullVaultFailure>)
              .value;
      answerLookups({
        for (final recipient in artifact.recipients)
          recipient: [elsewhere.bytes],
      });

      final result = await verify.verifyBip138(record.walletId);

      expect(
        (result as Ok<VaultBackupBip138Check, BackupSettingsFailure>)
            .value
            .foundKeys,
        0,
      );
      expect(await dates(), isEmpty);
    });

    test('a truncated search is carried through with the counts', () async {
      answerLookups({
        for (final recipient in artifact.recipients)
          recipient: [artifact.bytes],
      }, incomplete: true);

      final result = await verify.verifyBip138(record.walletId);

      final check =
          (result as Ok<VaultBackupBip138Check, BackupSettingsFailure>).value;
      expect(check.incomplete, isTrue);
      // Every key was retrieved, so the vault is backed up whatever else the
      // truncated page might also hold.
      expect(check.complete, isTrue);
      expect(await dates(), {VaultBackupSource.bip138: now});
    });

    test('a refused lookup stops the check rather than guessing', () async {
      when(() => metadata.lookupPrivateDescriptors(any())).thenAnswer(
        (_) async => const Err(WalletBackupRemoteUnavailableFailure()),
      );

      expect(
        await verify.verifyBip138(record.walletId),
        isA<Err<VaultBackupBip138Check, BackupSettingsFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<BackupSettingsUnavailableFailure>(),
        ),
      );
      expect(await dates(), isEmpty);
    });
  });

  group('nostr', () {
    void answerNostr({required bool found, bool incomplete = false}) {
      when(
        () => vaults.verifyNostrDescriptorBackup(
          any(),
          session: any(named: 'session'),
        ),
      ).thenAnswer(
        (_) async => Ok<NostrDescriptorVerification, BullVaultFailure>((
          found: found,
          incomplete: incomplete,
        )),
      );
    }

    test('a genuine read-back records the date and the destination', () async {
      answerNostr(found: true);

      final result = await verify.verifyNostr(record.walletId);

      expect(
        (result as Ok<NostrDescriptorVerification, BackupSettingsFailure>)
            .value
            .found,
        isTrue,
      );
      expect(await dates(), {VaultBackupSource.nostr: now});
      verify_
          .verify(
            () => vaults.recordDescriptorPublicationVerified(
              walletId: record.walletId,
              destination: VaultBackupDestination.nostr,
            ),
          )
          .called(1);
    });

    test('nothing found and an unfinished search record nothing', () async {
      answerNostr(found: false);
      expect(
        await verify.verifyNostr(record.walletId),
        isA<Ok<NostrDescriptorVerification, BackupSettingsFailure>>(),
      );
      expect(await dates(), isEmpty);

      answerNostr(found: false, incomplete: true);
      final truncated = await verify.verifyNostr(record.walletId);
      expect(
        (truncated as Ok<NostrDescriptorVerification, BackupSettingsFailure>)
            .value
            .incomplete,
        isTrue,
      );
      expect(await dates(), isEmpty);
      verify_.verifyNever(
        () => vaults.recordDescriptorPublicationVerified(
          walletId: any(named: 'walletId'),
          destination: any(named: 'destination'),
        ),
      );
    });

    test('a search that could not run changes no date', () async {
      when(
        () => vaults.verifyNostrDescriptorBackup(
          any(),
          session: any(named: 'session'),
        ),
      ).thenAnswer(
        (_) async => const Err<NostrDescriptorVerification, BullVaultFailure>(
          BullVaultBackupCredentialFailure(),
        ),
      );

      expect(
        await verify.verifyNostr(record.walletId),
        isA<Err<NostrDescriptorVerification, BackupSettingsFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<BackupSettingsUnavailableFailure>(),
        ),
      );
      expect(await dates(), isEmpty);
    });
  });

  group('checkAgain', () {
    setUp(() {
      when(() => vaults.encodePrivateDescriptorBackup(any())).thenAnswer(
        (_) async => const Err<BullVaultDescriptorBackup, BullVaultFailure>(
          BullVaultInvalidRecoveryFailure(),
        ),
      );
      when(
        () => vaults.verifyNostrDescriptorBackup(
          any(),
          session: any(named: 'session'),
        ),
      ).thenAnswer(
        (_) async => const Ok<NostrDescriptorVerification, BullVaultFailure>((
          found: false,
          incomplete: false,
        )),
      );
      when(metadata.fetchRemoteContents).thenAnswer(
        (_) async => const Err<WalletBackupContents?, WalletBackupFailure>(
          WalletBackupRemoteUnavailableFailure(),
        ),
      );
    });

    test(
      'each source answers for itself and only manual is left out',
      () async {
        final results =
            (await verify.checkAgain(record.walletId)
                    as Ok<VaultBackupCheckResults, BackupSettingsFailure>)
                .value;

        expect(results, {
          VaultBackupSource.metadata: VaultBackupCheckStatus.unavailable,
          VaultBackupSource.bip138: VaultBackupCheckStatus.unavailable,
          VaultBackupSource.nostr: VaultBackupCheckStatus.failed,
        });
        expect(await dates(), isEmpty);
      },
    );

    test('one source succeeding never dates the ones that failed', () async {
      when(
        () => vaults.verifyNostrDescriptorBackup(
          any(),
          session: any(named: 'session'),
        ),
      ).thenAnswer(
        (_) async => const Ok<NostrDescriptorVerification, BullVaultFailure>((
          found: true,
          incomplete: false,
        )),
      );

      final results =
          (await verify.checkAgain(record.walletId)
                  as Ok<VaultBackupCheckResults, BackupSettingsFailure>)
              .value;

      expect(results[VaultBackupSource.nostr], VaultBackupCheckStatus.success);
      expect(
        results[VaultBackupSource.metadata],
        VaultBackupCheckStatus.unavailable,
      );
      expect(await dates(), {VaultBackupSource.nostr: now});
    });

    test(
      'an unfinished cosigner search is incomplete, not a failure',
      () async {
        when(() => vaults.encodePrivateDescriptorBackup(any())).thenAnswer(
          (_) async => Ok(
            BullVaultDescriptorBackup(
              descriptor: policy.descriptor,
              network: policy.network,
              bytes: Uint8List.fromList([1, 2, 3]),
              recipients: const ['tpub-one'],
              lookupTokens: ['b' * 64],
            ),
          ),
        );
        when(() => metadata.lookupPrivateDescriptors(any())).thenAnswer(
          (_) async =>
              Ok(PrivateDescriptorLookup(records: const [], incomplete: true)),
        );

        final results =
            (await verify.checkAgain(record.walletId)
                    as Ok<VaultBackupCheckResults, BackupSettingsFailure>)
                .value;

        expect(
          results[VaultBackupSource.bip138],
          VaultBackupCheckStatus.incomplete,
        );
        expect(await dates(), isEmpty);
      },
    );

    test('an unknown vault is refused before any source is tried', () async {
      when(() => vaults.listRecords()).thenAnswer((_) async => Ok([]));

      expect(
        await verify.checkAgain(record.walletId),
        isA<Err<VaultBackupCheckResults, BackupSettingsFailure>>(),
      );
      verifyZeroInteractions(metadata);
    });
  });
}
