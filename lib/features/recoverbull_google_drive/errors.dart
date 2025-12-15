import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:flutter/material.dart';

abstract class RecoverBullGoogleDriveError {
  String toTranslated(BuildContext context);
}

class FetchAllDriveFilesError extends RecoverBullGoogleDriveError {
  @override
  String toTranslated(BuildContext context) {
    return context.loc.recoverbullGoogleDriveErrorFetchFailed;
  }
}
