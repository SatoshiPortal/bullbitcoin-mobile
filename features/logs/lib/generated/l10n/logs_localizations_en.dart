// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LogsLocalizationsEn extends LogsLocalizations {
  LogsLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Logs';

  @override
  String get logsViewerDeleteButton => 'Delete';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'Share';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'Logs exported successfully';

  @override
  String get logsExportFailedMessage => 'Failed to export logs';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'Showing $shown of $total logs';
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
  String get logsViewerClearFilter => 'Clear filter';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'Filter by Date';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'Copied to clipboard';

  @override
  String get logsViewerDeleteTitle => 'Delete logs';

  @override
  String get logsViewerDeleteConfirmation =>
      'Are you sure you want to delete all logs? This action cannot be undone.';

  @override
  String get logsDeletedMessage => 'Logs deleted';

  @override
  String get logsViewerCancelButton => 'Cancel';

  @override
  String get logsShareOptionShare => 'Share';

  @override
  String get logsShareOptionExport => 'Export';

  @override
  String get oopsSomethingWentWrong => 'Oops! Something went wrong';

  @override
  String get retry => 'Retry';
}
