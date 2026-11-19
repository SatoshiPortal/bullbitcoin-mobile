import 'dart:convert';

import 'package:ark/ark.dart';
import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ark_failure.dart';
import '../domain/repositories/ark_preferences_repository.dart';

/// Routing preference only, never custody or proof an account is empty. Async
/// preferences avoid per-isolate caches; background protective renewal does
/// not consult this flag to decide whether existing funds need protection.
final class SharedPreferencesArkPreferencesRepository
    implements ArkPreferencesRepository {
  final SharedPreferencesAsync _preferences;
  SharedPreferencesArkPreferencesRepository()
    : _preferences = SharedPreferencesAsync();
  String _key(ArkAccountId account) =>
      'ark.enabled.${sha256.convert(utf8.encode(account.canonical))}';
  @override
  Future<Result<bool, ArkFailure>> isEnabled(ArkAccountId account) async {
    try {
      return Ok(await _preferences.getBool(_key(account)) ?? false);
    } on Exception catch (_) {
      return const Err(ArkFeatureStorageFailure());
    }
  }

  @override
  Future<Result<void, ArkFailure>> setEnabled(
    ArkAccountId account,
    bool enabled,
  ) async {
    try {
      await _preferences.setBool(_key(account), enabled);
      return const Ok(null);
    } on Exception catch (_) {
      return const Err(ArkFeatureStorageFailure());
    }
  }
}
