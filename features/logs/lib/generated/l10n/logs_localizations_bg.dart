// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class LogsLocalizationsBg extends LogsLocalizations {
  LogsLocalizationsBg([String locale = 'bg']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Логове';

  @override
  String get logsViewerDeleteButton => 'Изтрий';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'Споделяне';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'Журналите са експортирани успешно';

  @override
  String get logsExportFailedMessage => 'Неуспешно експортиране на журналите';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'Показване на $shown от $total журнала';
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
  String get logsViewerClearFilter => 'Изчисти филтъра';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'Филтриране по дата';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'Копирано в клипборда';

  @override
  String get logsViewerDeleteTitle => 'Изтрий логовете';

  @override
  String get logsViewerDeleteConfirmation =>
      'Сигурни ли сте, че искате да изтриете всички логове? Това действие не може да бъде отменено.';

  @override
  String get logsDeletedMessage => 'Логовете са изтрити';

  @override
  String get logsViewerCancelButton => 'Отказ';

  @override
  String get logsShareOptionShare => 'Споделяне';

  @override
  String get logsShareOptionExport => 'Експортиране';

  @override
  String get oopsSomethingWentWrong => 'Опа! Нещо се обърка';

  @override
  String get retry => 'Повтори';
}
