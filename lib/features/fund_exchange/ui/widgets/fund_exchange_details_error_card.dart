import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:flutter/material.dart';

class FundExchangeDetailsErrorCard extends StatelessWidget {
  const FundExchangeDetailsErrorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InfoCard(
      description:
          'The payment details could not be loaded at this moment. Please go back and try again, pick another payment method or come back later.',
      bgColor: theme.colorScheme.error.withValues(alpha: 0.1),
      tagColor: theme.colorScheme.primary,
    );
  }
}
