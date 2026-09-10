import 'package:bull_ui/bull_ui.dart';

/// Compatibility facade for legacy root callers. The concrete widget belongs
/// to bull_ui so every caller gets identical toast behavior.
class SnackBarUtils {
  static void showCopiedSnackBar(BuildContext context) =>
      BullSnackBar.show(context, message: 'Copied to clipboard');

  static void showSnackBar(BuildContext context, String message) =>
      BullSnackBar.show(context, message: message);

  static void showSnackBarWithContent(BuildContext context, Widget content) =>
      BullSnackBar.showContent(context, content);

  static void dismiss() => BullSnackBar.dismiss();
}
