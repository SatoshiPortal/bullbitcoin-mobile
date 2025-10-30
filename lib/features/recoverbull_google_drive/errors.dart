import 'package:bb_mobile/core/errors/bull_exception.dart';

class RecoverBullGoogleDriveError extends BullException {
  RecoverBullGoogleDriveError(super.message);
}

class FetchAllDriveFilesError extends RecoverBullGoogleDriveError {
  FetchAllDriveFilesError() : super('Failed to fetch all drive backups');
}
