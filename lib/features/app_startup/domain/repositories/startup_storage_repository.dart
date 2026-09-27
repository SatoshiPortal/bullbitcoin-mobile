import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:meta/meta.dart';

/// Reads the persisted storage generation without opening the seed store.
abstract interface class StartupStorageRepository {
  @useResult
  Future<Result<bool, AppStartupFailure>> requiresLegacyRestore();
}
