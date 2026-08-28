// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class LogsLocalizationsBn extends LogsLocalizations {
  LogsLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'লগসমূহ';

  @override
  String get logsViewerDeleteButton => 'মুছুন';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'শেয়ার করুন';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'লগ সফলভাবে এক্সপোর্ট হয়েছে';

  @override
  String get logsExportFailedMessage => 'লগ এক্সপোর্ট করতে ব্যর্থ হয়েছে';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return '$total টি লগের মধ্যে $shown টি দেখানো হচ্ছে';
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
  String get logsViewerClearFilter => 'ফিল্টার সাফ করুন';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'তারিখ অনুযায়ী ফিল্টার করুন';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'ক্লিপবোর্ডে কপি করা হয়েছে';

  @override
  String get logsViewerDeleteTitle => 'লগ মুছুন';

  @override
  String get logsViewerDeleteConfirmation =>
      'আপনি কি নিশ্চিত যে আপনি সব লগ মুছে ফেলতে চান? এই ক্রিয়া পুনরুদ্ধার করা যাবে না।';

  @override
  String get logsDeletedMessage => 'লগ মুছে ফেলা হয়েছে';

  @override
  String get logsViewerCancelButton => 'বাতিল';

  @override
  String get logsShareOptionShare => 'শেয়ার করুন';

  @override
  String get logsShareOptionExport => 'এক্সপোর্ট করুন';

  @override
  String get oopsSomethingWentWrong => 'ওহ! কিছু ভুল হয়েছে';

  @override
  String get retry => 'পুনরায় চেষ্টা করুন';
}
