import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class DcaSuccessScreen extends StatelessWidget {
  const DcaSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final successState = context.watch<DcaBloc>().state as DcaSuccessState;
    final amount = FormatAmount.fiat(
      successState.amount,
      successState.currency.code,
    );
    final frequency = successState.frequency;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        context.goNamed(ExchangeRoute.exchangeHome.name);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            CloseButton(
              onPressed: () => context.goNamed(ExchangeRoute.exchangeHome.name),
            ),
          ],
        ),
        body: SafeArea(
          child: ScrollableColumn(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            crossAxisAlignment: .center,
            children: [
              const Spacer(),
              Icon(
                Icons.check_circle,
                size: 72,
                color: context.appColors.inverseSurface,
              ),
              const Gap(24),
              Text(
                context.loc.dcaSuccessTitle,
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: .center,
              ),
              const Gap(16),
              Text(
                switch (frequency) {
                  DcaBuyFrequency.hourly => context.loc.dcaSuccessMessageHourly(
                    amount,
                  ),
                  DcaBuyFrequency.daily => context.loc.dcaSuccessMessageDaily(
                    amount,
                  ),
                  DcaBuyFrequency.weekly => context.loc.dcaSuccessMessageWeekly(
                    amount,
                  ),
                  DcaBuyFrequency.monthly => context.loc
                      .dcaSuccessMessageMonthly(amount),
                },
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: .center,
              ),
              const Spacer(),
              BBButton.big(
                label: context.loc.dcaBackToHomeButton,
                onPressed: () {
                  context.goNamed(ExchangeRoute.exchangeHome.name);
                },
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onSecondary,
              ),
              const Gap(16.0),
            ],
          ),
        ),
      ),
    );
  }
}
