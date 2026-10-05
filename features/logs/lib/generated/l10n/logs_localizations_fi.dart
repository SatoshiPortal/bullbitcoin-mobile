// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Finnish (`fi`).
class LogsLocalizationsFi extends LogsLocalizations {
  LogsLocalizationsFi([String locale = 'fi']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Lokitiedot';

  @override
  String get logsViewerDeleteButton => 'Poista';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'Jaa';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'Lokit viety onnistuneesti';

  @override
  String get logsExportFailedMessage => 'Lokien vienti epäonnistui';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'Näytetään $shown / $total lokia';
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
  String get logsViewerClearFilter => 'Tyhjennä suodatin';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'Suodata päivämäärän mukaan';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'Kopioitu leikepöydälle';

  @override
  String get logsViewerDeleteTitle => 'Poista lokit';

  @override
  String get logsViewerDeleteConfirmation =>
      'Haluatko varmasti poistaa kaikki lokit? Tätä toimintoa ei voi peruuttaa.';

  @override
  String get logsDeletedMessage => 'Lokit poistettu';

  @override
  String get logsViewerCancelButton => 'Peruuta';

  @override
  String get logsShareOptionShare => 'Jaa';

  @override
  String get logsShareOptionExport => 'Vie';

  @override
  String get oopsSomethingWentWrong => 'Hups! Jotain meni pieleen';

  @override
  String get retry => 'Yritä uudelleen';
}
