import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

/// States the name a surface will advertise while no alias has been claimed.
///
/// The claimed nym is the default — no action is needed to keep it, and simply
/// completing the create form advertises it. The single action offered here is
/// the opt-in departure from that default: claim one permanent alias.
///
/// Shared by the Donation Page and Point of Sale so the wording, ordering, and
/// affordances stay identical; only [body] differs, because it names the product.
///
/// It lives in this feature's `public/` surface because it is shared Get Paid
/// product UI — business copy and affordances, not core infrastructure — and both
/// product features render it directly.
class GetPaidNameChoice extends StatelessWidget {
  final String nym;
  final String body;
  final VoidCallback onChooseAlias;

  const GetPaidNameChoice({
    super.key,
    required this.nym,
    required this.body,
    required this.onChooseAlias,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.loc.getPaidNameChoiceTitle(nym),
            style: context.font.titleMedium,
          ),
          const Gap(8),
          Text(
            body,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          const Gap(16),
          BBButton.big(
            key: const Key('get_paid_choose_an_alias'),
            label: context.loc.getPaidNameChoiceChooseAlias,
            onPressed: onChooseAlias,
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
        ],
      ),
    );
  }
}
