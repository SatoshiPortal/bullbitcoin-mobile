import 'package:bb_mobile/core/primitives/secrets/secret.dart';
import 'package:bb_mobile/core/primitives/secrets/secret_usage_purpose.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/application/usecases/create_new_mnemonic_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/deregister_secret_usage_with_fingerprint_check_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/get_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/import_mnemonic_secret_usecase.dart';
import 'package:bb_mobile/features/secrets/public/secrets_facade_errors.dart';

class SecretsFacade {
  final CreateNewMnemonicSecretUseCase _createNewMnemonicSecretUseCase;
  final ImportMnemonicSecretUseCase _importMnemonicSecretUseCase;
  final GetSecretUseCase _getSecretUseCase;
  final DeregisterSecretUsageWithFingerprintCheckUseCase
  _deregisterSecretUsageWithFingerprintCheck;

  SecretsFacade({
    required CreateNewMnemonicSecretUseCase createNewSecretMnemonicUseCase,
    required ImportMnemonicSecretUseCase importSecretMnemonicUseCase,
    required GetSecretUseCase getSecretUseCase,
    required DeregisterSecretUsageWithFingerprintCheckUseCase
    deregisterSecretUsageWithFingerprintCheck,
  }) : _createNewMnemonicSecretUseCase = createNewSecretMnemonicUseCase,
       _importMnemonicSecretUseCase = importSecretMnemonicUseCase,
       _getSecretUseCase = getSecretUseCase,
       _deregisterSecretUsageWithFingerprintCheck =
           deregisterSecretUsageWithFingerprintCheck;

  Future<({String fingerprint, MnemonicSecret secret})> createNewMnemonic({
    String? passphrase,
    required SecretUsagePurpose purpose,
    required String consumerRef,
  }) async {
    try {
      final command = CreateNewMnemonicSecretCommand(
        passphrase: passphrase,
        purpose: purpose,
        consumerRef: consumerRef,
      );
      final result = await _createNewMnemonicSecretUseCase.execute(command);
      return (fingerprint: result.fingerprint, secret: result.secret);
    } on SecretsApplicationError catch (e) {
      throw SecretsFacadeError.fromApplicationError(e);
    } catch (e) {
      throw UnknownSecretsFacadeError(e);
    }
  }

  Future<String> importMnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
    required SecretUsagePurpose purpose,
    required String consumerRef,
  }) async {
    try {
      final command = ImportMnemonicSecretCommand(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
        purpose: purpose,
        consumerRef: consumerRef,
      );
      final result = await _importMnemonicSecretUseCase.execute(command);
      return result.fingerprint;
    } on SecretsApplicationError catch (e) {
      throw SecretsFacadeError.fromApplicationError(e);
    } catch (e) {
      throw UnknownSecretsFacadeError(e);
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
      throw UnknownSecretsFacadeError(e);
    }
  }

  Future<void> deregisterUsage({
    required String fingerprint,
    required String consumerRef,
    required SecretUsagePurpose purpose,
  }) async {
    try {
      final command = DeregisterSecretUsageWithFingerprintCheckCommand(
        fingerprint: fingerprint,
        purpose: purpose,
        consumerRef: consumerRef,
      );
      await _deregisterSecretUsageWithFingerprintCheck.execute(command);
    } on SecretUsageNotFoundError {
      // If no usage found, nothing to deregister
      return;
    } on SecretsApplicationError catch (e) {
      throw SecretsFacadeError.fromApplicationError(e);
    } catch (e) {
      throw UnknownSecretsFacadeError(e);
    }
  }
}
