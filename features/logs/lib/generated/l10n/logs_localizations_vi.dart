// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class LogsLocalizationsVi extends LogsLocalizations {
  LogsLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'Nhật ký';

  @override
  String get logsViewerDeleteButton => 'Xóa';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'Chia sẻ';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'Nhật ký đã được xuất thành công';

  @override
  String get logsExportFailedMessage => 'Xuất nhật ký thất bại';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'Đang hiển thị $shown trong $total nhật ký';
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
  String get logsViewerClearFilter => 'Xóa bộ lọc';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'Lọc theo ngày';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'Đã sao chép vào bộ nhớ tạm';

  @override
  String get logsViewerDeleteTitle => 'Xóa nhật ký';

  @override
  String get logsViewerDeleteConfirmation =>
      'Bạn có chắc muốn xóa tất cả nhật ký không? Hành động này không thể hoàn tác.';

  @override
  String get logsDeletedMessage => 'Đã xóa nhật ký';

  @override
  String get logsViewerCancelButton => 'Hủy';

  @override
  String get logsShareOptionShare => 'Chia sẻ';

  @override
  String get logsShareOptionExport => 'Xuất';

  @override
  String get oopsSomethingWentWrong => 'Rất tiếc! Đã xảy ra lỗi';

  @override
  String get retry => 'Thử lại';
}
