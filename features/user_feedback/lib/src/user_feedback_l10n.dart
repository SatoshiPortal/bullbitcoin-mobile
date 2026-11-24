import 'package:flutter/widgets.dart';
import 'package:user_feedback/generated/l10n/user_feedback_localizations.dart';

/// This feature's copy for [localeName], falling back to the language, then English.
UserFeedbackLocalizations userFeedbackCopy(String localeName) {
  final tag = localeName.replaceAll('_', '-').toLowerCase();
  final supported = UserFeedbackLocalizations.supportedLocales;
  for (final locale in supported) {
    if (locale.toLanguageTag().toLowerCase() == tag) {
      return lookupUserFeedbackLocalizations(locale);
    }
  }
  final language = Locale(tag.split('-').first);
  return lookupUserFeedbackLocalizations(
    supported.contains(language) ? language : const Locale('en'),
  );
}

extension UserFeedbackCopyX on BuildContext {
  UserFeedbackLocalizations get feedbackCopy =>
      userFeedbackCopy(Localizations.localeOf(this).toLanguageTag());
}
