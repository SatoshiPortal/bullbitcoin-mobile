import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/onboarding_failure.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/public/default_wallets_facade.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart' show hex;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit, Ok;
import 'package:primitives/primitives.dart' as p;
import 'package:secrets/secrets.dart' as s;
import 'package:secrets/testing.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Wallets extends Mock implements WalletRepository {}

class _Wallet extends Mock implements Wallet {}

class _Create extends Mock implements CreateOnboardingWalletUsecase {}

class _Verification extends Mock
    implements CompletePhysicalBackupVerificationUsecase {}

/// A generated French phrase, never a real wallet's.
final _french = bip39.Mnemonic(
  List<int>.generate(16, (i) => i * 7 + 1),
  bip39.Language.french,
);

void main() {
  late FakeSecureStoragePlatform storage;
  late s.Secrets secrets;
  late List<s.Secret> created;
  late OnboardingBloc bloc;

  setUp(() async {
    storage = FakeSecureStoragePlatform()..install();
    secrets = s.Secrets(scratchDirectory: () async => '/tmp');
    // mocktail needs a real handle as the fallback of `any()`; then forget it.
    final fallback = await secrets.import(
      words: [...List.filled(11, 'abandon'), 'about'],
      language: bip39.Language.english,
    );
    registerFallbackValue((fallback as Ok<s.Secret, s.SecretFailure>).value);
    storage.entries.clear();
    registerFallbackValue(Network.bitcoinMainnet);
    registerFallbackValue(ScriptType.bip84);
    final settings = _Settings();
    when(settings.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    final wallets = _Wallets();
    when(
      () => wallets.getWallets(
        onlyDefaults: true,
        environment: Environment.mainnet,
      ),
    ).thenAnswer((_) async => const Ok<List<Wallet>, WalletFailure>([]));
    created = [];
    when(
      () => wallets.createWallet(
        secret: any(named: 'secret'),
        network: any(named: 'network'),
        scriptType: ScriptType.bip84,
        isDefault: true,
        birthday: null,
      ),
    ).thenAnswer((invocation) async {
      created.add(invocation.namedArguments[#secret] as s.Secret);
      return _Wallet();
    });
    final verification = _Verification();
    when(verification.execute).thenAnswer((_) async {});
    bloc = OnboardingBloc(
      createOnboardingWalletUsecase: _Create(),
      recoverOnboardingWalletUsecase: RecoverOnboardingWalletUsecase(
        defaultWallets: DefaultWalletsFacade(
          CreateDefaultWalletsUsecase(
            secrets: secrets,
            settingsRepository: settings,
            walletRepository: wallets,
          ),
        ),
        completePhysicalBackupVerificationUsecase: verification,
      ),
    );
  });

  tearDown(() => bloc.close());

  Future<OnboardingState> recover(
    List<String> words,
    bip39.Language language,
  ) async {
    bloc.add(
      OnboardingRecoverWalletClicked(
        mnemonic: (label: '', passphrase: '', words: words, language: language),
      ),
    );
    return bloc.stream.firstWhere(
      (state) => state.onboardingStepStatus != OnboardingStepStatus.loading,
    );
  }

  test(
    'a French phrase restores the default wallets from its BIP39 seed',
    () async {
      final state = await recover(_french.words, bip39.Language.french);

      expect(state.onboardingStepStatus, OnboardingStepStatus.success);
      expect(created, hasLength(2));
      final secret = created.first;
      expect(created.last.id, secret.id);
      expect(secret.info.language, bip39.Language.french);
      // The seed bip39 derives for these words in French: Bitcoin, Liquid, the
      // swap key and Silent Payments all derive from it.
      final seed = await secret.verify.seed(hex.encode(_french.seed));
      expect((seed as Ok<bool, s.SecretFailure>).value, isTrue);
      // The same identity as importing the phrase with its language.
      final previewed = await secrets.preview.bitcoinDescriptors(
        words: _french.words,
        language: bip39.Language.french,
        network: p.BitcoinNetwork.mainnet,
        scriptTypes: {p.ScriptType.bip84},
      );
      final recovered = await secret.derive.descriptors.bitcoin(
        network: p.BitcoinNetwork.mainnet,
        scriptType: p.ScriptType.bip84,
      );
      expect(
        (recovered as Ok).value,
        (previewed as Ok).value[p.ScriptType.bip84],
      );
    },
  );

  test('a French phrase read as English is refused, nothing stored', () async {
    expect(
      () => bip39.Mnemonic.fromWords(
        words: _french.words,
        language: bip39.Language.english,
      ),
      throwsA(isA<bip39.MnemonicException>()),
    );

    final state = await recover(_french.words, bip39.Language.english);

    expect(state.failure, isA<OnboardingWalletSetupFailure>());
    expect(created, isEmpty);
    expect(storage.entries, isEmpty);
  });

  test(
    'French words with a broken checksum are refused, nothing stored',
    () async {
      final words = [..._french.words];
      words[11] = words[11] == 'abaisser' ? 'abandon' : 'abaisser';
      expect(
        () => bip39.Mnemonic.fromWords(
          words: words,
          language: bip39.Language.french,
        ),
        throwsA(isA<bip39.MnemonicException>()),
      );

      final state = await recover(words, bip39.Language.french);

      expect(state.failure, isA<OnboardingWalletSetupFailure>());
      expect(created, isEmpty);
      expect(storage.entries, isEmpty);
    },
  );
}
