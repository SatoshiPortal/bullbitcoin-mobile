import 'package:wallet_import/wallet_import.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, BitcoinUnit, Err, Fingerprint, Ok, ScriptType;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:preferences/preferences.dart';
import 'package:provisioning/provisioning.dart';
import 'package:wallet_import/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockCheckDuplicateMnemonicUsecase extends Mock
    implements CheckDuplicateMnemonicUsecase {}

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockProvisioning extends Mock implements WalletProvisioning {}

/// A failed import must preserve custody for resumable native provisioning.
///
/// A catalog entry may already be committed when the native writer fails.
/// Assert against the real Secrets and in-memory keystore; automatic cleanup
/// cannot safely infer that a secret is unreferenced from an unavailable reader.
class _Admission extends Fake implements ParentCustodyAdmissionPort {}

void main() {
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];
  const settings = SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'CAD',
  );

  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late _MockCheckDuplicateMnemonicUsecase checkDuplicate;
  late _MockSettingsRepository settingsRepository;
  late _MockProvisioning provisioning;
  late ImportWalletUsecase usecase;

  Iterable<String> storedSecrets() =>
      storage.entries.keys.where((k) => k.startsWith('seed_'));

  setUpAll(() async {
    FakeSecureStoragePlatform().install();
    final fallback = await Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => '/tmp',
    ).import(words: words, language: bip39.Language.english);
    registerFallbackValue((fallback as Ok<Secret, SecretFailure>).value);
    registerFallbackValue(Fingerprint('73c5da0a'));
    registerFallbackValue(_Admission());
    registerFallbackValue(BitcoinNetwork.mainnet);
    registerFallbackValue(ScriptType.bip84);
  });

  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => '/tmp',
    );
    checkDuplicate = _MockCheckDuplicateMnemonicUsecase();
    settingsRepository = _MockSettingsRepository();
    provisioning = _MockProvisioning();
    usecase = ImportWalletUsecase(
      checkDuplicateMnemonicUsecase: checkDuplicate,
      secrets: secrets,
      settingsRepository: settingsRepository,
      provision: provisioning.importMnemonic,
      admission: _Admission(),
    );
    when(
      () => checkDuplicate.execute(
        mnemonicWords: any(named: 'mnemonicWords'),
        passphrase: any(named: 'passphrase'),
        language: bip39.Language.english,
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(() => checkDuplicate.isReferenced(any(), any()))
        .thenAnswer((_) async => const Ok(false));
  });

  void failCreateWalletWith(Object error) {
    when(
      () => provisioning.importMnemonic(
        parent: any(named: 'parent'),
        secrets: secrets,
        admission: any(named: 'admission'),
        network: any(named: 'network'),
        scriptType: any(named: 'scriptType'),
        label: any(named: 'label'),
      ),
    ).thenThrow(error);
  }

  group('ImportWalletUsecase serialises concurrent imports', () {
    test('a second execute never runs while the first is in flight', () async {
      // The usecase guards its body with a process-wide Lock. Nothing
      // asserted it, so the lock could be deleted and the whole suite
      // stayed green.
      //
      // Probed from inside the locked body: settings.fetch() is the first
      // await _execute performs, so counting overlapping calls to it
      // counts overlapping bodies.
      var inFlight = 0;
      var peak = 0;
      when(() => settingsRepository.fetch()).thenAnswer((_) async {
        inFlight++;
        peak = peak > inFlight ? peak : inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        inFlight--;
        return Ok(settings);
      });
      failCreateWalletWith(Exception('wallet already exists'));

      await Future.wait([
        usecase.execute(mnemonicWords: words, language: bip39.Language.english),
        usecase.execute(mnemonicWords: words, language: bip39.Language.english),
      ]);

      expect(
        peak,
        1,
        reason: 'two import bodies overlapped: the lock is not holding',
      );
    });
  });

  group('ImportWalletUsecase custody retention', () {
    test(
      'keeps a stored secret when the failure precedes the import',
      () async {
        expect(
          await secrets.import(words: words, language: bip39.Language.english),
          isA<Ok<Secret, SecretFailure>>(),
        );
        when(() => settingsRepository.fetch())
            .thenThrow(Exception('settings unavailable'));

        final result = await usecase.execute(
          mnemonicWords: words,
          language: bip39.Language.english,
        );

        expect(result, isA<Err<void, ImportMnemonicFailure>>());
        expect(storedSecrets(), hasLength(1));
      },
    );

    test('keeps a secret already referenced by an existing wallet', () async {
      expect(
        await secrets.import(words: words, language: bip39.Language.english),
        isA<Ok<Secret, SecretFailure>>(),
      );
      when(() => settingsRepository.fetch())
          .thenAnswer((_) async => Ok(settings));
      failCreateWalletWith(Exception('wallet already exists'));

      final result = await usecase.execute(
        mnemonicWords: words,
        language: bip39.Language.english,
      );

      expect(result, isA<Err<void, ImportMnemonicFailure>>());
      expect(
        storedSecrets(),
        hasLength(1),
        reason: 'this import did not create it, so it is not its to delete',
      );
    });

    test(
      'retains a newly imported secret after native provisioning fails',
      () async {
        when(() => settingsRepository.fetch())
            .thenAnswer((_) async => Ok(settings));
        failCreateWalletWith(Exception('electrum unreachable'));

        final result = await usecase.execute(
          mnemonicWords: words,
          language: bip39.Language.english,
        );

        expect(result, isA<Err<void, ImportMnemonicFailure>>());
        expect(
          storedSecrets(),
          hasLength(1),
          reason: 'startup must be able to resume a committed catalog entry',
        );
      },
    );
  });
}
