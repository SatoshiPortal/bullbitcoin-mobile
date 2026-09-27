import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/repositories/startup_storage_repository.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detects the retired Android storage generation from its public marker.
/// No seed-store operation is needed to decide whether restoration is required.
class SharedPreferencesStartupStorageRepository
    implements StartupStorageRepository {
  final bool _isAndroid;

  SharedPreferencesStartupStorageRepository({required this._isAndroid});

  @override
  @useResult
  Future<Result<bool, AppStartupFailure>> requiresLegacyRestore() async {
    if (!_isAndroid) return const Ok(false);
    try {
      final preferences = await SharedPreferences.getInstance();
      final marker = preferences.get('seed_store_type');
      if (marker == null) return const Ok(false);
      if (marker is! String) return _invalidMarker();
      final decoded = jsonDecode(marker);
      if (decoded is! Map<String, dynamic>) return _invalidMarker();
      return switch (decoded['storageLibrary']) {
        'fss9' => const Ok(true),
        'fss10' => const Ok(false),
        _ => _invalidMarker(),
      };
    } on Exception catch (e) {
      // The marker's contents never enter a failure or log message.
      return Err(
        AppStartupWalletCheckFailure('storage generation: ${e.runtimeType}'),
      );
    }
  }

  static Result<bool, AppStartupFailure> _invalidMarker() => const Err(
    AppStartupWalletCheckFailure('invalid storage generation marker'),
  );
}
