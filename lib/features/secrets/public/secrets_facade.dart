import 'package:bb_mobile/features/secrets/application/usecases/deregister_secret_usage_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/get_secret_usages_by_consumer_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/application/usecases/create_new_mnemonic_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/deregister_secret_usages_of_consumer_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/get_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/import_mnemonic_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/public/secrets_facade_error.dart';

class SecretsFacade {
  final CreateNewMnemonicSecretUseCase _createNewMnemonicSecretUseCase;
  final ImportMnemonicSecretUseCase _importMnemonicSecretUseCase;
  final GetSecretUseCase _getSecretUseCase;
  final GetSecretUsagesByConsumerUseCase _getSecretUsagesByConsumerUseCase;
  final DeregisterSecretUsageUseCase _deregisterSecretUsageUseCase;
  final DeregisterSecretUsagesOfConsumerUseCase
  _deregisterSecretUsagesOfConsumerUseCase;

  SecretsFacade({
    required CreateNewMnemonicSecretUseCase createNewSecretMnemonicUseCase,
    required ImportMnemonicSecretUseCase importSecretMnemonicUseCase,
    required GetSecretUseCase getSecretUseCase,
    required GetSecretUsagesByConsumerUseCase getSecretUsagesByConsumerUseCase,
    required DeregisterSecretUsageUseCase deregisterSecretUsageUseCase,
    required DeregisterSecretUsagesOfConsumerUseCase
    deregisterSecretUsagesOfConsumerUseCase,
  }) : _createNewMnemonicSecretUseCase = createNewSecretMnemonicUseCase,
       _importMnemonicSecretUseCase = importSecretMnemonicUseCase,
       _getSecretUseCase = getSecretUseCase,
       _getSecretUsagesByConsumerUseCase = getSecretUsagesByConsumerUseCase,
       _deregisterSecretUsageUseCase = deregisterSecretUsageUseCase,
       _deregisterSecretUsagesOfConsumerUseCase =
           deregisterSecretUsagesOfConsumerUseCase;

  Future<MnemonicSecret> createNewMnemonicForWallet({
    String? passphrase,
    required String walletId,
  }) async {
    try {
      final command = CreateNewMnemonicSecretCommand.forWallet(
        passphrase: passphrase,
        walletId: walletId,
      );
      final result = await _createNewMnemonicSecretUseCase.execute(command);
      return result.secret;
    } on SecretsApplicationError catch (e) {
      throw SecretsFacadeError.fromApplicationError(e);
    } catch (e) {
      throw UnknownSecretsError(e);
    }
  }

  Future<Fingerprint> importMnemonicForWallet({
    required List<String> mnemonicWords,
    String? passphrase,
    required String walletId,
  }) async {
    try {
      final command = ImportMnemonicSecretCommand.forWallet(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
        walletId: walletId,
      );
      final result = await _importMnemonicSecretUseCase.execute(command);
      return result.fingerprint;
    } on SecretsApplicationError catch (e) {
      throw SecretsFacadeError.fromApplicationError(e);
    } catch (e) {
      throw UnknownSecretsError(e);
    }
  }

  Future<Secret> getSecret(String fingerprint) async {
    try {
      final query = GetSecretQuery(fingerprint: fingerprint);
      final result = await _getSecretUseCase.execute(query);
      return result.secret;
    } on SecretsApplicationError catch (e) {
      throw SecretsFacadeError.fromApplicationError(e);
    } catch (e) {
      throw UnknownSecretsError(e);
    }
  }

  Future<List<SecretUsage>> getSecretUsagesByWalletConsumer({
    required String walletId,
  }) async {
    try {
      final query = GetSecretUsagesByConsumerQuery.byWallet(walletId: walletId);
      final result = await _getSecretUsagesByConsumerUseCase.execute(query);
      return result.usages;
    } on SecretsApplicationError catch (e) {
      throw SecretsFacadeError.fromApplicationError(e);
    } catch (e) {
      throw UnknownSecretsError(e);
    }
  }

  Future<void> deregisterUsage({required int usageId}) async {
    try {
      final command = DeregisterSecretUsageCommand(secretUsageId: usageId);
      await _deregisterSecretUsageUseCase.execute(command);
    } on SecretsApplicationError catch (e) {
      throw SecretsFacadeError.fromApplicationError(e);
    } catch (e) {
      throw UnknownSecretsError(e);
    }
  }

  Future<void> deregisterUsagesOfWalletConsumer({
    required String walletId,
  }) async {
    try {
      final command = DeregisterSecretUsagesOfConsumerCommand.ofWallet(
        walletId: walletId,
      );
      await _deregisterSecretUsagesOfConsumerUseCase.execute(command);
    } on SecretsApplicationError catch (e) {
      throw SecretsFacadeError.fromApplicationError(e);
    } catch (e) {
      throw UnknownSecretsError(e);
    }
  }
}
