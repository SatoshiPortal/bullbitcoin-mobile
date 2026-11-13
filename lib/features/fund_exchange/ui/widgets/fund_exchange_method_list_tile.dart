import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';

class FundExchangeMethodListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final void Function()? onTap;

  const FundExchangeMethodListTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      tileColor: context.appColors.transparent,
      shape: const RoundedRectangleBorder(),
      title: BBText(title, style: theme.textTheme.bodyLarge),
      subtitle: BBText(
        subtitle,
        style: theme.textTheme.labelMedium,
        color: context.appColors.outline,
      ),
      onTap: onTap,
      trailing: const Icon(Icons.arrow_forward),
    );
  }
}
