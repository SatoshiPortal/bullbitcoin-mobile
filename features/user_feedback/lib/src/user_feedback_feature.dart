import 'package:material_ui/material_ui.dart';
import 'package:user_feedback/src/feedback_form.dart';
import 'package:user_feedback/src/ui/feedback_shake_listener.dart';
import 'package:user_feedback/src/ui/feedback_sheet.dart';
import 'package:user_feedback/src/user_feedback_l10n.dart';

/// In-app feedback: the hosted form in a sheet, opened from Settings or by
/// shaking the phone. Off when the build has no `FEEDBACK_FORM_URL`.
abstract final class UserFeedbackFeature {
  static final FeedbackForm? _form = FeedbackForm.fromEnvironment();

  /// Whether this build has a feedback form to open.
  static bool get isAvailable => _form != null;

  /// Title of the Settings row, in [localeName].
  static String settingsTitle(String localeName) =>
      userFeedbackCopy(localeName).feedbackTitle;

  /// Search keywords of the Settings row, in [localeName].
  static List<String> settingsKeywords(String localeName) =>
      userFeedbackCopy(localeName).feedbackSearchKeywords
          .split(',')
          .map((k) => k.trim())
          .toList();

  /// Opens the form. [screen] names where the user came from.
  static Future<void> open(BuildContext context, {String? screen}) async {
    final form = _form;
    if (form == null) return;
    await showFeedbackSheet(context, form: form, screen: screen);
  }

  /// Wraps the unlocked app so a shake offers to send feedback.
  /// Returns [child] unchanged when [isAvailable] is false.
  static Widget shakeToReport({
    required GlobalKey<NavigatorState> navigatorKey,
    required Widget child,
    String? Function()? currentScreen,
  }) {
    final form = _form;
    if (form == null) return child;
    return FeedbackShakeListener(
      form: form,
      navigatorKey: navigatorKey,
      currentScreen: currentScreen,
      child: child,
    );
  }
}
