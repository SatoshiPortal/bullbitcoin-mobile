/// Checks whether a verified backup permits creating a PIN.
class CheckPinBackupUsecase {
  final Future<bool> Function() _hasVerifiedBackup;

  const CheckPinBackupUsecase(this._hasVerifiedBackup);

  Future<bool> execute() => _hasVerifiedBackup();
}
