import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_failure_l10n.dart';
import 'package:flutter/material.dart';

/// Shows a sanitized [ExchangeFailure] inline, with an optional retry.
///
/// Used where the screen still has usable (if stale) content behind it, so the
/// failure is reported without replacing everything the user was looking at.
class ExchangeFailureBanner extends StatelessWidget {
  final ExchangeFailure failure;

  /// Runs the failed operation again. Tapping the banner must genuinely retry
  /// — never merely dismiss — or users learn the tap does nothing useful and
  /// stop using it when it does.
  final VoidCallback? onRetry;

  const ExchangeFailureBanner({super.key, required this.failure, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      description: failure.toTranslated(context),
      tagColor: context.appColors.error,
      bgColor: context.appColors.errorContainer,
      onTap: onRetry,
    );
  }
}
