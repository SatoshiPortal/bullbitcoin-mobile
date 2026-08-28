// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class LogsLocalizationsPt extends LogsLocalizations {
  LogsLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Logs';

  @override
  String get logsViewerDeleteButton => 'Eliminar';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'Partilhar';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'Registos exportados com sucesso';

  @override
  String get logsExportFailedMessage => 'Falha ao exportar os registos';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'A mostrar $shown de $total registos';
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
  String get logsViewerClearFilter => 'Limpar filtro';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'Filtrar por data';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'Copiado para clipboard';

  @override
  String get logsViewerDeleteTitle => 'Eliminar registos';

  @override
  String get logsViewerDeleteConfirmation =>
      'Tem a certeza de que deseja eliminar todos os registos? Esta ação não pode ser desfeita.';

  @override
  String get logsDeletedMessage => 'Registros excluídos';

  @override
  String get logsViewerCancelButton => 'Cancelar';

  @override
  String get logsShareOptionShare => 'Partilhar';

  @override
  String get logsShareOptionExport => 'Exportar';

  @override
  String get oopsSomethingWentWrong => 'Oops! Algo correu mal';

  @override
  String get retry => 'Tentar novamente';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class LogsLocalizationsPtBr extends LogsLocalizationsPt {
  LogsLocalizationsPtBr() : super('pt_BR');

  @override
  String get logSettingsLogsTitle => 'Logs';

  @override
  String get logsViewerDeleteButton => 'Excluir';

  @override
  String get logsViewerShareButton => 'Compartilhar';

  @override
  String get logsExportedMessage => 'Registros exportados com sucesso';

  @override
  String get logsExportFailedMessage => 'Falha ao exportar os registros';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'Mostrando $shown de $total registros';
  }

  @override
  String get logsViewerClearFilter => 'Limpar filtro';

  @override
  String get logsViewerFilterByDate => 'Filtrar por data';

  @override
  String get copiedToClipboardMessage => 'Copiado para clipboard';

  @override
  String get logsViewerDeleteTitle => 'Excluir registros';

  @override
  String get logsViewerDeleteConfirmation =>
      'Tem certeza de que deseja excluir todos os registros? Esta ação não pode ser desfeita.';

  @override
  String get logsDeletedMessage => 'Registros excluídos';

  @override
  String get logsViewerCancelButton => 'Cancelar';

  @override
  String get logsShareOptionShare => 'Compartilhar';

  @override
  String get logsShareOptionExport => 'Exportar';

  @override
  String get oopsSomethingWentWrong => 'Oops! Algo correu mal';

  @override
  String get retry => 'Tentar novamente';
}
