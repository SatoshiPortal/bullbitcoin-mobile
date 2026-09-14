import 'dart:async';
import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vault_from_bip138_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_from_backup_words_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_from_cosigner_key_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_result.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../bullvault/bullvault_test_fixture.dart';

class _Vaults extends Mock implements BullVaultFacade {}

class _Metadata extends Mock implements WalletBackupFacade {}

class _Identity extends Mock implements NostrIdentityFacade {}

class _Files extends Mock implements WalletBackupFileRepository {}

final class _Parser extends Fake implements BitcoinDescriptorPort {
  @override
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  }) => parseTestBullVaultDescriptor(descriptor: descriptor, network: network);
}

void main() {
  final record = testBullVaultCreateResult().record;
  final policy = record.recoveryPackage.policy;
  final otherRecord = testBullVaultCreateResult(
    includesInheritance: true,
  ).record;
  final otherPolicy = otherRecord.recoveryPackage.policy;

  late _Vaults vaults;
  late _Metadata metadata;
  late _Identity identity;
  late VaultRecoveryCubit cubit;
  late List<BullVaultRecord> present;
  late int imports;

  WalletBackupVaultSummary summaryOf(BullVaultRecord source) =>
      WalletBackupVaultSummary(
        walletRef: source.walletId,
        status: 'active',
        network: source.recoveryPackage.policy.network,
        lineageId: source.recoveryPackage.policy.lineageId,
        vaultGeneration: 0,
        descriptor: source.recoveryPackage.policy.descriptor,
        birthHeight: null,
        recoveryPackage: '{}',
      );

  NostrDescriptorRecord relayRecord(String descriptor, Network network) =>
      NostrDescriptorRecord(
        descriptor: descriptor,
        network: network,
        createdAt: DateTime.utc(2027),
      );

  /// Imports really change what the device holds, which is what lets the
  /// second sighting of one vault be reported as already present.
  void importsInto(BullVaultRecord source) {
    when(
      () => vaults.restoreFromDescriptor(
        source: any(named: 'source'),
        label: any(named: 'label'),
      ),
    ).thenAnswer((_) async {
      imports++;
      present = [...present, source];
      return Ok(
        BullVaultRestoreResult(
          wallet: Wallet(
            origin: source.walletId,
            network: source.recoveryPackage.policy.network,
            signers: const [],
            scriptType: null,
            publicDescriptor: source.recoveryPackage.policy.descriptor,
            balanceSat: BigInt.zero,
            isHidden: true,
          ),
          record: source,
          mobileAccess: BullVaultMobileAccess.unavailable,
        ),
      );
    });
    when(
      () => vaults.restoreFromRecoveryPackage(
        source: any(named: 'source'),
        label: any(named: 'label'),
      ),
    ).thenAnswer((_) async {
      imports++;
      present = [...present, source];
      return Ok(
        BullVaultRestoreResult(
          wallet: Wallet(
            origin: source.walletId,
            network: source.recoveryPackage.policy.network,
            signers: const [],
            scriptType: null,
            publicDescriptor: source.recoveryPackage.policy.descriptor,
            balanceSat: BigInt.zero,
            isHidden: true,
          ),
          record: source,
          mobileAccess: BullVaultMobileAccess.unavailable,
        ),
      );
    });
  }

  setUp(() {
    vaults = _Vaults();
    metadata = _Metadata();
    identity = _Identity();
    present = [];
    imports = 0;
    when(() => vaults.listRecords()).thenAnswer((_) async => Ok(present));
    when(
      () => identity.walletBackupPublicKey(),
    ).thenAnswer((_) async => Ok('a' * 64));
    final artifact = RecoverVaultFromBip138FileUsecase(
      vaults,
      _Parser(),
      _Files(),
    );
    cubit = VaultRecoveryCubit(
      RecoverVaultsFromBackupWordsUsecase(metadata, vaults, identity, artifact),
      RecoverVaultsFromCosignerKeyUsecase(metadata, artifact),
      artifact,
    );
    addTearDown(cubit.close);
  });

  test(
    'a device with no seed searches nothing and keeps manual entries',
    () async {
      when(
        () => identity.walletBackupPublicKey(),
      ).thenAnswer((_) async => const Err(NostrIdentityUnavailableFailure()));

      await cubit.discover();

      expect(cubit.state.credentialAvailable, isFalse);
      expect(cubit.state.searched, isFalse);
      verifyNever(() => metadata.fetchRemoteContents());
      verifyNever(
        () => vaults.discoverDescriptorsOnNostr(
          words: any(named: 'words'),
          session: any(named: 'session'),
        ),
      );
    },
  );

  test('an unreachable server never stops the relay search', () async {
    when(() => metadata.fetchRemoteContents()).thenAnswer(
      (_) async => const Err(WalletBackupRemoteUnavailableFailure()),
    );
    when(
      () => vaults.discoverDescriptorsOnNostr(
        words: any(named: 'words'),
        session: any(named: 'session'),
      ),
    ).thenAnswer(
      (_) async => Ok((
        descriptors: [relayRecord(policy.descriptor, policy.network)],
        incomplete: false,
      )),
    );
    importsInto(record);

    await cubit.discover();

    expect(
      cubit.state.sources[VaultRecoverySource.dataBackup],
      VaultRecoverySourceStatus.unavailable,
    );
    expect(
      cubit.state.sources[VaultRecoverySource.nostr],
      VaultRecoverySourceStatus.found,
    );
    expect(imports, 1);
  });

  test('both sources run and one vault is imported once', () async {
    when(() => metadata.fetchRemoteContents()).thenAnswer(
      (_) async => Ok(
        WalletBackupContents(
          vaults: [summaryOf(record)],
          labelCount: 0,
          frozenCoinCount: 0,
          walletPreferenceCount: 0,
        ),
      ),
    );
    when(
      () => vaults.discoverDescriptorsOnNostr(
        words: any(named: 'words'),
        session: any(named: 'session'),
      ),
    ).thenAnswer(
      (_) async => Ok((
        descriptors: [relayRecord(policy.descriptor, policy.network)],
        incomplete: false,
      )),
    );
    importsInto(record);

    await cubit.discover();

    expect(imports, 1);
    expect(cubit.state.outcomes.map((outcome) => outcome.status), [
      VaultRecoveryStatus.imported,
      VaultRecoveryStatus.alreadyPresent,
    ]);
    expect(
      cubit.state.sources[VaultRecoverySource.dataBackup],
      VaultRecoverySourceStatus.found,
    );
    expect(
      cubit.state.sources[VaultRecoverySource.nostr],
      VaultRecoverySourceStatus.found,
    );
  });

  test('an unfinished relay search is not an empty one', () async {
    when(
      () => metadata.fetchRemoteContents(),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => vaults.discoverDescriptorsOnNostr(
        words: any(named: 'words'),
        session: any(named: 'session'),
      ),
    ).thenAnswer(
      (_) async =>
          const Ok((descriptors: <NostrDescriptorRecord>[], incomplete: true)),
    );

    await cubit.discover();

    expect(
      cubit.state.sources[VaultRecoverySource.dataBackup],
      VaultRecoverySourceStatus.none,
    );
    expect(
      cubit.state.sources[VaultRecoverySource.nostr],
      VaultRecoverySourceStatus.incomplete,
    );
  });

  test('a hit does not erase an unfinished search', () async {
    when(
      () => metadata.fetchRemoteContents(),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => vaults.discoverDescriptorsOnNostr(
        words: any(named: 'words'),
        session: any(named: 'session'),
      ),
    ).thenAnswer(
      (_) async => Ok((
        descriptors: [relayRecord(policy.descriptor, policy.network)],
        incomplete: true,
      )),
    );
    importsInto(record);

    await cubit.discover();

    expect(
      cubit.state.sources[VaultRecoverySource.nostr],
      VaultRecoverySourceStatus.incomplete,
      reason: 'other generations may still be out there, unseen',
    );
    expect(cubit.state.recovered, hasLength(1));
  });

  test('bitcoin is never searched', () async {
    when(
      () => metadata.fetchRemoteContents(),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => vaults.discoverDescriptorsOnNostr(
        words: any(named: 'words'),
        session: any(named: 'session'),
      ),
    ).thenAnswer(
      (_) async =>
          const Ok((descriptors: <NostrDescriptorRecord>[], incomplete: false)),
    );

    await cubit.discover();

    expect(
      cubit.state.sources[VaultRecoverySource.bitcoin],
      VaultRecoverySourceStatus.idle,
    );
  });

  test('a response that lands after the journey closed imports '
      'nothing', () async {
    final started = Completer<void>();
    final arrived = Completer<void>();
    when(() => metadata.fetchRemoteContents()).thenAnswer((_) async {
      if (!started.isCompleted) started.complete();
      await arrived.future;
      return Ok(
        WalletBackupContents(
          vaults: [summaryOf(record)],
          labelCount: 0,
          frozenCoinCount: 0,
          walletPreferenceCount: 0,
        ),
      );
    });
    when(
      () => vaults.discoverDescriptorsOnNostr(
        words: any(named: 'words'),
        session: any(named: 'session'),
      ),
    ).thenAnswer(
      (_) async =>
          const Ok((descriptors: <NostrDescriptorRecord>[], incomplete: false)),
    );
    importsInto(record);

    final running = cubit.discover();
    await started.future;
    await cubit.close();
    arrived.complete();
    await running;

    expect(imports, 0, reason: 'the person left before anything was written');
  });

  test(
    'closing between two imports stops at the one already written',
    () async {
      final started = Completer<void>();
      final arrived = Completer<void>();
      when(() => metadata.fetchRemoteContents()).thenAnswer(
        (_) async => Ok(
          WalletBackupContents(
            vaults: [summaryOf(record), summaryOf(otherRecord)],
            labelCount: 0,
            frozenCoinCount: 0,
            walletPreferenceCount: 0,
          ),
        ),
      );
      when(
        () => vaults.discoverDescriptorsOnNostr(
          words: any(named: 'words'),
          session: any(named: 'session'),
        ),
      ).thenAnswer(
        (_) async => const Ok((
          descriptors: <NostrDescriptorRecord>[],
          incomplete: false,
        )),
      );
      when(
        () => vaults.restoreFromRecoveryPackage(
          source: any(named: 'source'),
          label: any(named: 'label'),
        ),
      ).thenAnswer((_) async {
        imports++;
        if (!started.isCompleted) started.complete();
        await arrived.future;
        present = [...present, record];
        return Ok(
          BullVaultRestoreResult(
            wallet: Wallet(
              origin: record.walletId,
              network: record.recoveryPackage.policy.network,
              signers: const [],
              scriptType: null,
              publicDescriptor: record.recoveryPackage.policy.descriptor,
              balanceSat: BigInt.zero,
              isHidden: true,
            ),
            record: record,
            mobileAccess: BullVaultMobileAccess.unavailable,
          ),
        );
      });

      final running = cubit.discover();
      await started.future;
      await cubit.close();
      arrived.complete();
      await running;

      expect(imports, 1, reason: 'the second import never started');
    },
  );

  test('closing the journey cancels the relay search it started', () async {
    NostrSession? handed;
    when(
      () => metadata.fetchRemoteContents(),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => vaults.discoverDescriptorsOnNostr(
        words: any(named: 'words'),
        session: any(named: 'session'),
      ),
    ).thenAnswer((call) async {
      handed = call.namedArguments[#session] as NostrSession?;
      return const Ok((
        descriptors: <NostrDescriptorRecord>[],
        incomplete: true,
      ));
    });

    await cubit.discover();
    expect(handed, isNotNull);
    expect(handed!.isCancelled, isFalse);

    await cubit.close();

    expect(handed!.isCancelled, isTrue);
  });

  test('words search both sources and import only validated vaults', () async {
    when(() => metadata.fetchVaultsWithBackupWords(any())).thenAnswer(
      (_) async => Ok(
        WalletBackupWordsExtraction(
          vaults: [summaryOf(otherRecord)],
          parentFingerprint: 'deadbeef',
        ),
      ),
    );
    when(
      () => vaults.discoverDescriptorsOnNostr(
        words: any(named: 'words'),
        session: any(named: 'session'),
      ),
    ).thenAnswer(
      (_) async =>
          const Ok((descriptors: <NostrDescriptorRecord>[], incomplete: false)),
    );
    importsInto(otherRecord);

    await cubit.searchWithWords('abandon ' * 11 + 'about');

    expect(imports, 1);
    verify(() => metadata.fetchVaultsWithBackupWords(any())).called(1);
    verifyNever(() => metadata.fetchRemoteContents());
    expect(
      cubit.state.sources[VaultRecoverySource.nostr],
      VaultRecoverySourceStatus.none,
    );
    expect(otherPolicy.descriptor, isNotEmpty);
  });

  test('malformed backup words never reach a server or a relay', () async {
    when(
      () => vaults.discoverDescriptorsOnNostr(
        words: any(named: 'words'),
        session: any(named: 'session'),
      ),
    ).thenAnswer((_) async => const Err(BullVaultBackupWordsFailure()));
    when(() => metadata.fetchVaultsWithBackupWords(any())).thenAnswer(
      (_) async => const Err(WalletBackupInvalidBackupWordsFailure()),
    );

    await cubit.searchWithWords('not the words');

    expect(cubit.state.failure, isA<BackupSettingsFailure>());
    expect(imports, 0);
  });
}
