import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ExchangeHomeKycCard extends StatelessWidget {
  const ExchangeHomeKycCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isKycLight = context.select(
      (ExchangeCubit cubit) => cubit.state.isLightKycLevel,
    );
    final isKycLimited = context.select(
      (ExchangeCubit cubit) => cubit.state.isLimitedKycLevel,
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      tileColor: context.appColors.secondary,
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
              style: theme.textTheme.labelLarge?.copyWith(color: context.appColors.surfaceFixed),
            ),
          if (isKycLimited)
            Text(
              context.loc.exchangeKycLevelLimited,
              style: theme.textTheme.labelLarge?.copyWith(color: context.appColors.surfaceFixed),
            ),
        ],
      ),
      title: Text(
        context.loc.exchangeKycCardTitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: context.appColors.onPrimary,
          fontWeight: .w500,
        ),
      ),

      subtitle: Text(
        context.loc.exchangeKycCardSubtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: context.appColors.surface,
          fontWeight: .w500,
        ),
      ),
      titleAlignment: ListTileTitleAlignment.center,
      onTap: () async {
        await context.pushNamed(ExchangeRoute.exchangeKyc.name);
      },
      trailing: Icon(Icons.arrow_forward, color: context.appColors.surfaceFixed, size: 24),
    );
  }
}
