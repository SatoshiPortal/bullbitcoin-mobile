import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/announcement_banner.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/dca_list_tile.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_kyc_card.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_top_section.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_transaction_preview.dart';
import 'package:bb_mobile/features/fund_exchange/ui/fund_exchange_router.dart';
import 'package:bb_mobile/features/withdraw/ui/withdraw_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ExchangeHomeScreen extends StatelessWidget {
  const ExchangeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isFetchingUserSummary = context.select(
      (ExchangeCubit cubit) => cubit.state.isFetchingUserSummary,
    );
    final notLoggedIn = context.select(
      (ExchangeCubit cubit) => cubit.state.notLoggedIn,
    );
    final isFullyVerified = context.select(
      (ExchangeCubit cubit) => cubit.state.isFullyVerifiedKycLevel,
    );
    final dca = context.select((ExchangeCubit cubit) => cubit.state.dca);
    final hasDcaActive = dca?.isActive ?? false;

    if (isFetchingUserSummary || notLoggedIn) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<ExchangeCubit>().fetchUserSummary();
      },
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  const ExchangeHomeTopSection(),
                  const Gap(12),
                  const ExchangeTransactionPreview(),
                  const Gap(16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    child: Column(
                      children: [
                        if (!isFullyVerified) ...[
                          const ExchangeHomeKycCard(),
                          const Gap(12),
                        ],
                        DcaListTile(hasDcaActive: hasDcaActive, dca: dca),
                        const Gap(12),
                        if (!notLoggedIn) const AnnouncementBanner(),
                        const Gap(24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _ExchangeBottomButtons(),
        ],
      ),
    );
  }
}

class _ExchangeBottomButtons extends StatelessWidget {
  const _ExchangeBottomButtons();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.appColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.pushNamed(
                    FundExchangeRoute.fundExchangeAccount.name,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_downward,
                        color: context.appColors.primary,
                        size: 20,
                      ),
                      const Gap(8),
                      Text(
                        context.loc.exchangeHomeDepositButton,
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 20,
                color: context.appColors.primary.withValues(alpha: 0.25),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.pushNamed(WithdrawRoute.withdraw.name),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        color: context.appColors.primary,
                        size: 20,
                      ),
                      const Gap(8),
                      Text(
                        context.loc.exchangeHomeWithdrawButton,
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
