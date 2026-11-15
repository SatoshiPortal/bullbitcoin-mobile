import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/fund_exchange/fund_exchange_router.dart';
import 'package:bb_mobile/features/withdraw/ui/withdraw_router.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class ExchangeHomeFundingButtons extends StatelessWidget {
  const ExchangeHomeFundingButtons({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 40.0 : null;
    final textStyle = compact
        ? context.font.bodyLarge?.copyWith(fontWeight: .w600)
        : null;
    return Row(
      children: [
        Expanded(
          child: BBButton.big(
            iconData: Icons.arrow_downward,
            label: context.loc.exchangeHomeDepositButton,
            iconFirst: true,
            height: height,
            textStyle: textStyle,
            onPressed: () =>
                context.pushNamed(FundExchangeRoute.fundExchange.name),
            bgColor: context.appColors.secondaryFixed,
            textColor: context.appColors.onSecondaryFixed,
            outlined: true,
            borderColor: context.appColors.onSecondaryFixed,
          ),
        ),
        const Gap(4),
        Expanded(
          child: BBButton.big(
            iconData: Icons.arrow_upward,
            label: context.loc.exchangeHomeWithdrawButton,
            iconFirst: true,
            height: height,
            textStyle: textStyle,
            disabled: false,
            onPressed: () => context.pushNamed(WithdrawRoute.withdraw.name),
            bgColor: context.appColors.secondaryFixed,
            textColor: context.appColors.onSecondaryFixed,
            outlined: true,
            borderColor: context.appColors.onSecondaryFixed,
          ),
        ),
      ],
    );
  }
}
