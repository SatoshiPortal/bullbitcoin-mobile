// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'user_feedback_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Modern Greek (`el`).
class UserFeedbackLocalizationsEl extends UserFeedbackLocalizations {
  UserFeedbackLocalizationsEl([String locale = 'el']) : super(locale);

  @override
  String get feedbackTitle => 'Αποστολή σχολίων';

  @override
  String get feedbackClose => 'Κλείσιμο';

  @override
  String get feedbackLoadError =>
      'Δεν ήταν δυνατή η φόρτωση της φόρμας. Ελέγξτε τη σύνδεσή σας και δοκιμάστε ξανά.';

  @override
  String get feedbackRetry => 'Δοκιμάστε ξανά';

  @override
  String get feedbackShakeTitle => 'Κάτι δεν πάει καλά;';

  @override
  String get feedbackShakeBody =>
      'Στείλτε στην ομάδα αναφορά σφάλματος ή μια ιδέα.';

  @override
  String get feedbackShakeDismiss => 'Όχι τώρα';

  @override
  String get feedbackSearchKeywords =>
      'σχόλια, σφάλμα, bug, αναφορά, ιδέα, πρόταση, πρόβλημα, επικοινωνία';
}
