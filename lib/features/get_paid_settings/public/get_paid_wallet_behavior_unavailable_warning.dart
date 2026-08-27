import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

/// Persistent notice used when a product cannot read its reserved wallet
/// settings. Confirmed absence is intentionally represented by no notice.
class GetPaidWalletBehaviorUnavailableWarning extends StatelessWidget {
  final VoidCallback onRetry;
  final bool isRetrying;

  const GetPaidWalletBehaviorUnavailableWarning({
    super.key,
    required this.onRetry,
    this.isRetrying = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Card(
        key: const Key('get_paid_wallet_behavior_unavailable_warning'),
        color: context.appColors.warningContainer,
        child: ListTile(
          leading: Icon(
            Icons.warning_amber_rounded,
            color: context.appColors.warning,
          ),
          title: Text(context.loc.getPaidWalletSettingsUnavailable),
          trailing: TextButton(
            onPressed: isRetrying ? null : onRetry,
            child: Text(context.loc.retry),
          ),
        ),
      ),
    );
  }
}
