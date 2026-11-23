import '../exchange_l10n.dart';
import '../exchange_landing_navigation.dart';

import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show Gap, BullTypographyX;
import 'package:go_router/go_router.dart';

class ExchangeHomeKycCard extends StatelessWidget {
  const ExchangeHomeKycCard({
    required this.isKycLight,
    required this.isKycLimited,
    super.key,
  });

  final bool isKycLight;
  final bool isKycLimited;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      tileColor: context.appColors.secondaryFixed,
      leading: Column(
        mainAxisAlignment: .center,
        children: [
          Icon(
            Icons.person_outline_outlined,
            color: context.appColors.surfaceFixed,
            size: 32,
          ),
          const Gap(2),
          if (isKycLight)
            Text(
              context.loc.exchangeKycLevelLight,
              style: context.bullType.label.copyWith(
                color: context.appColors.surfaceFixed,
              ),
            ),
          if (isKycLimited)
            Text(
              context.loc.exchangeKycLevelLimited,
              style: context.bullType.label.copyWith(
                color: context.appColors.surfaceFixed,
              ),
            ),
        ],
      ),
      title: Text(
        context.loc.exchangeKycCardTitle,
        style: context.bullType.body.copyWith(
          color: context.appColors.onPrimary,
          fontWeight: .w500,
        ),
      ),

      subtitle: Text(
        context.loc.exchangeKycCardSubtitle,
        style: context.bullType.body.copyWith(
          color: context.appColors.onPrimaryFixed,
          fontWeight: .w500,
        ),
      ),
      titleAlignment: ListTileTitleAlignment.center,
      onTap: () async {
        await context.pushNamed(BullExchangeNavigation.kycName);
      },
      trailing: Icon(
        Icons.arrow_forward,
        color: context.appColors.surfaceFixed,
        size: 24,
      ),
    );
  }
}
