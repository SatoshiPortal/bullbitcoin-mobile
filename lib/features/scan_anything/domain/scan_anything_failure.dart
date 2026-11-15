import 'package:primitives/primitives.dart' show Failure;

sealed class ScanAnythingFailure extends Failure {
  const ScanAnythingFailure([super.logMessage]);
}

final class ScanAnythingEmptyInputFailure extends ScanAnythingFailure {
  const ScanAnythingEmptyInputFailure();
}

final class ScanAnythingUnrecognizedFailure extends ScanAnythingFailure {
  const ScanAnythingUnrecognizedFailure();
}

final class ScanAnythingLabelsImportFailure extends ScanAnythingFailure {
  const ScanAnythingLabelsImportFailure([super.logMessage]);
}

final class ScanAnythingUnexpectedFailure extends ScanAnythingFailure {
  const ScanAnythingUnexpectedFailure([super.logMessage]);
}
