import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/scan_anything/domain/scan_anything_failure.dart';
import 'package:flutter/widgets.dart';

extension ScanAnythingFailureL10n on ScanAnythingFailure {
  String toTranslated(BuildContext context) => switch (this) {
    ScanAnythingEmptyInputFailure() => context.loc.scanAnythingErrorEmpty,
    ScanAnythingUnrecognizedFailure() =>
      context.loc.scanAnythingErrorUnrecognized,
    ScanAnythingLabelsImportFailure() =>
      context.loc.scanAnythingErrorLabelsImport,
    ScanAnythingUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
