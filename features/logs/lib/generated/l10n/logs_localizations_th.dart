// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class LogsLocalizationsTh extends LogsLocalizations {
  LogsLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'เข้าสู่ระบบ';

  @override
  String get logsViewerDeleteButton => 'ลบ';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'แชร์';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'ส่งออกบันทึกสำเร็จแล้ว';

  @override
  String get logsExportFailedMessage => 'ส่งออกบันทึกไม่สำเร็จ';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return 'กำลังแสดง $shown จาก $total รายการบันทึก';
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
  String get logsViewerClearFilter => 'ล้างตัวกรอง';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'กรองตามวันที่';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'ติดตามคลิปบอร์ด';

  @override
  String get logsViewerDeleteTitle => 'ลบบันทึก';

  @override
  String get logsViewerDeleteConfirmation =>
      'คุณแน่ใจหรือไม่ว่าต้องการลบบันทึกทั้งหมด การดำเนินการนี้ไม่สามารถย้อนกลับได้';

  @override
  String get logsDeletedMessage => 'ลบบันทึกแล้ว';

  @override
  String get logsViewerCancelButton => 'ยกเลิก';

  @override
  String get logsShareOptionShare => 'แชร์';

  @override
  String get logsShareOptionExport => 'ส่งออก';

  @override
  String get oopsSomethingWentWrong => 'Oops! สิ่งที่ไม่ผิด';

  @override
  String get retry => 'ลองอีกครั้ง';
}
