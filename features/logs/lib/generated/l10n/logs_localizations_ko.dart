// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class LogsLocalizationsKo extends LogsLocalizations {
  LogsLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get logSettingsLogsTitle => '제품정보';

  @override
  String get logsViewerDeleteButton => '삭제';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => '공유';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => '로그를 성공적으로 내보냈습니다';

  @override
  String get logsExportFailedMessage => '로그 내보내기에 실패했습니다';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return '$total개 중 $shown개 로그 표시';
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
  String get logsViewerClearFilter => '필터 지우기';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => '날짜별 필터';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => '클립보드에 복사';

  @override
  String get logsViewerDeleteTitle => '로그 삭제';

  @override
  String get logsViewerDeleteConfirmation =>
      '모든 로그를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get logsDeletedMessage => '로그가 삭제되었습니다';

  @override
  String get logsViewerCancelButton => '취소';

  @override
  String get logsShareOptionShare => '공유';

  @override
  String get logsShareOptionExport => '내보내기';

  @override
  String get oopsSomethingWentWrong => '인기 있는 뭔가 잘못되었습니다';

  @override
  String get retry => '다시 시도';
}
