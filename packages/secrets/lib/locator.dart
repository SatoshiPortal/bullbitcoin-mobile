import 'package:get_it/get_it.dart';
import 'package:secrets/src/data/adapters/backup_vault_adapter.dart';
import 'package:secrets/src/data/adapters/bip85_adapter.dart';
import 'package:secrets/src/data/adapters/key_derivation_adapter.dart';
import 'package:secrets/src/data/adapters/signer_adapter.dart';
import 'package:secrets/src/data/adapters/swap_signer_adapter.dart';
import 'package:secrets/src/data/adapters/flutter_secure_storage_adapter.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/seed_adapter.dart';
import 'package:secrets/src/domain/ports/backup_vault_port.dart';
import 'package:secrets/src/domain/ports/bip85_port.dart';
import 'package:secrets/src/domain/ports/key_derivation_port.dart';
import 'package:secrets/src/domain/ports/seed_index_port.dart';
import 'package:secrets/src/domain/ports/seed_port.dart';
import 'package:secrets/src/domain/ports/signer_port.dart';
import 'package:secrets/src/domain/ports/swap_signer_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/ui/mnemonic_reader.dart';

/// Wires `secrets` into a `get_it` container. Mirrors the app's `SeedLocator`
/// phases. The internal `SecretStorePort`/`MnemonicReader` are registered by their
/// in-package types and never exported — consumers only ever resolve the public
/// ports.
///
/// Prerequisite: the APP must register a [SeedIndexPort] (its Drift-backed impl)
/// before [registerRepositories] is called.
class SecretsLocator {
  const SecretsLocator._();

  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<SecretStorePort>(
      () => FssSecretStoreAdapter(FlutterSecureStorageAdapter.standard()),
    );
    locator.registerLazySingleton<MnemonicReader>(
      () => MnemonicReader(locator<SecretStorePort>()),
    );
  }

  static void registerRepositories(GetIt locator) {
    // Fail fast: the app MUST register its Drift-backed SeedIndexPort first,
    // else the missing dependency would only surface deep in the first seed
    // flow. A runtime throw (NOT an assert — asserts are stripped in release,
    // which would let a production build hit the obscure get_it error instead).
    if (!locator.isRegistered<SeedIndexPort>()) {
      throw StateError(
        'SecretsLocator.registerRepositories: a SeedIndexPort must be '
        'registered first (the app provides the Drift-backed implementation).',
      );
    }
    locator.registerLazySingleton<SeedPort>(
      () => SeedAdapter(
        store: locator<SecretStorePort>(),
        index: locator<SeedIndexPort>(),
      ),
    );
    locator.registerLazySingleton<KeyDerivationPort>(
      () => KeyDerivationAdapter(locator<SecretStorePort>()),
    );
    locator.registerLazySingleton<SignerPort>(
      () => SignerAdapter(locator<SecretStorePort>()),
    );
    locator.registerLazySingleton<Bip85Port>(
      () => Bip85Adapter(locator<SecretStorePort>()),
    );
    locator.registerLazySingleton<SwapSignerPort>(
      () => SwapSignerAdapter(locator<SecretStorePort>()),
    );
    locator.registerLazySingleton<BackupVaultPort>(
      () => BackupVaultAdapter(
        store: locator<SecretStorePort>(),
        repository: locator<SeedPort>(),
      ),
    );
  }
}
