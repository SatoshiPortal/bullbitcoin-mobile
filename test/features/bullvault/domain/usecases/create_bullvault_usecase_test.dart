import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bip48_account_claim.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/reserve_bip48_account_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/set_wallet_hidden_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_request.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_key_source.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_schedule.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_signer_key.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/create_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_bullvault_time_reference_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/resume_bullvault_onboarding_usecase.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../bullvault_test_fixture.dart';
import '../../../../core_test/wallet/bdk_wallet_test_fixture.dart';

const _fourthMnemonic = 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong';

class _MockGetDefaultSeedUsecase extends Mock
    implements GetDefaultSeedUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockDeleteWalletUsecase extends Mock implements DeleteWalletUsecase {}

class _MockGetWalletUsecase extends Mock implements GetWalletUsecase {}

class _MockSetWalletHiddenUsecase extends Mock
    implements SetWalletHiddenUsecase {}

class _MockReserveBip48AccountUsecase extends Mock
    implements ReserveBip48AccountUsecase {}

class _MockPrepareBullVaultTimeReferenceUsecase extends Mock
    implements PrepareBullVaultTimeReferenceUsecase {}

final class _TestBip48AccountRepository implements Bip48AccountRepository {
  final Set<int> reserved = {};
  final Map<int, String> claims = {};
  final List<String>? events;
  int commitFailuresRemaining;
  var _token = 0;

  _TestBip48AccountRepository({this.events, this.commitFailuresRemaining = 0});

  int get _next {
    var account = 0;
    while (reserved.contains(account) || claims.containsKey(account)) {
      account++;
    }
    return account;
  }

  @override
  Future<Result<Bip48AccountClaim, Bip48AccountAllocationFailure>> claim({
    required String seedFingerprint,
    required int coinType,
    required int account,
  }) async {
    if (reserved.contains(account) || claims.containsKey(account)) {
      return const Err(Bip48AccountAllocationFailure());
    }
    final token = 'claim-${_token++}';
    claims[account] = token;
    events?.add('claim');
    return Ok(Bip48AccountClaim(account: account, token: token));
  }

  @override
  Future<Result<Bip48AccountClaim, Bip48AccountAllocationFailure>> claimNext({
    required String seedFingerprint,
    required int coinType,
  }) async {
    final account = _next;
    final token = 'claim-${_token++}';
    claims[account] = token;
    events?.add('claim');
    return Ok(Bip48AccountClaim(account: account, token: token));
  }

  @override
  Future<Result<void, Bip48AccountAllocationFailure>> commitClaim({
    required String seedFingerprint,
    required int coinType,
    required Bip48AccountClaim claim,
  }) async {
    if (commitFailuresRemaining > 0) {
      commitFailuresRemaining--;
      return const Err(Bip48AccountAllocationFailure());
    }
    if (claims[claim.account] != claim.token) {
      return const Err(Bip48AccountAllocationFailure());
    }
    claims.remove(claim.account);
    reserved.add(claim.account);
    events?.add('commit');
    return const Ok(null);
  }

  @override
  Future<Result<void, Bip48AccountAllocationFailure>> releaseClaim({
    required String seedFingerprint,
    required int coinType,
    required Bip48AccountClaim claim,
  }) async {
    if (claims[claim.account] == claim.token) claims.remove(claim.account);
    events?.add('release');
    return const Ok(null);
  }

  @override
  Future<Result<bool, Bip48AccountAllocationFailure>> isReserved({
    required String seedFingerprint,
    required int coinType,
    required int account,
  }) async => Ok(reserved.contains(account));

  @override
  Future<Result<int, Bip48AccountAllocationFailure>> nextAvailable({
    required String seedFingerprint,
    required int coinType,
  }) async => Ok(_next);

  @override
  Future<Result<void, Bip48AccountAllocationFailure>> reserve({
    required String seedFingerprint,
    required int coinType,
    required int account,
  }) async {
    reserved.add(account);
    return const Ok(null);
  }
}

final class _ParsingDescriptorPort implements BitcoinDescriptorPort {
  @override
  ({
    String descriptor,
    ScriptType? scriptType,
    List<WalletDescriptorKey> descriptorKeys,
    bool inferredChangePath,
  })
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  }) => parseTestBullVaultDescriptor(descriptor: descriptor, network: network);

  @override
  ({List<WalletDescriptorKey> policyKeys, bool hasUnspendablePolicyKey})
  analyzeBitcoinPolicyDescriptor({
    required String descriptor,
    required Network network,
  }) => throw UnimplementedError();

  @override
  Future<Wallet> importDescriptor({
    required String descriptor,
    required Network network,
    required String label,
    List<WalletSigner> signers = const [],
    bool isHidden = false,
    bool sync = false,
  }) async => Wallet(
    origin: 'bullvault-wallet',
    label: label,
    network: network,
    signers: signers,
    scriptType: null,
    publicDescriptor: descriptor,
    balanceSat: BigInt.zero,
    isHidden: isHidden,
  );
}

final class _SequentialDescriptorPort implements BitcoinDescriptorPort {
  final _parser = _ParsingDescriptorPort();
  var _importCount = 0;

  @override
  ({
    String descriptor,
    ScriptType? scriptType,
    List<WalletDescriptorKey> descriptorKeys,
    bool inferredChangePath,
  })
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  }) =>
      _parser.parseBitcoinDescriptor(descriptor: descriptor, network: network);

  @override
  ({List<WalletDescriptorKey> policyKeys, bool hasUnspendablePolicyKey})
  analyzeBitcoinPolicyDescriptor({
    required String descriptor,
    required Network network,
  }) => throw UnimplementedError();

  @override
  Future<Wallet> importDescriptor({
    required String descriptor,
    required Network network,
    required String label,
    List<WalletSigner> signers = const [],
    bool isHidden = false,
    bool sync = false,
  }) async => Wallet(
    origin: 'bullvault-wallet-${_importCount++}',
    label: label,
    network: network,
    signers: signers,
    scriptType: null,
    publicDescriptor: descriptor,
    balanceSat: BigInt.zero,
    isHidden: isHidden,
  );
}

final class _TestBullVaultRepository implements BullVaultRepository {
  BullVaultRecord? savedRecord;
  final List<String> events = [];

  @override
  Result<BullVaultRecoveryPackage, BullVaultFailure> decodeRecoveryPackage(
    String source,
  ) => throw UnimplementedError();

  @override
  String encodeRecoveryPackage(BullVaultRecoveryPackage recoveryPackage) =>
      throw UnimplementedError();

  @override
  Future<Result<void, BullVaultFailure>> activateRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord replacement,
  }) => throw UnimplementedError();

  @override
  Future<Result<void, BullVaultFailure>> linkRestoredRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord successor,
  }) => throw UnimplementedError();

  @override
  Future<Result<void, BullVaultFailure>> cancelRenewal({
    required String previousWalletId,
    required String replacementWalletId,
  }) => throw UnimplementedError();

  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getByWalletId(
    String walletId,
  ) async => Ok(savedRecord?.walletId == walletId ? savedRecord : null);

  @override
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> getLineage(
    String lineageId,
  ) => throw UnimplementedError();

  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getIncompleteInitial(
    Network network,
  ) async => Ok(savedRecord);

  @override
  Future<Result<int, BullVaultFailure>> reserveNextGeneration(
    BullVaultRecord current,
  ) => throw UnimplementedError();

  @override
  Future<Result<void, BullVaultFailure>> releaseGeneration({
    required String lineageId,
    required int generation,
  }) => throw UnimplementedError();

  @override
  Future<Result<void, BullVaultFailure>> save(BullVaultRecord record) async {
    events.add('save');
    savedRecord = record;
    return const Ok(null);
  }

  @override
  Future<Result<void, BullVaultFailure>> delete(String walletId) async {
    if (savedRecord?.walletId == walletId) savedRecord = null;
    return const Ok(null);
  }
}

void main() {
  late _MockGetSettingsUsecase getSettings;

  setUp(() {
    getSettings = _MockGetSettingsUsecase();
    when(getSettings.execute).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
  });

  test('uses the reviewed time reference after a fresh chain check', () async {
    final repository = _TestBullVaultRepository();
    final cold = deriveSignerKeys(testMnemonics[1]);
    final prepare = _MockPrepareBullVaultTimeReferenceUsecase();
    final reviewed = _timeReference();
    when(() => prepare.execute(isTestnet: true)).thenAnswer(
      (_) async => Ok(
        BullVaultTimeReference(
          deviceTime: reviewed.deviceTime.add(const Duration(minutes: 5)),
          chainHeight: reviewed.chainHeight + 1,
          medianTimePast: reviewed.medianTimePast + 300,
        ),
      ),
    );
    final usecase = _usecase(
      repository,
      getSettings,
      prepareTimeReferenceUsecase: prepare,
    );

    final result = await usecase.execute(
      BullVaultCreateRequest(
        label: 'BullVault',
        protection: BullVaultProtection.standard,
        cold: BullVaultSignerRequest(
          input: cold.xpub,
          device: SignerDeviceEntity.ledgerNanoX,
        ),
        secondCold: null,
        inheritance: null,
        schedule: BullVaultSchedule.standardWithoutInheritance,
        timeReference: reviewed,
      ),
    );

    final created =
        (result as Ok<BullVaultCreateResult, BullVaultFailure>).value;
    expect(created.policy.birthHeight, reviewed.chainHeight);
    expect(created.policy.referenceTimestamp, reviewed.deviceTimestamp);
    expect(
      created.policy.coldActivationTimestamp,
      BullVaultSchedule.standardWithoutInheritance.coldActivationTimestamp(
        reviewed.deviceTime,
      ),
    );
    expect(
      created.policy.recoveryActivationTimestamp,
      BullVaultSchedule.standardWithoutInheritance.recoveryActivationTimestamp(
        reviewed.deviceTime,
      ),
    );
    expect(created.policy.inheritanceActivationTimestamp, isNull);
    expect(created.wallet.signers, hasLength(2));
    expect(
      created.wallet.signers.map((signer) => signer.descriptorKeys.length),
      everyElement(2),
    );
    expect(repository.savedRecord?.birthHeight, 3_000_000);
    expect(created.policy.vaultGeneration, 0);
    expect(created.policy.lineageId, created.policy.id);
    expect(repository.savedRecord?.lineageId, created.policy.lineageId);
    expect(repository.savedRecord?.vaultGeneration, 0);
    expect(repository.savedRecord?.status, BullVaultLifecycleStatus.pending);
    expect(created.wallet.isHidden, isTrue);
    expect(
      repository
          .savedRecord
          ?.recoveryPackage
          .policy
          .recoveryActivationTimestamp,
      created.policy.recoveryActivationTimestamp,
    );

    final getWallet = _MockGetWalletUsecase();
    final setHidden = _MockSetWalletHiddenUsecase();
    when(
      () => getWallet.execute(created.wallet.id),
    ).thenAnswer((_) async => created.wallet);
    final reserveAccount = _MockReserveBip48AccountUsecase();
    when(
      () => reserveAccount.execute(
        seedFingerprint: any(named: 'seedFingerprint'),
        coinType: any(named: 'coinType'),
        account: any(named: 'account'),
      ),
    ).thenAnswer((_) async => const Ok(0));
    final resume = ResumeBullVaultOnboardingUsecase(
      repository,
      getWallet,
      setHidden,
      reserveAccount,
    );

    final resumed = await resume.execute(Network.bitcoinTestnet);

    expect(resumed, isA<Ok<BullVaultCreateResult?, BullVaultFailure>>());
    expect(
      (resumed as Ok<BullVaultCreateResult?, BullVaultFailure>)
          .value
          ?.wallet
          .id,
      created.wallet.id,
    );

    repository.savedRecord = created.record.copyWith(
      status: BullVaultLifecycleStatus.active,
    );
    final resumedActive = await resume.execute(
      Network.bitcoinTestnet,
      walletId: created.wallet.id,
    );
    expect(
      (resumedActive as Ok<BullVaultCreateResult?, BullVaultFailure>)
          .value
          ?.record
          .status,
      BullVaultLifecycleStatus.active,
    );
  });

  test(
    'rejects a stale recovery-date review before claiming an account',
    () async {
      final repository = _TestBullVaultRepository();
      final accounts = _TestBip48AccountRepository();
      final cold = deriveSignerKeys(testMnemonics[1]);
      final current = _timeReference();
      final usecase = _usecase(
        repository,
        getSettings,
        accountRepository: accounts,
      );
      final stale = BullVaultTimeReference(
        deviceTime: current.deviceTime.subtract(const Duration(hours: 1)),
        chainHeight: current.chainHeight - 6,
        medianTimePast: current.medianTimePast - 3600,
      );

      final result = await usecase.execute(
        BullVaultCreateRequest(
          label: 'BullVault',
          protection: BullVaultProtection.standard,
          cold: BullVaultSignerRequest(
            input: cold.xpub,
            device: SignerDeviceEntity.ledgerNanoX,
          ),
          secondCold: null,
          inheritance: null,
          schedule: BullVaultSchedule.standardWithoutInheritance,
          timeReference: stale,
        ),
      );

      expect(
        (result as Err<BullVaultCreateResult, BullVaultFailure>).failure,
        isA<BullVaultReviewExpiredFailure>(),
      );
      expect(accounts.claims, isEmpty);
      expect(accounts.reserved, isEmpty);
    },
  );

  test('allows only one incomplete initial BullVault', () async {
    final repository = _TestBullVaultRepository();
    final accounts = _TestBip48AccountRepository();
    final usecase = _usecase(
      repository,
      getSettings,
      descriptorPort: _SequentialDescriptorPort(),
      accountRepository: accounts,
    );
    final cold = deriveSignerKeys(testMnemonics[1]);
    final request = BullVaultCreateRequest(
      label: 'BullVault',
      protection: BullVaultProtection.standard,
      cold: BullVaultSignerRequest(
        input: cold.xpub,
        device: SignerDeviceEntity.ledgerNanoX,
      ),
      secondCold: null,
      inheritance: null,
      schedule: BullVaultSchedule.standardWithoutInheritance,
      timeReference: _timeReference(),
    );

    final results = await Future.wait([
      usecase.execute(request),
      usecase.execute(request),
    ]);

    expect(
      results.whereType<Ok<BullVaultCreateResult, BullVaultFailure>>(),
      hasLength(1),
    );
    expect(
      results.whereType<Err<BullVaultCreateResult, BullVaultFailure>>(),
      hasLength(1),
    );
    expect(accounts.reserved, {0});
    expect(accounts.claims, isEmpty);
  });

  test('creates extra protection with two cold keys and inheritance', () async {
    final repository = _TestBullVaultRepository();
    final cold = deriveSignerKeys(testMnemonics[1]);
    final secondCold = deriveSignerKeys(testMnemonics[2]);
    final inheritance = deriveSignerKeys(_fourthMnemonic);

    final result = await _usecase(repository, getSettings).execute(
      BullVaultCreateRequest(
        label: 'BullVault',
        protection: BullVaultProtection.extra,
        cold: BullVaultSignerRequest(
          input: cold.xpub,
          device: SignerDeviceEntity.ledgerNanoX,
        ),
        secondCold: BullVaultSignerRequest(
          input: secondCold.xpub,
          device: SignerDeviceEntity.krux,
        ),
        inheritance: BullVaultSignerRequest(
          input: inheritance.xpub,
          device: null,
          genericExternal: true,
          requiresHardwareSetup: false,
        ),
        schedule: BullVaultSchedule.extraWithInheritance,
        timeReference: _timeReference(),
      ),
    );

    final created =
        (result as Ok<BullVaultCreateResult, BullVaultFailure>).value;
    expect(created.policy.protection, BullVaultProtection.extra);
    expect(created.policy.secondColdKey, isNotNull);
    expect(created.policy.coldActivationTimestamp, isNull);
    expect(created.policy.recoveryActivationTimestamp, isNotNull);
    expect(created.policy.inheritanceActivationTimestamp, isNotNull);
    expect(created.policy.inheritanceKey?.signerDevice, isNull);
    expect(created.policy.inheritanceKey?.signer, SignerEntity.none);
    expect(created.wallet.signers, hasLength(4));
    expect(
      created.wallet.signers.map((signer) => signer.descriptorKeys.length),
      everyElement(2),
    );
    expect(created.policy.descriptor, contains('multi_a(2,'));
    expect(
      repository.savedRecord?.recoveryPackage.policy.protection,
      BullVaultProtection.extra,
    );
  });

  test(
    'uses a hardware everyday key without reserving a Bull account',
    () async {
      final repository = _TestBullVaultRepository();
      final accounts = _TestBip48AccountRepository();
      final everyday = deriveSignerKeys(testMnemonics.first);
      final cold = deriveSignerKeys(testMnemonics[1]);

      final result =
          await _usecase(
            repository,
            getSettings,
            accountRepository: accounts,
          ).execute(
            BullVaultCreateRequest(
              label: 'BullVault',
              protection: BullVaultProtection.standard,
              everydayKeySource: BullVaultEverydayKeySource.hardware,
              everydayHardware: BullVaultSignerRequest(
                input: everyday.xpub,
                device: SignerDeviceEntity.bitbox02,
              ),
              cold: BullVaultSignerRequest(
                input: cold.xpub,
                device: SignerDeviceEntity.ledgerNanoX,
              ),
              secondCold: null,
              inheritance: null,
              schedule: BullVaultSchedule.standardWithoutInheritance,
              timeReference: _timeReference(),
            ),
          );

      final created =
          (result as Ok<BullVaultCreateResult, BullVaultFailure>).value;
      expect(created.record.mobileAccount, isNull);
      expect(created.record.mobileSeedFingerprint, isNull);
      expect(created.policy.everydayKey.signer, SignerEntity.remote);
      expect(accounts.claims, isEmpty);
      expect(accounts.reserved, isEmpty);
    },
  );

  test(
    'keeps passphrase-free recovery outside the immediate threshold',
    () async {
      final repository = _TestBullVaultRepository();
      final getDefaultSeed = _MockGetDefaultSeedUsecase();
      final mnemonic = bip39.Mnemonic.fromWords(
        words: testMnemonics.first.split(' '),
      );
      final seedBytes = Uint8List.fromList(mnemonic.seed);
      when(
        () => getDefaultSeed.execute(environment: Environment.testnet),
      ).thenAnswer(
        (_) async => Seed.mnemonic(
          mnemonicWords: mnemonic.words,
          bytes: seedBytes,
          masterFingerprint: bip32.Bip32Keys.fromSeed(seedBytes).fingerprintHex,
        ),
      );
      final cold = deriveSignerKeys(testMnemonics[1]);

      final result =
          await _usecase(
            repository,
            getSettings,
            getDefaultSeed: getDefaultSeed,
          ).execute(
            BullVaultCreateRequest(
              label: 'BullVault',
              protection: BullVaultProtection.standard,
              mobilePassphrase: 'vault passphrase',
              passphraseFreeRecovery: true,
              cold: BullVaultSignerRequest(
                input: cold.xpub,
                device: SignerDeviceEntity.ledgerNanoX,
              ),
              secondCold: null,
              inheritance: null,
              schedule: BullVaultSchedule.standardWithoutInheritance,
              timeReference: _timeReference(),
            ),
          );

      final created =
          (result as Ok<BullVaultCreateResult, BullVaultFailure>).value;
      final everyday = created.policy.everydayKey;
      final recovery = created.policy.delayedMobileRecoveryKey!;
      final coldKey = created.policy.coldKey;
      expect(everyday.accountKey.xpub, isNot(recovery.accountKey.xpub));
      expect(
        everyday.accountKey.derivationPath,
        recovery.accountKey.derivationPath,
      );
      expect(everyday.accountKey.requiresPassphrase, isTrue);
      expect(recovery.accountKey.requiresPassphrase, isFalse);
      expect(
        created.policy.descriptor,
        contains(
          'multi_a(2,${everyday.expression(receiveBranch: 0, changeBranch: 1)},${coldKey.expression(receiveBranch: 0, changeBranch: 1)})',
        ),
      );
      expect(
        created.policy.descriptor,
        contains(
          'pk(${recovery.expression(receiveBranch: 0, changeBranch: 1)})',
        ),
      );
      final mobileSigner = created.wallet.signers.singleWhere(
        (signer) => signer.id == BullVaultSignerRole.everyday.name,
      );
      expect(mobileSigner.descriptorKeys.map((key) => key.xpub).toSet(), {
        everyday.accountKey.xpub,
        recovery.accountKey.xpub,
      });
      expect(created.record.mobileAccount, 0);
    },
  );

  test('creates a mainnet policy from mainnet account keys', () async {
    final repository = _TestBullVaultRepository();
    when(getSettings.execute).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );

    final cold = deriveSignerKeys(testMnemonics[1], isTestnet: false);
    final getDefaultSeed = _MockGetDefaultSeedUsecase();
    when(
      () => getDefaultSeed.execute(environment: Environment.mainnet),
    ).thenAnswer(
      (_) async => Seed.bytes(
        bytes: Uint8List.fromList(List<int>.generate(64, (index) => index)),
        masterFingerprint: 'deadbeef',
      ),
    );
    final result =
        await _usecase(
          repository,
          getSettings,
          getDefaultSeed: getDefaultSeed,
        ).execute(
          BullVaultCreateRequest(
            label: 'BullVault',
            protection: BullVaultProtection.standard,
            cold: BullVaultSignerRequest(
              input: cold.xpub,
              device: SignerDeviceEntity.ledgerNanoX,
            ),
            secondCold: null,
            inheritance: null,
            schedule: BullVaultSchedule.standardWithoutInheritance,
            timeReference: _timeReference(isMainnet: true),
          ),
        );

    final created =
        (result as Ok<BullVaultCreateResult, BullVaultFailure>).value;
    expect(created.wallet.network, Network.bitcoinMainnet);
    expect(created.policy.network, Network.bitcoinMainnet);
    expect(created.policy.birthHeight, 900_000);
    expect(created.policy.descriptor, contains('xpub'));
    expect(created.policy.descriptor, isNot(contains('tpub')));
    expect(created.record.mobileAccount, 0);
    expect(
      created.policy.everydayKey.accountKey.derivationPath,
      contains("/0'/"),
    );
    verify(
      () => getDefaultSeed.execute(environment: Environment.mainnet),
    ).called(1);
    expect(repository.savedRecord, isNotNull);
  });

  test(
    'commits the mobile account after BullVault creation is saved',
    () async {
      final repository = _TestBullVaultRepository();
      final getDefaultSeed = _MockGetDefaultSeedUsecase();
      final accounts = _TestBip48AccountRepository(events: repository.events);
      when(
        () => getDefaultSeed.execute(environment: Environment.testnet),
      ).thenAnswer(
        (_) async => Seed.bytes(
          bytes: Uint8List.fromList(List<int>.generate(64, (index) => index)),
          masterFingerprint: 'deadbeef',
        ),
      );
      final cold = deriveSignerKeys(testMnemonics[1]);

      final result =
          await _usecase(
            repository,
            getSettings,
            getDefaultSeed: getDefaultSeed,
            accountRepository: accounts,
          ).execute(
            BullVaultCreateRequest(
              label: 'BullVault',
              protection: BullVaultProtection.standard,
              cold: BullVaultSignerRequest(
                input: cold.xpub,
                device: SignerDeviceEntity.bitbox02,
              ),
              secondCold: null,
              inheritance: null,
              schedule: BullVaultSchedule.standardWithoutInheritance,
              timeReference: _timeReference(),
            ),
          );

      expect(result, isA<Ok<BullVaultCreateResult, BullVaultFailure>>());
      expect(repository.events, ['claim', 'save', 'commit']);
    },
  );

  test(
    'releases the account when commit failure is fully rolled back',
    () async {
      final repository = _TestBullVaultRepository();
      final accounts = _TestBip48AccountRepository(commitFailuresRemaining: 1);
      final deleteWallet = _MockDeleteWalletUsecase();
      when(
        () => deleteWallet.execute(walletId: any(named: 'walletId')),
      ).thenAnswer((_) async {});
      final cold = deriveSignerKeys(testMnemonics[1]);

      final result =
          await _usecase(
            repository,
            getSettings,
            deleteWalletUsecase: deleteWallet,
            accountRepository: accounts,
          ).execute(
            BullVaultCreateRequest(
              label: 'BullVault',
              protection: BullVaultProtection.standard,
              cold: BullVaultSignerRequest(
                input: cold.xpub,
                device: SignerDeviceEntity.bitbox02,
              ),
              secondCold: null,
              inheritance: null,
              schedule: BullVaultSchedule.standardWithoutInheritance,
              timeReference: _timeReference(),
            ),
          );

      expect(result, isA<Err<BullVaultCreateResult, BullVaultFailure>>());
      expect(repository.savedRecord, isNull);
      expect(accounts.claims, isEmpty);
      expect(accounts.reserved, isEmpty);
      verify(
        () => deleteWallet.execute(walletId: 'bullvault-wallet'),
      ).called(1);
    },
  );

  test(
    'preserves the account when commit rollback cannot remove the wallet',
    () async {
      final repository = _TestBullVaultRepository();
      final accounts = _TestBip48AccountRepository(commitFailuresRemaining: 1);
      final deleteWallet = _MockDeleteWalletUsecase();
      when(
        () => deleteWallet.execute(walletId: any(named: 'walletId')),
      ).thenThrow(Exception('wallet deletion failed'));
      final cold = deriveSignerKeys(testMnemonics[1]);

      final result =
          await _usecase(
            repository,
            getSettings,
            deleteWalletUsecase: deleteWallet,
            accountRepository: accounts,
          ).execute(
            BullVaultCreateRequest(
              label: 'BullVault',
              protection: BullVaultProtection.standard,
              cold: BullVaultSignerRequest(
                input: cold.xpub,
                device: SignerDeviceEntity.bitbox02,
              ),
              secondCold: null,
              inheritance: null,
              schedule: BullVaultSchedule.standardWithoutInheritance,
              timeReference: _timeReference(),
            ),
          );

      expect(result, isA<Err<BullVaultCreateResult, BullVaultFailure>>());
      expect(repository.savedRecord, isNull);
      expect(accounts.claims, isEmpty);
      expect(accounts.reserved, {0});
    },
  );

  test('rejects invalid recovery ordering', () async {
    final repository = _TestBullVaultRepository();
    final result = await _usecase(repository, getSettings).execute(
      BullVaultCreateRequest(
        label: 'BullVault',
        protection: BullVaultProtection.standard,
        cold: BullVaultSignerRequest(
          input: 'unused',
          device: SignerDeviceEntity.bitbox02,
        ),
        secondCold: null,
        inheritance: null,
        schedule: const BullVaultSchedule(coldDelay: 3, recoveryDelay: 3),
        timeReference: _timeReference(),
      ),
    );

    expect(
      (result as Err<BullVaultCreateResult, BullVaultFailure>).failure,
      isA<BullVaultInvalidScheduleFailure>(),
    );
  });

  test('rejects the fixed BIP341 NUMS point as a signer', () async {
    final repository = _TestBullVaultRepository();
    final result = await _usecase(repository, getSettings).execute(
      BullVaultCreateRequest(
        label: 'BullVault',
        protection: BullVaultProtection.standard,
        cold: BullVaultSignerRequest(
          input:
              'tpubD6NzVbkrYhZ4WLd82sJzTQAcHXancR9nXqyNo8pXVNNEQ7qTDXiwX6dSW97sUvxdVBV2tAgod7gfG8dhJsVqDspXrsaLSifGx8suAPrpyUn',
          device: SignerDeviceEntity.bitbox02,
        ),
        secondCold: null,
        inheritance: null,
        schedule: BullVaultSchedule.standardWithoutInheritance,
        timeReference: _timeReference(),
      ),
    );

    expect(
      (result as Err<BullVaultCreateResult, BullVaultFailure>).failure,
      isA<BullVaultInvalidSignerFailure>(),
    );
  });

  test('accepts a nonzero external BIP48 account', () async {
    final repository = _TestBullVaultRepository();
    final wrongAccount = deriveSignerKeysAtAccount(
      testMnemonics.first,
      account: 1,
    );
    final result = await _usecase(repository, getSettings).execute(
      BullVaultCreateRequest(
        label: 'BullVault',
        protection: BullVaultProtection.standard,
        cold: BullVaultSignerRequest(
          input: wrongAccount.xpub,
          device: SignerDeviceEntity.bitbox02,
        ),
        secondCold: null,
        inheritance: null,
        schedule: BullVaultSchedule.standardWithoutInheritance,
        timeReference: _timeReference(),
      ),
    );

    expect(result, isA<Ok<BullVaultCreateResult, BullVaultFailure>>());
    final created =
        (result as Ok<BullVaultCreateResult, BullVaultFailure>).value;
    expect(created.policy.coldKey.accountKey.derivationPath, "m/48'/1'/1'/2'");
  });
}

CreateBullVaultUsecase _usecase(
  BullVaultRepository repository,
  GetSettingsUsecase getSettings, {
  GetDefaultSeedUsecase? getDefaultSeed,
  DeleteWalletUsecase? deleteWalletUsecase,
  Bip48AccountRepository? accountRepository,
  PrepareBullVaultTimeReferenceUsecase? prepareTimeReferenceUsecase,
  BitcoinDescriptorPort? descriptorPort,
}) {
  final seedUsecase = getDefaultSeed ?? _MockGetDefaultSeedUsecase();
  if (getDefaultSeed == null) {
    when(
      () => seedUsecase.execute(environment: any(named: 'environment')),
    ).thenAnswer(
      (_) async => Seed.bytes(
        bytes: Uint8List.fromList(List<int>.generate(64, (index) => index)),
        masterFingerprint: 'deadbeef',
      ),
    );
  }
  final prepareTimeReference =
      prepareTimeReferenceUsecase ??
      _MockPrepareBullVaultTimeReferenceUsecase();
  if (prepareTimeReferenceUsecase == null) {
    when(
      () => prepareTimeReference.execute(isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((invocation) async {
      final isTestnet = invocation.namedArguments[#isTestnet] as bool;
      return Ok(_timeReference(isMainnet: !isTestnet));
    });
  }
  return CreateBullVaultUsecase(
    repository,
    descriptorPort ?? _ParsingDescriptorPort(),
    seedUsecase,
    getSettings,
    deleteWalletUsecase ?? _MockDeleteWalletUsecase(),
    accountRepository ?? _TestBip48AccountRepository(),
    prepareTimeReference,
  );
}

BullVaultTimeReference _timeReference({bool isMainnet = false}) =>
    BullVaultTimeReference(
      deviceTime: DateTime.utc(2027, 1, 15, 12),
      chainHeight: isMainnet ? 900_000 : 3_000_000,
      medianTimePast:
          DateTime.utc(2027, 1, 15, 11).millisecondsSinceEpoch ~/ 1000,
    );
