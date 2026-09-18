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
/// [SecretStoreLockedException] inside the test.
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

  FakeSecureStoragePlatform({
    Map<String, String>? entries,
    this.locked = false,
    this.writesFail = false,
    List<Object?>? scripted,
    List<Object?>? scriptedWrites,
  }) : entries = entries ?? {},
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
    return entries[key];
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    reads++;
    if (locked) throw lockedError;
    return Map<String, String>.from(entries);
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
    entries[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _guardMutation();
    entries.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _guardMutation();
    entries.clear();
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => entries.containsKey(key);
}
