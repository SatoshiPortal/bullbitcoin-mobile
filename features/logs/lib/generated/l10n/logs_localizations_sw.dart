// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class LogsLocalizationsSw extends LogsLocalizations {
  LogsLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Kumbukumbu';

  @override
  String get logsViewerDeleteButton => 'Futa';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'Shiriki';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'Kumbukumbu zimehamiishwa kwa mafanikio';

  @override
  String get logsExportFailedMessage => 'Imeshindwa kuhamisha kumbukumbu';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'Inaonyesha $shown kati ya $total kumbukumbu';
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
  String get logsViewerClearFilter => 'Futa kichujio';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'Chuja kwa Tarehe';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'Imenakiliwa';

  @override
  String get logsViewerDeleteTitle => 'Futa kumbukumbu';

  @override
  String get logsViewerDeleteConfirmation =>
      'Una uhakika unataka kufuta kumbukumbu zote? Kitendo hiki hakiwezi kutenduliwa.';

  @override
  String get logsDeletedMessage => 'Kumbukumbu zimefutwa';

  @override
  String get logsViewerCancelButton => 'Ghairi';

  @override
  String get logsShareOptionShare => 'Shiriki';

  @override
  String get logsShareOptionExport => 'Hamisha';

  @override
  String get oopsSomethingWentWrong => 'Lo! Hitilafu fulani imetokea';

  @override
  String get retry => 'Jaribu Tena';
}
