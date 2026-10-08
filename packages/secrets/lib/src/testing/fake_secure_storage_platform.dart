import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// An in-memory `flutter_secure_storage`, substituted at the plugin's
/// own seam.
///
/// The package builds its `FlutterSecureStorage` itself and hands one to
/// nobody, so tests replace the layer *below* it:
/// `FlutterSecureStoragePlatform.instance`. That puts the package's real
/// key composition, JSON encoding and — the part that was never covered
/// before — its translation of `PlatformException` into
/// `KeystoreLockedException` inside the test.
///
/// The instance is process-wide, so [install] replaces whatever was
/// there. Two stores cannot be live at once: a test needing two
/// installs the second before the calls that should see it.
class FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> entries;

  /// When set, every read raises the iOS locked-keychain error, in the
  /// wire shape the plugin delivers it.
  bool locked;

  /// When set, every write, delete and deleteAll raises it too.
  ///
  /// Separate from [locked] because the two are not the same fault: a
  /// keychain can be readable and refuse a write, and the package's
  /// write paths have their own translation and their own callers. A
  /// fake that can only fail reads leaves every write and delete error
  /// path untested, which is how a test asserting "cleanup failure does
  /// not fail the wallet deletion" came to pass while exercising
  /// nothing.
  bool writesFail;

  /// Outcomes [write] and [delete] raise, in order, before falling back
  /// to succeeding. One entry is consumed per mutating call.
  final List<Object?> scriptedWrites;

  /// Outcomes [read] serves, in order, before falling back to
  /// [entries]: a `String?` is returned as-is, an [Exception] is thrown.
  /// Models the plugin's observed misbehaviour — null or "" for an entry
  /// that exists, or a platform error — one read at a time.
  final List<Object?> scripted;

  int reads = 0;

  /// The iOS accessibility class each entry was filed under, by key, as the plugin names it (`unlocked`, `first_unlock_this_device`). `null` unless the store was built with one: the store then ignores classes, as every test that predates them expects.
  ///
  /// When set, a write records the class it was sent with. An entry with no recorded class is visible to every query.
  final Map<String, String>? accessibilityOf;

  /// When set, reads, listings and existence checks see only entries filed under the class they ask for, and a write that misses the key under its class adds it — colliding, as `SecItemAdd` does, with the same key filed under another class. Deletes ignore the class. That is `flutter_secure_storage_darwin` 0.3.2 on a keychain that filters on `kSecAttrAccessible`; unset, the keychain ignores the class and only [accessibilityOf] records it.
  final bool filtersAccessibility;

  FakeSecureStoragePlatform({
    Map<String, String>? entries,
    this.locked = false,
    this.writesFail = false,
    List<Object?>? scripted,
    List<Object?>? scriptedWrites,
    this.accessibilityOf,
    this.filtersAccessibility = false,
  }) : assert(
         !filtersAccessibility || accessibilityOf != null,
         'filtering on classes needs a record of them',
       ),
       entries = entries ?? {},
       scriptedWrites = List.of(scriptedWrites ?? const []),
       // A growable copy: callers pass `List.filled(…)`, which is fixed-length, and `removeAt` on it throws `UnsupportedError`. That `Error` used to be swallowed into a failure by the boundary, and three tests passed without ever throwing what they had scripted.
       scripted = List.of(scripted ?? const []);

  /// Makes this the store the package will read. Returns itself so a
  /// helper can install and construct in one expression.
  FakeSecureStoragePlatform install() {
    FlutterSecureStoragePlatform.instance = this;
    return this;
  }

  /// `errSecInteractionNotAllowed`, as the plugin surfaces it. The
  /// package matches this code in three places because it has moved
  /// between them across plugin versions.
  static PlatformException get lockedError => PlatformException(
    code: 'Unexpected security result code',
    details: -25308,
  );

  /// `errSecDuplicateItem`, raised by an add on a key the keychain already holds.
  static PlatformException get duplicateError => PlatformException(
    code: 'Unexpected security result code',
    details: -25299,
  );

  /// Whether a query sent with [options] sees [key].
  bool _visible(String key, Map<String, String> options) {
    if (!filtersAccessibility) return true;
    final filed = accessibilityOf![key];
    return filed == null || filed == options['accessibility'];
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    reads++;
    if (locked) throw lockedError;
    if (scripted.isNotEmpty) {
      final next = scripted.removeAt(0);
      if (next is Exception) throw next;
      return next as String?;
    }
    return _visible(key, options) ? entries[key] : null;
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    reads++;
    if (locked) throw lockedError;
    return {
      for (final e in entries.entries)
        if (_visible(e.key, options)) e.key: e.value,
    };
  }

  /// Raises the next scripted mutation outcome, or the blanket failure.
  void _guardMutation() {
    if (scriptedWrites.isNotEmpty) {
      final next = scriptedWrites.removeAt(0);
      if (next is Exception) throw next;
      return;
    }
    if (writesFail) throw lockedError;
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _guardMutation();
    if (entries.containsKey(key) && !_visible(key, options)) {
      throw duplicateError;
    }
    entries[key] = value;
    final accessibility = options['accessibility'];
    if (accessibilityOf != null && accessibility != null) {
      accessibilityOf![key] = accessibility;
    }
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _guardMutation();
    entries.remove(key);
    accessibilityOf?.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _guardMutation();
    entries.clear();
    accessibilityOf?.clear();
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => entries.containsKey(key) && _visible(key, options);
}
