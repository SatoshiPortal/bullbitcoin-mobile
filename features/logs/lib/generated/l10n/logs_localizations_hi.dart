// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'logs_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class LogsLocalizationsHi extends LogsLocalizations {
  LogsLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get logSettingsLogsTitle => 'लॉग';

  @override
  String get logsViewerDeleteButton => 'हटाएं';

  @override
  String get logsViewerFilter => 'Filter logs';

  @override
  String get logsViewerShareButton => 'शेयर करें';

  @override
  String get logsShareFailedMessage => 'Failed to share logs';

  @override
  String get logsExportedMessage => 'लॉग सफलतापूर्वक निर्यात किए गए';

  @override
  String get logsExportFailedMessage => 'लॉग निर्यात करने में विफल';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return '$total में से $shown लॉग दिखाए जा रहे हैं';
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
  String get logsViewerClearFilter => 'फ़िल्टर हटाएं';

  @override
  String get logsViewerSearchHint => 'Search logs';

  @override
  String get logsViewerFilterByDate => 'तारीख के अनुसार फ़िल्टर करें';

  @override
  String get logsViewerCollapseHint => 'Tap to collapse. Long press to copy.';

  @override
  String get logsViewerExpandHint =>
      'Tap a log to expand it. Long press to copy.';

  @override
  String get copiedToClipboardMessage => 'कोपिड टू क्लिपबोर्ड';

  @override
  String get logsViewerDeleteTitle => 'लॉग हटाएं';

  @override
  String get logsViewerDeleteConfirmation =>
      'क्या आप वाकई सभी लॉग हटाना चाहते हैं? यह कार्रवाई पूर्ववत नहीं की जा सकती।';

  @override
  String get logsDeletedMessage => 'लॉग्स हटा दिए गए';

  @override
  String get logsViewerCancelButton => 'रद्द करें';

  @override
  String get logsShareOptionShare => 'शेयर करें';

  @override
  String get logsShareOptionExport => 'निर्यात करें';

  @override
  String get oopsSomethingWentWrong => 'ओप! कुछ गलत हो गया';

  @override
  String get retry => 'पुनः प्रयास करें';
}

/// The translations for Hindi, using the Latin script (`hi_Latn`).
class LogsLocalizationsHiLatn extends LogsLocalizationsHi {
  LogsLocalizationsHiLatn() : super('hi_Latn');

  @override
  String get logSettingsLogsTitle => 'Logs';

  @override
  String get logsViewerDeleteButton => 'Delete';

  @override
  String get logsViewerShareButton => 'Share karein';

  @override
  String get logsExportedMessage => 'Logs safaltaapoorvak export kiye gaye';

  @override
  String get logsExportFailedMessage => 'Logs export karne mein vifal';

  @override
  String logsViewerShowingCount(int shown, int total) {
    return '$total mein se $shown log dikhaaye ja rahe hain';
  }

  @override
  String get logsViewerClearFilter => 'Filter hatayein';

  @override
  String get logsViewerFilterByDate => 'Taareekh ke anusaar filter karein';

  @override
  String get copiedToClipboardMessage => 'Clipboard mein copy hua';

  @override
  String get logsViewerDeleteTitle => 'Logs Delete Karo';

  @override
  String get logsViewerDeleteConfirmation =>
      'Kya aap sach mein saare logs delete karna chahte hain? Ye action wapas nahi liya ja sakta.';

  @override
  String get logsDeletedMessage => 'Logs delete ho gayi';

  @override
  String get logsViewerCancelButton => 'Cancel';

  @override
  String get logsShareOptionShare => 'Share karein';

  @override
  String get logsShareOptionExport => 'Export karein';

  @override
  String get oopsSomethingWentWrong => 'Oops! Kuch galat ho gaya';

  @override
  String get retry => 'Dobara Try Karo';
}
