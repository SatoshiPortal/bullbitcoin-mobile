import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/bloc/fund_exchange_bloc.dart';
import 'package:bb_mobile/features/fund_exchange/ui/fund_exchange_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class FundExchangeMethodListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final FundingMethod method;

  const FundExchangeMethodListTile({
    super.key,
    required this.method,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      tileColor: context.appColors.transparent,
      shape: const RoundedRectangleBorder(),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.labelMedium!.copyWith(
          color: context.appColors.outline,
        ),
      ),
      onTap: () {
        // Reset the checkbox value when showing the warning screen again
        context.read<FundExchangeBloc>().add(
          const FundExchangeEvent.noCoercionConfirmed(false),
        );
        _navigateToWarningScreen(context, method);
      },
      trailing: const Icon(Icons.arrow_forward),
    );
  }

  void _navigateToWarningScreen(BuildContext context, FundingMethod method) {
    context.pushNamed(
      FundExchangeRoute.fundExchangeWarning.name,
      queryParameters: {'method': method.queryParam},
    );
  }
}
