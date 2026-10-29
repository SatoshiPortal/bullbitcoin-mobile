import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Create extends Mock implements CreateOnboardingWalletUsecase {}

class _Recover extends Mock implements RecoverOnboardingWalletUsecase {}

void main() {
  test(
    'recovery passes explicit Bitcoin source and birthday to default creation',
    () async {
      final recover = _Recover();
      final birthday = WalletBirthday(DateTime.utc(2021, 3));
      when(
        () => recover.execute(
          mnemonicWords: const [],
          birthday: birthday,
          bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
        ),
      ).thenAnswer((_) async => const Ok(null));
      final bloc = OnboardingBloc(
        createOnboardingWalletUsecase: _Create(),
        recoverOnboardingWalletUsecase: recover,
      );
      addTearDown(bloc.close);
      verifyZeroInteractions(recover);
      bloc.add(
        OnboardingRecoverWalletClicked(
          mnemonic: (
            words: const [],
            passphrase: '',
            label: '',
            language: bip39.Language.english,
          ),
          birthday: birthday,
          bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
        ),
      );
      await pumpEventQueue();
      expect(bloc.state.onboardingStepStatus, OnboardingStepStatus.success);
      verify(
        () => recover.execute(
          mnemonicWords: const [],
          birthday: birthday,
          bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
        ),
      ).called(1);
    },
  );
}
