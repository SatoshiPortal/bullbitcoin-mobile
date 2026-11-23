import 'package:access/access.dart';
import 'package:startup/src/domain/app_startup_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

class GetStartupPinStatusUsecase {
  final Access _access;

  const GetStartupPinStatusUsecase(this._access);

  Future<Result<bool, AppStartupFailure>> execute() async {
    switch (await _access.checkPinCodeExists()) {
      case Ok(:final value):
        return Ok(value);
      case Err(failure: AccessUnlockKeychainLockedFailure()):
        return const Err(AppStartupKeychainLockedFailure());
      case Err(:final failure):
        log.severe(
          message: 'PIN check failed at startup',
          error: failure,
          trace: StackTrace.current,
        );
        return const Err(AppStartupPinCheckFailure());
    }
  }
}
