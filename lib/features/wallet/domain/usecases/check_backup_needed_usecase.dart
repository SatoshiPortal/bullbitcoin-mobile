import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../wallet_failure.dart';

class CheckBackupNeededUsecase {
  final Future<Result<bool, rb.RecoverBullFailure>> Function() _backupWarning;

  CheckBackupNeededUsecase({required this._backupWarning});

  @useResult
  Future<Result<bool, WalletFailure>> execute() async =>
      switch (await _backupWarning()) {
        Ok(:final value) => Ok(value),
        Err() => const Err(WalletStorageFailure()),
      };
}
