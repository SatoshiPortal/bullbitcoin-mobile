// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Georgian (`ka`).
class LogsLocalizationsKa extends LogsLocalizations {
  LogsLocalizationsKa([String locale = 'ka']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'ჟურნალები';

  @override
  String get logsViewerDeleteButton => 'წაშლა';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'გაზიარება';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'ჟურნალები წარმატებით ექსპორტირებულია';

  @override
  String get logsExportFailedMessage => 'ჟურნალების ექსპორტი ვერ მოხერხდა';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'ნაჩვენებია $shown $total-დან';
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
  String get logsViewerClearFilter => 'ფილტრის გასუფთავება';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'თარიღის მიხედვით გაფილტრვა';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'დაკოპირდა';

  @override
  String get logsViewerDeleteTitle => 'ჟურნალების წაშლა';

  @override
  String get logsViewerDeleteConfirmation =>
      'დარწმუნებული ხართ, რომ გსურთ ყველა ჟურნალის წაშლა? ეს მოქმედება შეუქცევადია.';

  @override
  String get logsDeletedMessage => 'ჟურნალები წაშლილია';

  @override
  String get logsViewerCancelButton => 'გაუქმება';

  @override
  String get logsShareOptionShare => 'გაზიარება';

  @override
  String get logsShareOptionExport => 'ექსპორტი';

  @override
  String get oopsSomethingWentWrong => 'უპს! რაღაც ვერ მოხერხდა';

  @override
  String get retry => 'ხელახლა ცდა';
}
