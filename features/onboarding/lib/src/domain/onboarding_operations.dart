import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:primitives/primitives.dart';

import 'onboarding_failure.dart';

typedef CreateOnboardingWallet =
    Future<Result<void, OnboardingFailure>> Function();
typedef RecoverOnboardingWallet =
    Future<Result<void, OnboardingFailure>> Function({
      required List<String> mnemonicWords,
      required Language language,
      required String passphrase,
    });
