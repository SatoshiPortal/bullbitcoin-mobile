import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/ui/fund_exchange_router.dart';
import 'package:flutter/material.dart';
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
      tileColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.labelMedium!.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      onTap: () {
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
