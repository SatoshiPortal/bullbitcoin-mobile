import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_transaction_details_table.dart';
import 'package:bb_mobile/router.dart';
import 'package:bb_mobile/ui/components/badges/transaction_direction_badge.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceiveDetailsScreen extends StatelessWidget {
  const ReceiveDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = context.select((ReceiveBloc bloc) => bloc.state.tx);
    final amountSat =
        tx?.amountSat ??
        context.select((ReceiveBloc bloc) => bloc.state.confirmedAmountSat) ??
        0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Don't allow back navigation

        context.go(AppRoute.home.path);
      },
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: 'Receive',
            actionIcon: Icons.close,
            onAction: () {
              context.go(AppRoute.home.path);
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                children: [
                  const TransactionDirectionBadge(isIncoming: true),
                  const Gap(24),
                  BBText('Payment received', style: context.font.headlineLarge),
                  const Gap(8),
                  BBText(
                    FormatAmount.sats(amountSat),
                    style: context.font.displaySmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Gap(24),
                  const ReceiveTransactionDetailsTable(),
                  const Gap(62),
                  BBButton.big(
                    label: 'Edit label',
                    onPressed: () {},
                    bgColor: Colors.transparent,
                    textColor: theme.colorScheme.secondary,
                    outlined: true,
                    borderColor: theme.colorScheme.secondary,
                  ),
                  const Gap(16),
                  BBButton.big(
                    label: 'Done',
                    onPressed: () {
                      context.go(AppRoute.home.path);
                    },
                    bgColor: theme.colorScheme.secondary,
                    textColor: theme.colorScheme.onPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
