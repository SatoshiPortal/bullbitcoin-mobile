// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class LogsLocalizationsZh extends LogsLocalizations {
  LogsLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get logSettingsLogsTitle => '记录';

  @override
  String get logsViewerDeleteButton => '删除';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => '分享';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => '日志导出成功';

  @override
  String get logsExportFailedMessage => '日志导出失败';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return '显示 $shown 条（共 $total 条）日志';
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
  String get logsViewerClearFilter => '清除筛选';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => '按日期筛选';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => '涂料';

  @override
  String get logsViewerDeleteTitle => '删除日志';

  @override
  String get logsViewerDeleteConfirmation => '您确定要删除所有日志吗？此操作无法撤销。';

  @override
  String get logsDeletedMessage => '日志已删除';

  @override
  String get logsViewerCancelButton => '取消';

  @override
  String get logsShareOptionShare => '分享';

  @override
  String get logsShareOptionExport => '导出';

  @override
  String get oopsSomethingWentWrong => 'Oops! 某些错误';

  @override
  String get retry => '重试';
}
