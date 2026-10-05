// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class LogsLocalizationsUk extends LogsLocalizations {
  LogsLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Логін';

  @override
  String get logsViewerDeleteButton => 'Видалити';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'Поділитися';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'Журнали успішно експортовано';

  @override
  String get logsExportFailedMessage => 'Не вдалося експортувати журнали';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'Показано $shown з $total записів';
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
  String get logsViewerClearFilter => 'Очистити фільтр';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'Фільтр за датою';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'Скопіювати до буферу';

  @override
  String get logsViewerDeleteTitle => 'Видалити журнали';

  @override
  String get logsViewerDeleteConfirmation =>
      'Ви впевнені, що хочете видалити всі журнали? Цю дію не можна скасувати.';

  @override
  String get logsDeletedMessage => 'Журнали видалено';

  @override
  String get logsViewerCancelButton => 'Скасувати';

  @override
  String get logsShareOptionShare => 'Поділитися';

  @override
  String get logsShareOptionExport => 'Експорт';

  @override
  String get oopsSomethingWentWrong => 'Опери Хтось пішов неправильно';

  @override
  String get retry => 'Повторити';
}
