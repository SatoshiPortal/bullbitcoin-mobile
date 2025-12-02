import 'package:bb_mobile/core/errors/bull_exception.dart';

class RecoverBullGoogleDriveError extends BullException {
  RecoverBullGoogleDriveError(super.message);
}

class FetchDriveVaultsFailedError extends RecoverBullGoogleDriveError {
  FetchDriveVaultsFailedError()
    : super('Failed to fetch vaults from Google Drive');
}

class SelectDriveVaultFailedError extends RecoverBullGoogleDriveError {
  SelectDriveVaultFailedError() : super('Failed to select vault from Google Drive');
}

class DeleteDriveVaultFailedError extends RecoverBullGoogleDriveError {
  DeleteDriveVaultFailedError() : super('Failed to delete vault from Google Drive');
}

class ExportDriveVaultFailedError extends RecoverBullGoogleDriveError {
  ExportDriveVaultFailedError() : super('Failed to export vault from Google Drive');
}
