import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:share_plus/share_plus.dart';

/// Shares the exact destination; no result establishes delivery to another user.
Future<void> shareArkReceive(
  BuildContext context,
  String value, {
  required bool Function() isCurrent,
  Future<ShareResult> Function(ShareParams)? share,
}) async {
  if (!context.mounted || !isCurrent() || value.trim().isEmpty) return;
  try {
    // Dismissed and unavailable results remain neutral, like success: no toast
    // claims delivery. Some platforms cannot report a result after sharing.
    await (share ?? SharePlus.instance.share)(ShareParams(text: value));
  } on Exception {
    if (context.mounted && isCurrent()) {
      BullSnackBar.show(context, message: context.loc.oopsSomethingWentWrong);
    }
  }
}
