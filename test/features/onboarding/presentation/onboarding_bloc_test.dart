import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';

class _MockCreateOnboardingWalletUsecase extends Mock
    implements CreateOnboardingWalletUsecase {}

class _MockRecoverOnboardingWalletUsecase extends Mock
    implements RecoverOnboardingWalletUsecase {}

void main() {
  test(
    'physical recovery forwards initial preferences without awaiting a server',
    () async {
      final recover = _MockRecoverOnboardingWalletUsecase();
      final initial = [
        WalletPreferences(walletRef: 'new-default', label: 'Initial'),
      ];
      when(
        () => recover.execute(mnemonicWords: any(named: 'mnemonicWords')),
      ).thenAnswer((_) async => Ok(initial));
      final bloc = OnboardingBloc(
        createOnboardingWalletUsecase: _MockCreateOnboardingWalletUsecase(),
        recoverOnboardingWalletUsecase: recover,
      );
      addTearDown(bloc.close);
      bloc.add(
        OnboardingRecoverWalletClicked(
          mnemonic: (
            words:
                'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'
                    .split(' '),
            language: bip39.Language.english,
            label: '',
            passphrase: '',
          ),
        ),
      );
      final state = await bloc.stream.firstWhere((state) => state.isSuccess);
      expect(state.defaultCreatedWalletPreferences, initial);
      expect(state.failure, isNull);
      final context = WalletHomeRecoveryContext(
        state.defaultCreatedWalletPreferences,
      );
      expect(context.takeCreatedWalletPreferences(), initial);
      expect(context.takeCreatedWalletPreferences(), isEmpty);
    },
  );

  test('reports success as soon as the default wallets exist', () async {
    final createWallets = _MockCreateOnboardingWalletUsecase();
    when(() => createWallets.execute()).thenAnswer((_) async => const Ok([]));
    final bloc = OnboardingBloc(
      createOnboardingWalletUsecase: createWallets,
      recoverOnboardingWalletUsecase: _MockRecoverOnboardingWalletUsecase(),
    );
    addTearDown(bloc.close);

    bloc.add(const OnboardingCreateNewWallet());
    final state = await bloc.stream.firstWhere((state) => state.isSuccess);

    // Nothing after wallet creation, such as the Data Backup opt-in, is
    // awaited here: that runs from the home page.
    expect(state.failure, isNull);
    verify(() => createWallets.execute()).called(1);
  });
}
