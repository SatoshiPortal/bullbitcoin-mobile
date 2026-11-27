import 'package:onboarding/src/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:onboarding/onboarding.dart';
import 'package:onboarding/src/domain/usecases/recover_onboarding_wallet_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:convert/convert.dart' show hex;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:primitives/primitives.dart' as p;
import 'package:secrets/secrets.dart' as s;
import 'package:secrets/testing.dart';
import 'package:provisioning/provisioning.dart';

class _Inventory extends Mock implements s.WalletInventory {}

class _Verification extends Mock
    implements CompletePhysicalBackupVerificationUsecase {}

/// Records the default accounts the provisioning pass creates.
final class _Accounts implements WalletProvisioning {
  _Accounts(this.created, this.registrations);

  final List<s.Secret> created;
  final List<s.WalletRegistration> registrations;

  @override
  Future<p.Result<void, WalletProvisioningFailure>> resume() async =>
      const Ok(null);

  @override
  Future<p.Result<String, WalletProvisioningFailure>> createDefault(
    s.Secret secret,
    p.Network network, {
    DateTime? birthday,
  }) async {
    created.add(secret);
    final id = network.toString();
    registrations.add(
      walletRegistrationForTesting(
        id: id,
        network: network,
        isDefault: true,
        signer: s.WalletSigner.local,
        masterFingerprint: secret.id,
        secretFingerprint: secret.id,
      ),
    );
    return Ok(id);
  }

  @override
  Future<p.Result<void, s.ParentCustodyFailure>> importMnemonic({
    required p.Fingerprint parent,
    required s.Secrets secrets,
    required s.ParentCustodyAdmissionPort admission,
    required p.BitcoinNetwork network,
    required p.ScriptType scriptType,
    String? label,
  }) => throw StateError('Unexpected mnemonic provisioning');

  @override
  Future<p.Result<void, WalletProvisioningFailure>> importDescriptor(
    WatchOnlyAccount account,
  ) => throw StateError('Unexpected descriptor provisioning');

  @override
  Future<p.Result<void, WalletProvisioningFailure>> importXpub({
    required String xpub,
    required p.BitcoinNetwork network,
    required p.ScriptType scriptType,
    required String label,
  }) => throw StateError('Unexpected xpub provisioning');
}

final class _Environment implements ActiveEnvironmentReader {
  @override
  Future<p.Result<Environment, PreferencesFailure>>
  readActiveEnvironment() async {
    return const Ok(Environment.mainnet);
  }
}

/// A generated French phrase, never a real wallet's.
final _french = bip39.Mnemonic(
  List<int>.generate(16, (i) => i * 7 + 1),
  bip39.Language.french,
);

void main() {
  late FakeSecureStoragePlatform storage;
  late s.Secrets secrets;
  late List<s.Secret> created;
  late RecoverOnboardingWalletUsecase usecase;

  setUp(() async {
    storage = FakeSecureStoragePlatform()..install();
    secrets = s.Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => '/tmp',
    );
    final inventory = _Inventory();
    final registrations = <s.WalletRegistration>[];
    registerFallbackValue(p.BitcoinNetwork.mainnet);
    registerFallbackValue(<s.WalletRegistration>[]);
    when(() => inventory.walletsForNetwork(any())).thenAnswer((
      invocation,
    ) async {
      final network = invocation.positionalArguments.single as p.Network;
      return Ok(
        walletSelectionForTesting(
          registrations.where((wallet) => wallet.network == network).toList(),
        ),
      );
    });
    when(() => inventory.readWallet(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.single as String;
      return Ok(registrations.singleWhere((wallet) => wallet.id == id));
    });
    created = [];
    final provisioning = DefaultWalletProvisioning(
      secrets: secrets,
      inventory: inventory,
      environment: _Environment(),
      accounts: _Accounts(created, registrations),
    );
    final verification = _Verification();
    when(() => verification.execute(any()))
        .thenAnswer((_) async => const Ok(null));
    usecase = RecoverOnboardingWalletUsecase(
      defaultWallets: provisioning,
      completePhysicalBackupVerificationUsecase: verification,
    );
  });

  Future<p.Result<void, OnboardingFailure>> recover(
    List<String> words,
    bip39.Language language,
  ) => usecase.execute(mnemonicWords: words, language: language);

  test(
    'a French phrase restores the default wallets from its BIP39 seed',
    () async {
      final state = await recover(_french.words, bip39.Language.french);

      expect(state, isA<Ok<void, OnboardingFailure>>());
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

    expect(state, isA<p.Err<void, OnboardingFailure>>());
    expect(
      (state as p.Err<void, OnboardingFailure>).failure,
      isA<OnboardingWalletSetupFailure>(),
    );
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

      expect(state, isA<p.Err<void, OnboardingFailure>>());
      expect(
        (state as p.Err<void, OnboardingFailure>).failure,
        isA<OnboardingWalletSetupFailure>(),
      );
      expect(created, isEmpty);
      expect(storage.entries, isEmpty);
    },
  );
}
