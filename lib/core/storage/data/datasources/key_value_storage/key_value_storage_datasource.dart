/// The app's shared secure storage.
///
/// Deliberately blind to the user's seeds. Those live in the same OS
/// keystore under a `seed_` prefix, but they belong to the `secrets`
/// package, which owns its own `flutter_secure_storage` instance. This
/// interface adapts the package-owned application storage for swaps, exchange and app_unlock; the unlock credential uses its dedicated capability.
///
/// There is no `deleteAll`: on a store that shares a keystore with seed
/// material, one call would destroy every wallet on the device, and
/// nothing in the app has ever needed it.
abstract class KeyValueStorageDatasource<T> {
  Future<void> saveValue({required String key, required T value});

  /// Every entry the app owns. Entries under the `secrets` namespace are
  /// filtered out rather than returned and ignored.
  Future<Map<String, T>> getAll();

  Future<T?> getValue(String key);
  Future<bool> hasValue(String key);
  Future<void> deleteValue(String key);
}
