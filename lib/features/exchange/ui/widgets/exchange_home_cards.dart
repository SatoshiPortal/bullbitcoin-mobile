import 'package:bb_mobile/features/autobuy/public/autobuy_facade.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/announcement_banner.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/dca_list_tile.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_failure_banner.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_kyc_card.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class ExchangeHomeCards extends StatelessWidget {
  const ExchangeHomeCards({super.key, required this.homeCards});

  final List<Widget> homeCards;

  @override
  Widget build(BuildContext context) {
    final notLoggedIn = context.select(
      (ExchangeCubit cubit) => cubit.state.notLoggedIn,
    );
    final isFullyVerified = context.select(
      (ExchangeCubit cubit) => cubit.state.isFullyVerifiedKycLevel,
    );
    final getUserSummaryFailure = context.select(
      (ExchangeCubit cubit) => cubit.state.getUserSummaryFailure,
    );
    final stopDcaFailure = context.select(
      (ExchangeCubit cubit) => cubit.state.stopDcaFailure,
    );
    final dca = context.select((ExchangeCubit cubit) => cubit.state.dca);
    final hasDcaActive = dca?.isActive ?? false;
    final autoBuy = context.select(
      (ExchangeCubit cubit) => cubit.state.userSummary?.autoBuy,
    );
    final isFundingRestricted = context.select(
      (ExchangeCubit cubit) =>
          cubit.state.userSummary?.isFundingRestricted ?? true,
    );

    return Column(
      children: [
        // A refresh that fails leaves stale data on screen; say
        // so instead of letting it look current.
        if (getUserSummaryFailure != null) ...[
          ExchangeFailureBanner(
            failure: getUserSummaryFailure,
            onRetry: () => context.read<ExchangeCubit>().fetchUserSummary(),
          ),
          const Gap(12),
        ],
        if (stopDcaFailure != null) ...[
          ExchangeFailureBanner(
            failure: stopDcaFailure,
            onRetry: () => context.read<ExchangeCubit>().stopDca(),
          ),
          const Gap(12),
        ],
        if (!isFullyVerified) ...[const ExchangeHomeKycCard(), const Gap(12)],
        DcaListTile(hasDcaActive: hasDcaActive, dca: dca),
        const Gap(12),
        GetIt.I<AutoBuyFacade>().buildHomeCard(
          isActive: autoBuy?.isActive ?? false,
          isRestricted: isFundingRestricted,
          onActivate: () async {
            await context.pushNamed(AutoBuyRoute.autoBuy.name);
            if (context.mounted) {
              await context.read<ExchangeCubit>().fetchUserSummary();
            }
          },
          onStatusChanged: () =>
              context.read<ExchangeCubit>().fetchUserSummary(),
        ),
        const Gap(12),
        for (final card in homeCards) ...[card, const Gap(12)],
        if (!notLoggedIn) const AnnouncementBanner(),
      ],
    );
  }
}
