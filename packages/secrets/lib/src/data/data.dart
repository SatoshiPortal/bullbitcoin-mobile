/// Where secrets are kept, and the rules for getting them back.
///
/// The only module that touches `flutter_secure_storage`. What it hands
/// upward is live material and descriptions, never the keystore, never
/// the on-disk models — those stay behind this file.
library;

export 'owner_keychain.dart' show OwnerKeychain, OwnerKey;
export 'boundary.dart'
    show
        boundary,
        inventorySessionChangedFailure,
        inventoryCredentialRequiredFailure,
        inventoryLockedFailure;
export 'database_key_repository.dart' show DatabaseKeyRepository;
export 'database_worker.dart' show captureDatabaseWorkerOpener;
export 'encrypted_database.dart' show openEncryptedDatabase;
export 'exceptions.dart';
export 'fss_datasource.dart' show FlutterSecureStorageDatasource;
export 'inventory_store.dart' show inventoryModule;
export 'models/key_model.dart' show KeyKind;
export 'secret_repository.dart' show SecretRepository;
