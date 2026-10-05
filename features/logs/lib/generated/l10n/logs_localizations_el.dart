// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Modern Greek (`el`).
class LogsLocalizationsEl extends LogsLocalizations {
  LogsLocalizationsEl([String locale = 'el']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Logs';

  @override
  String get logsViewerDeleteButton => 'Διαγραφή';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'Κοινοποίηση';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'Τα αρχεία καταγραφής εξήχθησαν επιτυχώς';

  @override
  String get logsExportFailedMessage => 'Αποτυχία εξαγωγής αρχείων καταγραφής';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'Εμφάνιση $shown από $total αρχεία καταγραφής';
  }

  @override
  String get logsViewerCollapseAll => 'Collapse all';

  @override
  String get logsViewerWrapAll => 'Wrap all';

  @override
  String get logsViewerEmpty => 'No logs yet';

  @override
  String get logsViewerNoMatches => 'No logs match the active filters';

  @override
  String get logsViewerClearFilter => 'Εκκαθάριση φίλτρου';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'Φιλτράρισμα κατά ημερομηνία';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'Κόπηκε να πετάξε';

  @override
  String get logsViewerDeleteTitle => 'Διαγραφή αρχείων καταγραφής';

  @override
  String get logsViewerDeleteConfirmation =>
      'Είστε βέβαιοι ότι θέλετε να διαγράψετε όλα τα αρχεία καταγραφής; Αυτή η ενέργεια δεν μπορεί να αναιρεθεί.';

  @override
  String get logsDeletedMessage => 'Τα αρχεία καταγραφής διαγράφηκαν';

  @override
  String get logsViewerCancelButton => 'Ακύρωση';

  @override
  String get logsShareOptionShare => 'Κοινοποίηση';

  @override
  String get logsShareOptionExport => 'Εξαγωγή';

  @override
  String get oopsSomethingWentWrong => 'Oops! Κάτι πήγε στραβά';

  @override
  String get retry => 'Επανάληψη';
}
