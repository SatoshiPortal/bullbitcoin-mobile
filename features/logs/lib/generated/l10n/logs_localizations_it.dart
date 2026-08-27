// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class LogsLocalizationsIt extends LogsLocalizations {
  LogsLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Logs';

  @override
  String get logsViewerDeleteButton => 'Elimina';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'Condividi';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'Registri esportati con successo';

  @override
  String get logsExportFailedMessage =>
      'Esportazione dei registri non riuscita';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'Visualizzazione di $shown su $total registri';
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
  String get logsViewerClearFilter => 'Cancella filtro';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'Filtra per data';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'Copied a clipboard';

  @override
  String get logsViewerDeleteTitle => 'Elimina registri';

  @override
  String get logsViewerDeleteConfirmation =>
      'Sei sicuro di voler eliminare tutti i registri? Questa azione non può essere annullata.';

  @override
  String get logsDeletedMessage => 'Registri eliminati';

  @override
  String get logsViewerCancelButton => 'Annulla';

  @override
  String get logsShareOptionShare => 'Condividi';

  @override
  String get logsShareOptionExport => 'Esporta';

  @override
  String get oopsSomethingWentWrong => 'Ops! Qualcosa non va';

  @override
  String get retry => 'Riprova';
}
