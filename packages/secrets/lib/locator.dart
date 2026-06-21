import 'package:get_it/get_it.dart';
import 'package:secrets/src/crypto/backup_vault_port_impl.dart';
import 'package:secrets/src/crypto/bip85_port_impl.dart';
import 'package:secrets/src/crypto/key_derivation_port_impl.dart';
import 'package:secrets/src/crypto/signer_port_impl.dart';
import 'package:secrets/src/crypto/swap_signer_port_impl.dart';
import 'package:secrets/src/data/datasources/flutter_secure_storage_adapter.dart';
import 'package:secrets/src/data/datasources/fss_secret_store.dart';
import 'package:secrets/src/data/seed_repository_impl.dart';
import 'package:secrets/src/domain/backup_vault_port.dart';
import 'package:secrets/src/domain/bip85_port.dart';
import 'package:secrets/src/domain/key_derivation_port.dart';
import 'package:secrets/src/domain/seed_index.dart';
import 'package:secrets/src/domain/seed_repository.dart';
import 'package:secrets/src/domain/signer_port.dart';
import 'package:secrets/src/domain/swap_signer_port.dart';
import 'package:secrets/src/storage/secret_store.dart';
import 'package:secrets/src/ui/mnemonic_reader.dart';

/// Wires `secrets` into a `get_it` container. Mirrors the app's `SeedLocator`
/// phases. The internal `SecretStore`/`MnemonicReader` are registered by their
/// in-package types and never exported — consumers only ever resolve the public
/// ports.
///
/// Prerequisite: the APP must register a [SeedIndex] (its Drift-backed impl)
/// before [registerRepositories] is called.
class SecretsLocator {
  const SecretsLocator._();

  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<SecretStore>(
      () => FssSecretStore(FlutterSecureStorageAdapter.standard()),
    );
    locator.registerLazySingleton<MnemonicReader>(
      () => MnemonicReader(locator<SecretStore>()),
    );
  }

  static void registerRepositories(GetIt locator) {
    // Fail fast: the app MUST register its Drift-backed SeedIndex first, else
    // the missing dependency would only surface deep in the first seed flow.
    assert(
      locator.isRegistered<SeedIndex>(),
      'SecretsLocator.registerRepositories: a SeedIndex must be registered '
      'first (the app provides the Drift-backed implementation).',
    );
    locator.registerLazySingleton<SeedRepository>(
      () => SeedRepositoryImpl(
        store: locator<SecretStore>(),
        index: locator<SeedIndex>(),
      ),
    );
    locator.registerLazySingleton<KeyDerivationPort>(
      () => KeyDerivationPortImpl(locator<SecretStore>()),
    );
    locator.registerLazySingleton<SignerPort>(
      () => SignerPortImpl(locator<SecretStore>()),
    );
    locator.registerLazySingleton<Bip85Port>(
      () => Bip85PortImpl(locator<SecretStore>()),
    );
    locator.registerLazySingleton<SwapSignerPort>(
      () => SwapSignerPortImpl(locator<SecretStore>()),
    );
    locator.registerLazySingleton<BackupVaultPort>(
      () => BackupVaultPortImpl(
        store: locator<SecretStore>(),
        repository: locator<SeedRepository>(),
      ),
    );
  }
}
