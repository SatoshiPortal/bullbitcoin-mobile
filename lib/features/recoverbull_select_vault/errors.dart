import 'package:bb_mobile/core/errors/bull_exception.dart';

class RecoverBullSelectVaultError extends BullException {
  RecoverBullSelectVaultError(super.message);
}

class FetchAllDriveFilesError extends RecoverBullSelectVaultError {
  FetchAllDriveFilesError() : super('Failed to fetch all drive backups');
}

class FileNotSelectedError extends RecoverBullSelectVaultError {
  FileNotSelectedError() : super('File not selected');
}

class SelectFileFromPathError extends RecoverBullSelectVaultError {
  SelectFileFromPathError()
    : super('Failed to select file from custom location');
}

class RecoverbullBackupFileNotValidError extends RecoverBullSelectVaultError {
  RecoverbullBackupFileNotValidError()
    : super('Recoverbull backup file is not valid');
}
