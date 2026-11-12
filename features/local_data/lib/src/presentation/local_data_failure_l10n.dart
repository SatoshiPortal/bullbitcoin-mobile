import 'package:bull_local_data/generated/l10n/local_data_localizations.dart';
import 'package:bull_local_data/src/domain/local_data_failure.dart';
import 'package:bull_local_data/src/domain/local_database.dart';

extension LocalDataFailureL10n on LocalDataFailure {
  /// The title of the gate screen for this failure.
  String title(LocalDataLocalizations loc) => switch (this) {
    LocalDataKeystoreLockedFailure() => loc.localDataLockedTitle,
    LocalDataUnrecoverableFailure() ||
    LocalDataUnexpectedFailure() => loc.localDataRecoveryTitle,
  };

  /// What happened, for the user. Never the log message.
  String message(LocalDataLocalizations loc) => switch (this) {
    LocalDataKeystoreLockedFailure() => loc.localDataLockedMessage,
    LocalDataInconsistentFailure() => loc.localDataRecoveryInconsistentMessage,
    LocalDataUnrecoverableFailure(:final database) => switch (database) {
      LocalDatabase.main => loc.localDataRecoveryMainMessage,
      LocalDatabase.payjoin => loc.localDataRecoveryPayjoinMessage,
    },
    LocalDataUnexpectedFailure() => loc.localDataResetFailedMessage,
  };
}
