// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class LogsLocalizationsAr extends LogsLocalizations {
  LogsLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'اللوز';

  @override
  String get logsViewerDeleteButton => 'حذف';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'مشاركة';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'تم تصدير السجلات بنجاح';

  @override
  String get logsExportFailedMessage => 'فشل تصدير السجلات';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'عرض $shown من $total سجل';
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
  String get logsViewerClearFilter => 'مسح التصفية';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'تصفية حسب التاريخ';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'مركب على لوح مشبك';

  @override
  String get logsViewerDeleteTitle => 'حذف السجلات';

  @override
  String get logsViewerDeleteConfirmation =>
      'هل أنت متأكد من رغبتك في حذف جميع السجلات؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get logsDeletedMessage => 'تم حذف السجلات';

  @override
  String get logsViewerCancelButton => 'إلغاء';

  @override
  String get logsShareOptionShare => 'مشاركة';

  @override
  String get logsShareOptionExport => 'تصدير';

  @override
  String get oopsSomethingWentWrong => '! شيء ما حدث';

  @override
  String get retry => 'إعادة المحاولة';
}
