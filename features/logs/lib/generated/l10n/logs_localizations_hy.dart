// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Armenian (`hy`).
class LogsLocalizationsHy extends LogsLocalizations {
  LogsLocalizationsHy([String locale = 'hy']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Մատյաններ';

  @override
  String get logsViewerDeleteButton => 'Ջնջել';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'Կիսվել';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'Մատյանները հաջողությամբ արտահանվեցին';

  @override
  String get logsExportFailedMessage => 'Մատյանների արտահանումը ձախողվեց';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'Ցուցադրվում է $shown $total-ից';
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
  String get logsViewerClearFilter => 'Մաքրել զտիչը';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'Զտել ըստ ամսաթվի';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'Պատճենվեց սեղմատախտակին';

  @override
  String get logsViewerDeleteTitle => 'Ջնջել մատյանները';

  @override
  String get logsViewerDeleteConfirmation =>
      'Համոզվա՞ծ եք, որ ցանկանում եք ջնջել բոլոր մատյանները։ Այս գործողությունը հնարավոր չէ հետարկել։';

  @override
  String get logsDeletedMessage => 'Մատյանները ջնջվեցին';

  @override
  String get logsViewerCancelButton => 'Չեղարկել';

  @override
  String get logsShareOptionShare => 'Կիսվել';

  @override
  String get logsShareOptionExport => 'Արտահանել';

  @override
  String get oopsSomethingWentWrong => 'Ուպս։ Ինչ-որ բան սխալ գնաց';

  @override
  String get retry => 'Կրկին փորձել';
}
