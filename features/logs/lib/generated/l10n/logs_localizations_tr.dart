// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class LogsLocalizationsTr extends LogsLocalizations {
  LogsLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Logs';

  @override
  String get logsViewerDeleteButton => 'Sil';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'Paylaş';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'Kayıtlar başarıyla dışa aktarıldı';

  @override
  String get logsExportFailedMessage => 'Kayıtlar dışa aktarılamadı';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return '$total kayıttan $shown tanesi gösteriliyor';
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
  String get logsViewerClearFilter => 'Filtreyi Temizle';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'Tarihe Göre Filtrele';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'Copied to klibi';

  @override
  String get logsViewerDeleteTitle => 'Günlükleri sil';

  @override
  String get logsViewerDeleteConfirmation =>
      'Tüm günlükleri silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.';

  @override
  String get logsDeletedMessage => 'Günlükler silindi';

  @override
  String get logsViewerCancelButton => 'İptal';

  @override
  String get logsShareOptionShare => 'Paylaş';

  @override
  String get logsShareOptionExport => 'Dışa Aktar';

  @override
  String get oopsSomethingWentWrong =>
      'Oops! Bir şey ters gitti yanlış bir şey gitti';

  @override
  String get retry => 'Tekrar dene';
}
