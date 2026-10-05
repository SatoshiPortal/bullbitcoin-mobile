import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class AppStartupWalletPort {
  @useResult
  Future<Result<bool, AppStartupFailure>> hasMainnetBitcoinEncryptedBackup();
}
