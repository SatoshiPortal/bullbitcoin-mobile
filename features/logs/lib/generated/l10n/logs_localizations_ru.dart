// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class LogsLocalizationsRu extends LogsLocalizations {
  LogsLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Журналы';

  @override
  String get logsViewerDeleteButton => 'Удалить';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'Поделиться';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'Журналы успешно экспортированы';

  @override
  String get logsExportFailedMessage => 'Не удалось экспортировать журналы';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'Показано $shown из $total записей';
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
  String get logsViewerClearFilter => 'Очистить фильтр';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'Фильтр по дате';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'Копируется в буфер обмена';

  @override
  String get logsViewerDeleteTitle => 'Удалить журналы';

  @override
  String get logsViewerDeleteConfirmation =>
      'Вы уверены, что хотите удалить все журналы? Это действие нельзя отменить.';

  @override
  String get logsDeletedMessage => 'Журналы удалены';

  @override
  String get logsViewerCancelButton => 'Отмена';

  @override
  String get logsShareOptionShare => 'Поделиться';

  @override
  String get logsShareOptionExport => 'Экспорт';

  @override
  String get oopsSomethingWentWrong => 'Упс! Что-то не так';

  @override
  String get retry => 'Повторить';
}
