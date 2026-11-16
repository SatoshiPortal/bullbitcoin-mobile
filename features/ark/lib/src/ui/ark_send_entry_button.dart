import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';

/// Published presentation for an explicit Ark source choice in another flow.
class ArkSendEntryButton extends StatelessWidget {
  final ArkAccountId account;
  final VoidCallback onPressed;
  const ArkSendEntryButton({
    super.key,
    required this.account,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: BullSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BullText(account.serverIdentity, style: null),
          BullButton.big(
            label: l10n.sendFromArkAccount(account.parent.hex),
            onPressed: onPressed,
            bgColor: context.bull.primary,
            textColor: context.bull.onPrimary,
          ),
        ],
      ),
    );
  }
}
