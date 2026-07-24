import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/resolve_wallet_birthday_checkpoint_usecase.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCreateDefaultWalletsUsecase extends Mock
    implements CreateDefaultWalletsUsecase {}

class _MockCompletePhysicalBackupVerificationUsecase extends Mock
    implements CompletePhysicalBackupVerificationUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockCheckCompactBlockFiltersAvailableUsecase extends Mock
    implements CheckCompactBlockFiltersAvailableUsecase {}

class _MockResolveWalletBirthdayCheckpointUsecase extends Mock
    implements ResolveWalletBirthdayCheckpointUsecase {}

SettingsEntity _buildSettings({bool useCompactBlockFiltersByDefault = false}) {
  return SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    useCompactBlockFiltersByDefault: useCompactBlockFiltersByDefault,
  );
}

/// Focused tests for `OnboardingBloc`'s "create" step — the state
/// `OnboardingRouter`'s listener reads (`state.step ==
/// OnboardingStep.create`) to always navigate a freshly created wallet
/// straight to wallet home, whether or not it opted into compact block
/// filters (see `WalletRouter.goToWalletHomeOrInitialSyncForDefaultBitcoinWallet`'s
/// `isRecoveryOrImport: false` call in that listener). The bloc itself
/// stays CBF-agnostic — that decision lives entirely in
/// `CreateDefaultWalletsUsecase` and `WalletRouter`.
void main() {
  late _MockCreateDefaultWalletsUsecase createDefaultWalletsUsecase;
  late _MockCompletePhysicalBackupVerificationUsecase
  completePhysicalBackupVerificationUsecase;
  late _MockGetSettingsUsecase getSettings;
  late _MockCheckCompactBlockFiltersAvailableUsecase
  checkCompactBlockFiltersAvailable;
  late _MockResolveWalletBirthdayCheckpointUsecase
  resolveWalletBirthdayCheckpoint;
  late OnboardingBloc bloc;

  setUpAll(() {
    registerFallbackValue(WalletBirthdayLookupMode.recovery);
  });

  setUp(() {
    createDefaultWalletsUsecase = _MockCreateDefaultWalletsUsecase();
    completePhysicalBackupVerificationUsecase =
        _MockCompletePhysicalBackupVerificationUsecase();
    getSettings = _MockGetSettingsUsecase();
    checkCompactBlockFiltersAvailable =
        _MockCheckCompactBlockFiltersAvailableUsecase();
    resolveWalletBirthdayCheckpoint =
        _MockResolveWalletBirthdayCheckpointUsecase();
    // The birthday-picker gate below defaults to off, so the existing
    // tests (predating that gate) keep exercising the immediate
    // create-wallets path unchanged.
    when(() => getSettings.execute()).thenAnswer((_) async => _buildSettings());
    bloc = OnboardingBloc(
      createDefaultWalletsUsecase: createDefaultWalletsUsecase,
      completePhysicalBackupVerificationUsecase:
          completePhysicalBackupVerificationUsecase,
      getSettingsUsecase: getSettings,
      checkCompactBlockFiltersAvailableUsecase:
          checkCompactBlockFiltersAvailable,
      resolveWalletBirthdayCheckpointUsecase: resolveWalletBirthdayCheckpoint,
    );
  });

  tearDown(() => bloc.close());

  test('OnboardingCreateNewWallet calls CreateDefaultWalletsUsecase with no '
      'mnemonicWords (a freshly generated wallet, never a recovery) and ends '
      'on step create with success — the state the router listens on to '
      'navigate straight to wallet home, CBF or not', () async {
    when(
      () => createDefaultWalletsUsecase.execute(),
    ).thenAnswer((_) async => <Wallet>[]);

    final states = <OnboardingState>[];
    bloc.stream.listen(states.add);

    bloc.add(const OnboardingCreateNewWallet());
    await bloc.stream.firstWhere((s) => s.isSuccess);

    verify(() => createDefaultWalletsUsecase.execute()).called(1);
    verifyNever(
      () => createDefaultWalletsUsecase.execute(
        mnemonicWords: any(named: 'mnemonicWords'),
      ),
    );

    expect(states.last.step, OnboardingStep.create);
    expect(states.last.onboardingStepStatus, OnboardingStepStatus.success);
    expect(states.last.statusError, isEmpty);
  });

  test('a CreateDefaultWalletsUsecase failure (e.g. checkpoint resolution '
      'failed for a CBF wallet) surfaces as a retryable splash error — never '
      'a success, so the router never navigates', () async {
    when(
      () => createDefaultWalletsUsecase.execute(),
    ).thenThrow(CreateDefaultWalletsException('boom'));

    final states = <OnboardingState>[];
    bloc.stream.listen(states.add);

    bloc.add(const OnboardingCreateNewWallet());
    await bloc.stream.firstWhere(
      (s) => s.onboardingStepStatus == OnboardingStepStatus.none,
    );

    expect(states.last.step, OnboardingStep.splash);
    expect(states.last.isSuccess, isFalse);
    expect(states.last.statusError, isNotEmpty);
  });

  test('a second OnboardingCreateNewWallet dispatched while the first is still '
      'loading is dropped (#2015) — CreateDefaultWalletsUsecase.execute is '
      'called only once', () async {
    when(() => createDefaultWalletsUsecase.execute()).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return <Wallet>[];
    });

    bloc
      ..add(const OnboardingCreateNewWallet())
      ..add(const OnboardingCreateNewWallet());
    await bloc.stream.firstWhere((s) => s.isSuccess);

    verify(() => createDefaultWalletsUsecase.execute()).called(1);
  });

  test('OnboardingRecoverWalletClicked passes the entered mnemonic through — '
      'never the freshly-generated (null mnemonicWords) path a CBF checkpoint '
      'resolution requires', () async {
    when(
      () => createDefaultWalletsUsecase.execute(
        mnemonicWords: any(named: 'mnemonicWords'),
      ),
    ).thenAnswer((_) async => <Wallet>[]);
    when(
      () => completePhysicalBackupVerificationUsecase.execute(),
    ).thenAnswer((_) async {});

    final mnemonic = (
      words: const ['abandon'],
      passphrase: '',
      label: '',
      language: bip39.Language.english,
    );

    final states = <OnboardingState>[];
    bloc.stream.listen(states.add);

    bloc.add(OnboardingRecoverWalletClicked(mnemonic: mnemonic));
    await bloc.stream.firstWhere((s) => s.isSuccess);

    verify(
      () => createDefaultWalletsUsecase.execute(mnemonicWords: ['abandon']),
    ).called(1);
    verifyNever(() => createDefaultWalletsUsecase.execute());
    expect(states.last.step, OnboardingStep.recover);
  });

  group('CBF birthday picker (mnemonic recovery)', () {
    final mnemonic = (
      words: const ['abandon'],
      passphrase: '',
      label: '',
      language: bip39.Language.english,
    );

    test('the preference on and CBF available pauses on '
        'needsBitcoinBirthdaySelection with the mnemonic pending — '
        'CreateDefaultWalletsUsecase is never called yet', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
      );
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);

      bloc.add(OnboardingRecoverWalletClicked(mnemonic: mnemonic));
      await bloc.stream.firstWhere((s) => s.needsBitcoinBirthdaySelection);

      expect(bloc.state.needsBitcoinBirthdaySelection, isTrue);
      expect(bloc.state.pendingRecoveryMnemonic, mnemonic);
      verifyNever(
        () => createDefaultWalletsUsecase.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
        ),
      );
    });

    test('the preference off never pauses — createDefaultWalletsUsecase runs '
        'immediately, exactly as before this feature existed', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: false),
      );
      when(
        () => createDefaultWalletsUsecase.execute(
          mnemonicWords: any(named: 'mnemonicWords'),
        ),
      ).thenAnswer((_) async => <Wallet>[]);
      when(
        () => completePhysicalBackupVerificationUsecase.execute(),
      ).thenAnswer((_) async {});

      bloc.add(OnboardingRecoverWalletClicked(mnemonic: mnemonic));
      await bloc.stream.firstWhere((s) => s.isSuccess);

      expect(bloc.state.needsBitcoinBirthdaySelection, isFalse);
      verifyNever(() => checkCompactBlockFiltersAvailable.execute());
    });

    test('resolveBitcoinBirthdayCheckpoint always resolves with '
        'WalletBirthdayLookupMode.recovery — never newWallet, which is only '
        'ever used by CreateDefaultWalletsUsecase for a freshly generated '
        'wallet', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
      );
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);
      final fakeCheckpoint = WalletBirthdayCheckpoint(
        requestedBirthday: DateTime.utc(2026),
        blockTimestamp: DateTime.utc(2026),
        blockHeight: 900000,
        blockHash: 'a' * 64,
      );
      when(
        () => resolveWalletBirthdayCheckpoint.execute(
          requestedBirthday: any(named: 'requestedBirthday'),
          isTestnet: any(named: 'isTestnet'),
          lookupMode: any(named: 'lookupMode'),
        ),
      ).thenAnswer((_) async => Ok(fakeCheckpoint));

      bloc.add(OnboardingRecoverWalletClicked(mnemonic: mnemonic));
      await bloc.stream.firstWhere((s) => s.needsBitcoinBirthdaySelection);

      final requestedBirthday = DateTime.utc(2015);
      final result = await bloc.resolveBitcoinBirthdayCheckpoint(
        requestedBirthday,
      );

      expect(result, isA<Ok<WalletBirthdayCheckpoint, dynamic>>());
      verify(
        () => resolveWalletBirthdayCheckpoint.execute(
          requestedBirthday: requestedBirthday,
          isTestnet: false,
          lookupMode: WalletBirthdayLookupMode.recovery,
        ),
      ).called(1);
    });

    test(
      'OnboardingBitcoinBirthdayResolved with a checkpoint resumes recovery, '
      'passing it through to CreateDefaultWalletsUsecase, and clears the '
      'pending mnemonic on success',
      () async {
        when(() => getSettings.execute()).thenAnswer(
          (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
        );
        when(
          () => checkCompactBlockFiltersAvailable.execute(),
        ).thenAnswer((_) async => true);

        bloc.add(OnboardingRecoverWalletClicked(mnemonic: mnemonic));
        await bloc.stream.firstWhere((s) => s.needsBitcoinBirthdaySelection);

        final fakeCheckpoint = WalletBirthdayCheckpoint(
          requestedBirthday: DateTime.utc(2026),
          blockTimestamp: DateTime.utc(2026),
          blockHeight: 900000,
          blockHash: 'a' * 64,
        );
        when(
          () => createDefaultWalletsUsecase.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
            bitcoinBirthdayCheckpoint: any(named: 'bitcoinBirthdayCheckpoint'),
          ),
        ).thenAnswer((_) async => <Wallet>[]);
        when(
          () => completePhysicalBackupVerificationUsecase.execute(),
        ).thenAnswer((_) async {});

        bloc.add(OnboardingBitcoinBirthdayResolved(checkpoint: fakeCheckpoint));
        await bloc.stream.firstWhere((s) => s.isSuccess);

        verify(
          () => createDefaultWalletsUsecase.execute(
            mnemonicWords: ['abandon'],
            bitcoinBirthdayCheckpoint: fakeCheckpoint,
          ),
        ).called(1);
        expect(bloc.state.pendingRecoveryMnemonic, isNull);
        expect(bloc.state.needsBitcoinBirthdaySelection, isFalse);
      },
    );

    test(
      'OnboardingBitcoinBirthdayResolved with no checkpoint (user backed out '
      'of the picker) aborts — no wallet is ever created, never a partial '
      'pair',
      () async {
        when(() => getSettings.execute()).thenAnswer(
          (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
        );
        when(
          () => checkCompactBlockFiltersAvailable.execute(),
        ).thenAnswer((_) async => true);

        bloc.add(OnboardingRecoverWalletClicked(mnemonic: mnemonic));
        await bloc.stream.firstWhere((s) => s.needsBitcoinBirthdaySelection);

        bloc.add(const OnboardingBitcoinBirthdayResolved());
        await bloc.stream.firstWhere((s) => !s.needsBitcoinBirthdaySelection);

        expect(bloc.state.pendingRecoveryMnemonic, isNull);
        expect(bloc.state.step, OnboardingStep.recover);
        expect(bloc.state.isSuccess, isFalse);
        verifyNever(
          () => createDefaultWalletsUsecase.execute(
            mnemonicWords: any(named: 'mnemonicWords'),
          ),
        );
      },
    );
  });
}
