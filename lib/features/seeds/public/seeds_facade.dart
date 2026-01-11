import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/create_new_seed_mnemonic_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/deregister_seed_usage_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/get_seed_secret_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/get_seed_usage_by_consumer_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/import_seed_mnemonic_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/register_seed_usage_usecase.dart';
import 'package:bb_mobile/features/seeds/public/seeds_facade_errors.dart';

class SeedsFacade {
  final CreateNewSeedMnemonicUseCase _createNewSeedMnemonicUseCase;
  final ImportSeedMnemonicUseCase _importSeedMnemonicUseCase;
  final GetSeedSecretUseCase _getSeedSecretUseCase;
  final RegisterSeedUsageUseCase _registerSeedUsageUseCase;
  final GetSeedUsageByConsumerUseCase _getSeedUsageByConsumerUseCase;
  final DeregisterSeedUsageUseCase _deregisterSeedUsageUseCase;

  SeedsFacade({
    required CreateNewSeedMnemonicUseCase createNewSeedMnemonicUseCase,
    required ImportSeedMnemonicUseCase importSeedMnemonicUseCase,
    required GetSeedSecretUseCase getSeedSecretUseCase,
    required RegisterSeedUsageUseCase registerSeedUsageUseCase,
    required GetSeedUsageByConsumerUseCase getSeedUsageByConsumerUseCase,
    required DeregisterSeedUsageUseCase deregisterSeedUsageUseCase,
  }) : _createNewSeedMnemonicUseCase = createNewSeedMnemonicUseCase,
       _importSeedMnemonicUseCase = importSeedMnemonicUseCase,
       _getSeedSecretUseCase = getSeedSecretUseCase,
       _registerSeedUsageUseCase = registerSeedUsageUseCase,
       _getSeedUsageByConsumerUseCase = getSeedUsageByConsumerUseCase,
       _deregisterSeedUsageUseCase = deregisterSeedUsageUseCase;

  Future<({String fingerprint, SeedSecret secret})> createNewMnemonic({
    String? passphrase,
    required SeedUsagePurpose purpose,
    required String consumerRef,
  }) async {
    try {
      final command = CreateNewSeedMnemonicCommand(
        passphrase: passphrase,
        purpose: purpose,
        consumerRef: consumerRef,
      );
      final result = await _createNewSeedMnemonicUseCase.execute(command);
      return (fingerprint: result.fingerprint, secret: result.secret);
    } on SeedsApplicationError catch (e) {
      throw SeedsFacadeError.fromApplicationError(e);
    } catch (e) {
      throw UnknownSeedsFacadeError(e);
    }
  }

  Future<String> importMnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
    required SeedUsagePurpose purpose,
    required String consumerRef,
  }) async {
    try {
      final command = ImportSeedMnemonicCommand(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
        purpose: purpose,
        consumerRef: consumerRef,
      );
      final result = await _importSeedMnemonicUseCase.execute(command);
      return result.fingerprint;
    } on SeedsApplicationError catch (e) {
      throw SeedsFacadeError.fromApplicationError(e);
    } catch (e) {
      throw UnknownSeedsFacadeError(e);
    }
  }

  Future<SeedSecret> getSeedSecret(String fingerprint) async {
    try {
      final query = GetSeedSecretQuery(fingerprint: fingerprint);
      final result = await _getSeedSecretUseCase.execute(query);
      return result.secret;
    } on SeedsApplicationError catch (e) {
      throw SeedsFacadeError.fromApplicationError(e);
    } catch (e) {
      throw UnknownSeedsFacadeError(e);
    }
  }

  Future<void> registerUsage(
    String fingerprint,
    SeedUsagePurpose purpose,
    String consumerRef,
  ) async {
    try {
      final command = RegisterSeedUsageCommand(
        fingerprint: fingerprint,
        purpose: purpose,
        consumerRef: consumerRef,
      );
      await _registerSeedUsageUseCase.execute(command);
    } on SeedsApplicationError catch (e) {
      throw SeedsFacadeError.fromApplicationError(e);
    } catch (e) {
      throw UnknownSeedsFacadeError(e);
    }
  }

  Future<void> deregisterUsage({
    required String fingerprint,
    required String consumerRef,
    required SeedUsagePurpose purpose,
  }) async {
    try {
      // Ensure the usage exists
      final result = await _getSeedUsageByConsumerUseCase.execute(
        GetSeedUsageByConsumerQuery(purpose: purpose, consumerRef: consumerRef),
      );
      final usage = result.usage;

      if (usage.fingerprint != fingerprint) {
        // The usage found does not match the provided fingerprint
        throw FailedToDeregisterSeedUsageError(
          usage.id,
          'Fingerprint mismatch.',
        );
      }
      final command = DeregisterSeedUsageCommand(seedUsageId: usage.id);
      await _deregisterSeedUsageUseCase.execute(command);
    } on SeedUsageNotFoundError {
      // If no usage found, nothing to deregister
      return;
    } on SeedsApplicationError catch (e) {
      throw SeedsFacadeError.fromApplicationError(e);
    } catch (e) {
      throw UnknownSeedsFacadeError(e);
    }
  }
}
