// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Assamese (`as`).
class LogsLocalizationsAs extends LogsLocalizations {
  LogsLocalizationsAs([String locale = 'as']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'লগসমূহ';

  @override
  String get logsViewerDeleteButton => 'মচক';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'শ্বেয়াৰ কৰক';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'লগসমূহ সফলভাৱে ৰপ্তানি কৰা হৈছে';

  @override
  String get logsExportFailedMessage => 'লগ ৰপ্তানি কৰিবলৈ বিফল হৈছে';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return '$total টা লগৰ ভিতৰত $shown টা দেখুওৱা হৈছে';
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
  String get logsViewerClearFilter => 'ফিল্টাৰ মচক';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'তাৰিখ অনুযায়ী ফিল্টাৰ কৰক';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'ক্লিপবোৰ্ডত কপি কৰা হৈছে';

  @override
  String get logsViewerDeleteTitle => 'লগ মচক';

  @override
  String get logsViewerDeleteConfirmation =>
      'আপুনি নিশ্চিতভাৱে সকলো লগ মচিব বিচাৰে নে? এই কাৰ্য পূৰ্বাৱস্থালৈ ঘূৰাই আনিব নোৱাৰিব।';

  @override
  String get logsDeletedMessage => 'লগ মচা হৈছে';

  @override
  String get logsViewerCancelButton => 'বাতিল কৰক';

  @override
  String get logsShareOptionShare => 'শ্বেয়াৰ কৰক';

  @override
  String get logsShareOptionExport => 'ৰপ্তানি কৰক';

  @override
  String get oopsSomethingWentWrong => 'উফ্! কিবা এটা ভুল হৈছে';

  @override
  String get retry => 'পুনৰ চেষ্টা কৰক';
}
