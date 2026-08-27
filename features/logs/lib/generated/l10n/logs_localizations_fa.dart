// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class LogsLocalizationsFa extends LogsLocalizations {
  LogsLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Logs';

  @override
  String get logsViewerDeleteButton => 'حذف';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'اشتراک‌گذاری';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'گزارش‌ها با موفقیت صادر شدند';

  @override
  String get logsExportFailedMessage => 'صدور گزارش‌ها ناموفق بود';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'نمایش $shown از $total گزارش';
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
  String get logsViewerClearFilter => 'پاک کردن فیلتر';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'فیلتر بر اساس تاریخ';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'نصب شده برای Clipboard';

  @override
  String get logsViewerDeleteTitle => 'حذف گزارش‌ها';

  @override
  String get logsViewerDeleteConfirmation =>
      'آیا مطمئن هستید که می‌خواهید همه‌ی گزارش‌ها را حذف کنید؟ این عمل قابل بازگشت نیست.';

  @override
  String get logsDeletedMessage => 'گزارش‌ها حذف شدند';

  @override
  String get logsViewerCancelButton => 'لغو';

  @override
  String get logsShareOptionShare => 'اشتراک‌گذاری';

  @override
  String get logsShareOptionExport => 'صدور';

  @override
  String get oopsSomethingWentWrong => 'Oops! چیزی اشتباه کرد';

  @override
  String get retry => 'تلاش مجدد';
}
