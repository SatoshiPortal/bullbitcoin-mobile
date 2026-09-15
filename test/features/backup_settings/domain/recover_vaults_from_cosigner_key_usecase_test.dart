import 'dart:typed_data';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/export_private_descriptor_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vault_from_bip138_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_from_cosigner_key_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_result.dart';
import 'package:bb_mobile/features/bullvault/data/bip138_codec.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_metadata_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_mapper.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../bullvault/bullvault_test_fixture.dart';
import '../../../core_test/wallet/bdk_wallet_test_fixture.dart';

class _Vaults extends Mock implements BullVaultFacade {}

class _Metadata extends Mock implements WalletBackupFacade {}

class _Files extends Mock implements WalletBackupFileRepository {}

final class _Parser extends Fake implements BitcoinDescriptorPort {
  @override
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  }) => parseTestBullVaultDescriptor(descriptor: descriptor, network: network);
}

/// Any lookup at all is a bug: the file route is offline.
final class _OfflineMetadata extends Fake implements WalletBackupFacade {
  @override
  Future<Result<PrivateDescriptorLookup, WalletBackupFailure>>
  lookupPrivateDescriptors(String accountKeyInput) =>
      throw StateError('the file route reached the network');
}

void main() {
  late SqliteDatabase storage;
  late BullVaultRepositoryImpl codecs;
  late _Vaults vaults;
  late _Metadata metadata;
  late _Files files;
  late RecoverVaultFromBip138FileUsecase openArtifact;
  late RecoverVaultsFromCosignerKeyUsecase recover;

  final record = testBullVaultCreateResult(includesInheritance: true).record;
  final policy = record.recoveryPackage.policy;
  // A wallet this cosigner has nothing to do with, filed under the same alias
  // because anyone may publish under any token.
  final strangerDescriptor =
      'wsh(sortedmulti(2,${[
        for (final index in [2, 3]) '${deriveSignerKeysAtAccount(testMnemonics[index], account: 4, isTestnet: false).xpub.split(']').last}/<0;1>/*',
      ].join(',')}))';

  late BullVaultDescriptorBackup artifact;

  BullVaultDescriptorBackup encode(String descriptor, Network network) =>
      (codecs.encodePrivateDescriptorBackup(
                descriptor: descriptor,
                network: network,
              )
              as Ok<BullVaultDescriptorBackup, BullVaultFailure>)
          .value;

  void answerLookup(List<Uint8List> candidates, {bool incomplete = false}) {
    when(() => metadata.lookupPrivateDescriptors(any())).thenAnswer(
      (_) async => Ok(
        PrivateDescriptorLookup(
          records: [
            for (final bytes in candidates)
              PrivateDescriptorRecord(
                ciphertext: bytes,
                ciphertextSha256: 'a' * 64,
                createdAt: DateTime.utc(2027),
              ),
          ],
          incomplete: incomplete,
        ),
      ),
    );
  }

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      WalletBackupExport(suggestedFilename: 'x', bytes: const [1]),
    );
  });

  setUp(() {
    storage = SqliteDatabase(NativeDatabase.memory());
    final packageCodec = testBullVaultRecoveryPackageCodec();
    codecs = BullVaultRepositoryImpl(
      BullVaultMetadataDatasource(storage),
      BullVaultRecordMapper(packageCodec),
      packageCodec,
      Bip138Codec(),
    );
    artifact = encode(policy.descriptor, policy.network);

    vaults = _Vaults();
    metadata = _Metadata();
    files = _Files();
    when(() => vaults.listRecords()).thenAnswer((_) async => const Ok([]));
    when(() => vaults.holdsSigningKey(any())).thenAnswer((_) async => false);
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
    when(
      () => vaults.restoreFromDescriptor(
        source: any(named: 'source'),
        label: any(named: 'label'),
      ),
    ).thenAnswer(
      (_) async => Ok(
        BullVaultRestoreResult(
          wallet: Wallet(
            origin: 'restored-wallet',
            network: policy.network,
            signers: const [],
            scriptType: null,
            publicDescriptor: policy.descriptor,
            balanceSat: BigInt.zero,
            isHidden: true,
          ),
          record: record,
          mobileAccess: BullVaultMobileAccess.unavailable,
        ),
      ),
    );
    openArtifact = RecoverVaultFromBip138FileUsecase(vaults, _Parser(), files);
    recover = RecoverVaultsFromCosignerKeyUsecase(metadata, openArtifact);
  });

  tearDown(() => storage.close());

  test('one damaged record never hides the good ones', () async {
    final damaged = Uint8List.fromList(artifact.bytes)
      ..[artifact.bytes.length - 1] ^= 1;
    answerLookup([damaged, Uint8List.fromList(artifact.bytes)]);

    final result = await recover.execute(artifact.recipients.first);

    final outcomes = (result as Ok<VaultRecoveryResult, BackupSettingsFailure>)
        .value
        .outcomes;
    expect(outcomes.map((outcome) => outcome.status), [
      VaultRecoveryStatus.undecryptable,
      VaultRecoveryStatus.imported,
    ]);
    expect(outcomes.last.walletId, 'restored-wallet');
    verify(
      () => vaults.restoreFromDescriptor(
        source: artifact.descriptor,
        label: RecoverVaultFromBip138FileUsecase.fallbackLabel,
      ),
    ).called(1);
  });

  test('a stranger\'s record under the same alias is left alone', () async {
    final stranger = encode(strangerDescriptor, policy.network);
    expect(stranger.recipients, isNot(contains(artifact.recipients.first)));
    answerLookup([stranger.bytes, artifact.bytes]);

    final result = await recover.execute(artifact.recipients.first);

    expect(
      (result as Ok<VaultRecoveryResult, BackupSettingsFailure>).value.outcomes
          .map((outcome) => outcome.status),
      [VaultRecoveryStatus.undecryptable, VaultRecoveryStatus.imported],
    );
  });

  test('a vault already on this device is reported, not re-imported', () async {
    when(() => vaults.listRecords()).thenAnswer((_) async => Ok([record]));
    answerLookup([artifact.bytes]);

    final result = await recover.execute(artifact.recipients.first);

    final outcome = (result as Ok<VaultRecoveryResult, BackupSettingsFailure>)
        .value
        .outcomes
        .single;
    expect(outcome.status, VaultRecoveryStatus.alreadyPresent);
    expect(outcome.walletId, record.walletId);
    verifyNever(
      () => vaults.restoreFromDescriptor(
        source: any(named: 'source'),
        label: any(named: 'label'),
      ),
    );
  });

  test('a package reaches the importer for a vault already here', () async {
    when(() => vaults.listRecords()).thenAnswer((_) async => Ok([record]));
    when(
      () => vaults.restoreFromRecoveryPackage(
        source: any(named: 'source'),
        label: any(named: 'label'),
      ),
    ).thenAnswer(
      (_) async => Ok(
        BullVaultRestoreResult(
          wallet: Wallet(
            origin: record.walletId,
            network: policy.network,
            signers: const [],
            scriptType: null,
            publicDescriptor: policy.descriptor,
            balanceSat: BigInt.zero,
            isHidden: true,
          ),
          record: record,
          mobileAccess: BullVaultMobileAccess.unavailable,
        ),
      ),
    );

    final outcome = await openArtifact.importDescriptor(
      descriptor: policy.descriptor,
      network: policy.network,
      recoveryPackage: '{"package":"richer"}',
    );

    expect(outcome.status, VaultRecoveryStatus.alreadyPresent);
    expect(outcome.walletId, record.walletId);
    verify(
      () => vaults.restoreFromRecoveryPackage(
        source: '{"package":"richer"}',
        label: RecoverVaultFromBip138FileUsecase.fallbackLabel,
      ),
    ).called(1);
  });

  test('a package the importer refuses leaves the vault as it was', () async {
    when(() => vaults.listRecords()).thenAnswer((_) async => Ok([record]));
    when(
      () => vaults.restoreFromRecoveryPackage(
        source: any(named: 'source'),
        label: any(named: 'label'),
      ),
    ).thenAnswer((_) async => const Err(BullVaultInvalidRecoveryFailure()));

    final outcome = await openArtifact.importDescriptor(
      descriptor: policy.descriptor,
      network: policy.network,
      recoveryPackage: '{"package":"refused"}',
    );

    expect(outcome.status, VaultRecoveryStatus.alreadyPresent);
    expect(outcome.walletId, record.walletId);
  });

  test('a bare descriptor adds nothing to a vault already here', () async {
    when(() => vaults.listRecords()).thenAnswer((_) async => Ok([record]));

    final outcome = await openArtifact.importDescriptor(
      descriptor: policy.descriptor,
      network: policy.network,
    );

    expect(outcome.status, VaultRecoveryStatus.alreadyPresent);
    verifyNever(
      () => vaults.restoreFromDescriptor(
        source: any(named: 'source'),
        label: any(named: 'label'),
      ),
    );
  });

  test('a descriptor the vault feature refuses is reported as such', () async {
    when(
      () => vaults.restoreFromDescriptor(
        source: any(named: 'source'),
        label: any(named: 'label'),
      ),
    ).thenAnswer((_) async => const Err(BullVaultInvalidRecoveryFailure()));
    answerLookup([artifact.bytes]);

    final result = await recover.execute(artifact.recipients.first);

    expect(
      (result as Ok<VaultRecoveryResult, BackupSettingsFailure>)
          .value
          .outcomes
          .single
          .status,
      VaultRecoveryStatus.unsupported,
    );
  });

  test('a search that did not finish says so', () async {
    answerLookup([artifact.bytes], incomplete: true);

    final result = await recover.execute(artifact.recipients.first);

    final value =
        (result as Ok<VaultRecoveryResult, BackupSettingsFailure>).value;
    expect(value.incomplete, isTrue);
    expect(value.recovered, hasLength(1));
  });

  test('a server refusal is a failure, never an empty search', () async {
    when(() => metadata.lookupPrivateDescriptors(any())).thenAnswer(
      (_) async => const Err(WalletBackupInvalidAccountKeyFailure()),
    );

    // Text that is not an account key now has its own message, because C10's
    // entry screen is where someone types one and has to be told what is wrong.
    expect(
      await recover.execute('not a key'),
      isA<Err<VaultRecoveryResult, BackupSettingsFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<BackupSettingsInvalidAccountKeyFailure>(),
      ),
    );
  });

  test('the file route never touches the network', () async {
    final offline = RecoverVaultsFromCosignerKeyUsecase(
      _OfflineMetadata(),
      openArtifact,
    );
    expect(
      () => offline.execute(artifact.recipients.first),
      throwsStateError,
      reason: 'a lookup is the only thing that should reach out',
    );

    final outcome = await openArtifact.execute(
      fileBytes: Uint8List.fromList(artifact.bytes),
      accountKeyInput: artifact.recipients.last,
    );
    expect(outcome.status, VaultRecoveryStatus.imported);
  });

  test('an empty or oversized file is refused before any work', () async {
    for (final bytes in [
      Uint8List(0),
      Uint8List(RecoverVaultFromBip138FileUsecase.maximumFileBytes + 1),
    ]) {
      final outcome = await openArtifact.execute(
        fileBytes: bytes,
        accountKeyInput: artifact.recipients.first,
      );
      expect(outcome.status, VaultRecoveryStatus.undecryptable);
    }
    verifyNever(
      () => vaults.decodePrivateDescriptorBackup(
        bytes: any(named: 'bytes'),
        accountKeyInput: any(named: 'accountKeyInput'),
      ),
    );
  });

  test('the exported file is the artifact under one extension', () async {
    when(
      () => vaults.encodePrivateDescriptorBackup(record.walletId),
    ).thenAnswer((_) async => Ok(artifact));
    when(() => files.save(any())).thenAnswer((_) async => const Ok(true));

    expect(
      await ExportPrivateDescriptorFileUsecase(
        vaults,
        files,
      ).execute(record.walletId),
      isA<Ok<bool, BackupSettingsFailure>>(),
    );
    final saved =
        verify(() => files.save(captureAny())).captured.single
            as WalletBackupExport;
    expect(saved.suggestedFilename, endsWith('.bip138'));
    expect(saved.copyBytes(), artifact.bytes);
  });

  test('a vault that cannot be sealed produces no file', () async {
    when(() => vaults.encodePrivateDescriptorBackup(any())).thenAnswer(
      (_) async => const Err(BullVaultDescriptorBackupUnsupportedFailure()),
    );

    expect(
      await ExportPrivateDescriptorFileUsecase(
        vaults,
        files,
      ).execute(record.walletId),
      isA<Err<bool, BackupSettingsFailure>>(),
    );
    verifyNever(() => files.save(any()));
  });
}
