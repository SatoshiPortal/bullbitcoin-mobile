import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autobuy/domain/autobuy_failure.dart';
import 'package:bb_mobile/features/autobuy/domain/autobuy_status.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/get_autobuy_status_usecase.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/set_autobuy_usecase.dart';
import 'package:bb_mobile/features/autobuy/presentation/autobuy_cubit.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSetAutoBuyUsecase extends Mock implements SetAutoBuyUsecase {}

class MockGetAutoBuyStatusUsecase extends Mock
    implements GetAutoBuyStatusUsecase {}

void main() {
  late MockSetAutoBuyUsecase setAutoBuy;
  late MockGetAutoBuyStatusUsecase getStatus;

  AutoBuyCubit buildCubit() => AutoBuyCubit(setAutoBuy, getStatus);

  const wallets = DefaultWallets(
    bitcoin: DefaultWallet(
      walletType: WalletAddressType.bitcoin,
      address: 'bc1qaddress',
    ),
  );

  setUp(() {
    setAutoBuy = MockSetAutoBuyUsecase();
    getStatus = MockGetAutoBuyStatusUsecase();
  });

  blocTest<AutoBuyCubit, AutoBuyState>(
    'loads the authoritative status',
    setUp: () {
      when(() => getStatus.execute()).thenAnswer(
        (_) async =>
            const Ok(AutoBuyStatus(isActive: true, isRestricted: false)),
      );
    },
    build: () => AutoBuyCubit(setAutoBuy, getStatus),
    act: (cubit) => cubit.loadStatus(),
    expect: () => const [
      AutoBuyState(isLoadingStatus: true),
      AutoBuyState(isActive: true, isRestricted: false),
    ],
  );

  blocTest<AutoBuyCubit, AutoBuyState>(
    'reports a failure when the status cannot be loaded',
    setUp: () {
      when(
        () => getStatus.execute(),
      ).thenAnswer((_) async => const Err(AutoBuyAccountUnavailableFailure()));
    },
    build: () => AutoBuyCubit(setAutoBuy, getStatus),
    act: (cubit) => cubit.loadStatus(),
    expect: () => const [
      AutoBuyState(isLoadingStatus: true),
      AutoBuyState(failure: AutoBuyAccountUnavailableFailure()),
    ],
  );

  blocTest<AutoBuyCubit, AutoBuyState>(
    'moves through intro, wallet, and confirmation steps',
    build: buildCubit,
    seed: () => const AutoBuyState(isRestricted: false),
    act: (cubit) {
      cubit.showWallets();
      cubit.showConfirmation(wallets);
      cubit.showWallets();
      cubit.showIntro();
    },
    expect: () => const [
      AutoBuyState(step: AutoBuyStep.wallets, isRestricted: false),
      AutoBuyState(
        step: AutoBuyStep.confirm,
        isRestricted: false,
        wallets: wallets,
      ),
      AutoBuyState(
        step: AutoBuyStep.wallets,
        isRestricted: false,
        wallets: wallets,
      ),
      AutoBuyState(isRestricted: false, wallets: wallets),
    ],
  );

  blocTest<AutoBuyCubit, AutoBuyState>(
    'enables AutoBuy only once the account confirms it',
    setUp: () {
      when(
        () => setAutoBuy.execute(enabled: true),
      ).thenAnswer((_) async => const Ok(null));
      when(() => getStatus.execute()).thenAnswer(
        (_) async =>
            const Ok(AutoBuyStatus(isActive: true, isRestricted: false)),
      );
    },
    build: buildCubit,
    seed: () => const AutoBuyState(
      step: AutoBuyStep.confirm,
      isRestricted: false,
      wallets: wallets,
    ),
    act: (cubit) => cubit.setEnabled(true),
    expect: () => const [
      AutoBuyState(
        step: AutoBuyStep.confirm,
        isRestricted: false,
        wallets: wallets,
        isSaving: true,
      ),
      AutoBuyState(
        step: AutoBuyStep.confirm,
        isRestricted: false,
        wallets: wallets,
        isActive: true,
        statusChangeSucceeded: true,
      ),
    ],
  );

  blocTest<AutoBuyCubit, AutoBuyState>(
    'does not report success when the account still reports it inactive',
    setUp: () {
      when(
        () => setAutoBuy.execute(enabled: true),
      ).thenAnswer((_) async => const Ok(null));
      when(() => getStatus.execute()).thenAnswer(
        (_) async =>
            const Ok(AutoBuyStatus(isActive: false, isRestricted: false)),
      );
    },
    build: buildCubit,
    seed: () => const AutoBuyState(
      step: AutoBuyStep.confirm,
      isRestricted: false,
      wallets: wallets,
    ),
    act: (cubit) => cubit.setEnabled(true),
    skip: 1,
    expect: () => [
      isA<AutoBuyState>()
          .having((state) => state.statusChangeSucceeded, 'succeeded', isFalse)
          .having((state) => state.isActive, 'isActive', isFalse)
          .having(
            (state) => state.failure,
            'failure',
            isA<AutoBuyStatusUnconfirmedFailure>(),
          ),
    ],
  );

  blocTest<AutoBuyCubit, AutoBuyState>(
    'does not report success when the confirming refresh fails',
    setUp: () {
      when(
        () => setAutoBuy.execute(enabled: true),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => getStatus.execute(),
      ).thenAnswer((_) async => const Err(AutoBuyAccountUnavailableFailure()));
    },
    build: buildCubit,
    seed: () => const AutoBuyState(
      step: AutoBuyStep.confirm,
      isRestricted: false,
      wallets: wallets,
    ),
    act: (cubit) => cubit.setEnabled(true),
    skip: 1,
    expect: () => [
      isA<AutoBuyState>()
          .having((state) => state.statusChangeSucceeded, 'succeeded', isFalse)
          .having(
            (state) => state.failure,
            'failure',
            isA<AutoBuyAccountUnavailableFailure>(),
          ),
    ],
  );

  blocTest<AutoBuyCubit, AutoBuyState>(
    'disables AutoBuy without requiring a wallet',
    setUp: () {
      when(
        () => setAutoBuy.execute(enabled: false),
      ).thenAnswer((_) async => const Ok(null));
      when(() => getStatus.execute()).thenAnswer(
        (_) async =>
            const Ok(AutoBuyStatus(isActive: false, isRestricted: false)),
      );
    },
    build: buildCubit,
    seed: () => const AutoBuyState(isActive: true, isRestricted: false),
    act: (cubit) => cubit.setEnabled(false),
    expect: () => const [
      AutoBuyState(isActive: true, isRestricted: false, isSaving: true),
      AutoBuyState(isRestricted: false, statusChangeSucceeded: true),
    ],
  );

  blocTest<AutoBuyCubit, AutoBuyState>(
    'keeps AutoBuy inactive when the preference update fails',
    setUp: () {
      when(
        () => setAutoBuy.execute(enabled: true),
      ).thenAnswer((_) async => const Err(AutoBuyPreferenceUpdateFailure()));
    },
    build: buildCubit,
    seed: () => const AutoBuyState(
      step: AutoBuyStep.confirm,
      isRestricted: false,
      wallets: wallets,
    ),
    act: (cubit) => cubit.setEnabled(true),
    expect: () => const [
      AutoBuyState(
        step: AutoBuyStep.confirm,
        isRestricted: false,
        wallets: wallets,
        isSaving: true,
      ),
      AutoBuyState(
        step: AutoBuyStep.confirm,
        isRestricted: false,
        wallets: wallets,
        failure: AutoBuyPreferenceUpdateFailure(),
      ),
    ],
  );
}
