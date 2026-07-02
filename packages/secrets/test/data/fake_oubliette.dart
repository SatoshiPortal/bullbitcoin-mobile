import 'dart:typed_data';

import 'package:oubliette/oubliette.dart';

/// In-memory [Oubliette] for unit tests. Implements `useAndForget` directly
/// (fetch + zero-after-use) since the shared `OublietteFetch` mixin is
/// `@internal` to the oubliette package. Error-injection flags make each
/// primitive throw the sealed [OublietteException] the adapter must translate.
class FakeOubliette extends Oubliette {
  FakeOubliette() : super.internal();

  final Map<String, Uint8List> _m = {};

  /// Device locked / auth required → recoverable [AuthenticationFailedException].
  bool locked = false;

  /// Keyring/keystore service down → recoverable [BackendUnavailableException].
  bool backendUnavailable = false;

  /// Biometric enrolment changed → unrecoverable [KeyInvalidatedException].
  bool keyInvalidated = false;

  /// If set, every [init] throws this — drives the capability probe through each
  /// sealed [OublietteException] for the recoverable/structural drift guard.
  OublietteException? throwOnInit;

  /// Once [trash] has been called more than [trashSucceedsFor] times it throws
  /// [throwOnTrash]. Lets a test fail ONLY the probe's trailing cleanup trash
  /// (call #2) while the stale-clear trash (call #1) succeeds.
  OublietteException? throwOnTrash;
  int trashSucceedsFor = 0;
  int _trashCalls = 0;

  void _guard(String? key) {
    if (locked) throw AuthenticationFailedException(key: key);
    if (backendUnavailable) throw const BackendUnavailableException();
    if (keyInvalidated) {
      throw KeyInvalidatedException(keyAlias: key ?? 'fake');
    }
  }

  @override
  Future<void> init() async {
    if (throwOnInit != null) throw throwOnInit!;
    _guard(null);
  }

  @override
  Future<void> store(String key, Uint8List value) async {
    _guard(key);
    if (_m.containsKey(key)) throw StateError('exists: $key');
    _m[key] = Uint8List.fromList(value);
  }

  /// Raw fetch — not on the public [Oubliette] interface (moved to the
  /// internal `OublietteFetch` mixin), but needed here for `useAndForget`.
  Future<Uint8List?> fetch(String key) async {
    _guard(key);
    final v = _m[key];
    return v == null ? null : Uint8List.fromList(v);
  }

  @override
  Future<bool> exists(String key) async {
    _guard(key);
    return _m.containsKey(key);
  }

  @override
  Future<void> trash(String key) async {
    _guard(key);
    _trashCalls++;
    if (throwOnTrash != null && _trashCalls > trashSucceedsFor) {
      throw throwOnTrash!;
    }
    _m.remove(key);
  }

  @override
  Future<void> purge() async {
    _guard(null);
    _m.clear();
  }

  @override
  Future<List<String>> keys() async {
    _guard(null);
    return _m.keys.toList(growable: false);
  }

  @override
  Future<T?> useAndForget<T>(
    String key,
    Future<T> Function(Uint8List bytes) action,
  ) async {
    final bytes = await fetch(key);
    if (bytes == null) return null;
    try {
      return await action(bytes);
    } finally {
      try {
        bytes.fillRange(0, bytes.length, 0);
      } on UnsupportedError {
        // Unmodifiable buffer — cannot zero it.
      }
    }
  }
}
