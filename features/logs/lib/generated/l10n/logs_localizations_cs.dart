// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class LogsLocalizationsCs extends LogsLocalizations {
  LogsLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Přihlášení';

  @override
  String get logsViewerDeleteButton => 'Smazat';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'Sdílet';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'Záznamy byly úspěšně exportovány';

  @override
  String get logsExportFailedMessage => 'Export záznamů se nezdařil';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'Zobrazeno $shown z $total záznamů';
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
  String get logsViewerClearFilter => 'Vymazat filtr';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'Filtrovat podle data';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'Připojil se do schránky';

  @override
  String get logsViewerDeleteTitle => 'Smazat logy';

  @override
  String get logsViewerDeleteConfirmation =>
      'Opravdu chcete smazat všechny logy? Tuto akci nelze vrátit zpět.';

  @override
  String get logsDeletedMessage => 'Logy smazány';

  @override
  String get logsViewerCancelButton => 'Zrušit';

  @override
  String get logsShareOptionShare => 'Sdílet';

  @override
  String get logsShareOptionExport => 'Exportovat';

  @override
  String get oopsSomethingWentWrong => 'Oops! Něco šlo špatně';

  @override
  String get retry => 'Zkusit znovu';
}
