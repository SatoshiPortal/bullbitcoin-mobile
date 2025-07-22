import 'package:bb_mobile/core/themes/app_theme.dart';
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
      tileColor: context.colour.secondary,
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_outline_outlined,
            color: Colors.white,
            size: 32,
          ),
          const Gap(2),
          if (isKycLight)
            Text(
              'Light',
              style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
            ),
          if (isKycLimited)
            Text(
              'Limited',
              style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
            ),
        ],
      ),
      title: Text(
        'Complete your KYC',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: context.colour.onPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),

      subtitle: Text(
        'To remove transaction limits',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: context.colour.surface,
          fontWeight: FontWeight.w500,
        ),
      ),
      titleAlignment: ListTileTitleAlignment.center,
      onTap: () async {
        await context.pushNamed(ExchangeRoute.exchangeKyc.name);
      },
      trailing: const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
    );
  }
}
