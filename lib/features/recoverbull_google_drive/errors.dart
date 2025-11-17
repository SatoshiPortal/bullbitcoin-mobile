import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

class RecoverBullGoogleDriveError extends BullException {
  RecoverBullGoogleDriveError(super.message);
}

class FetchAllDriveFilesError extends RecoverBullGoogleDriveError {
  FetchAllDriveFilesError(BuildContext context)
      : super(context.loc.recoverbullGoogleDriveErrorFetchFailed);
}
