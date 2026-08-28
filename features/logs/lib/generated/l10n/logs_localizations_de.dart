// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class LogsLocalizationsDe extends LogsLocalizations {
  LogsLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Protokolle';

  @override
  String get logsViewerDeleteButton => 'Löschen';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'Teilen';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'Protokolle erfolgreich exportiert';

  @override
  String get logsExportFailedMessage => 'Export der Protokolle fehlgeschlagen';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return '$shown von $total Protokollen werden angezeigt';
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
  String get logsViewerClearFilter => 'Filter löschen';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'Nach Datum filtern';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'In die Zwischenablage kopiert.';

  @override
  String get logsViewerDeleteTitle => 'Logs löschen';

  @override
  String get logsViewerDeleteConfirmation =>
      'Möchten Sie wirklich alle Logs löschen? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get logsDeletedMessage => 'Logs gelöscht';

  @override
  String get logsViewerCancelButton => 'Abbrechen';

  @override
  String get logsShareOptionShare => 'Teilen';

  @override
  String get logsShareOptionExport => 'Exportieren';

  @override
  String get oopsSomethingWentWrong => 'Ups! Etwas ist schief gelaufen';

  @override
  String get retry => 'Wiederholen';
}
