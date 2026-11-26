import 'package:primitives/primitives.dart';

sealed class FeeSourceSettingsFailure extends Failure {
  const FeeSourceSettingsFailure();
}

final class FeeSourceSettingsLoadFailure extends FeeSourceSettingsFailure {
  const FeeSourceSettingsLoadFailure();
}

final class FeeSourceSettingsSaveFailure extends FeeSourceSettingsFailure {
  const FeeSourceSettingsSaveFailure();
}
