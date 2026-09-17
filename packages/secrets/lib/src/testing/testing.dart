/// The test seam, as a module: what `package:secrets/testing.dart` exports.
///
/// Under the same rules as the four others — cross-module imports come
/// through this file — and the only module besides `data/` allowed to
/// touch the keystore plugin, because it *is* a keystore.
library;

export 'fake_secure_storage_platform.dart' show FakeSecureStoragePlatform;
