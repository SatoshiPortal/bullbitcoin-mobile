import 'package:primitives/primitives.dart' show FormatAmount;
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullSuccessScreen;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class DcaSuccessScreen extends StatelessWidget {
  const DcaSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final successState = context.watch<DcaBloc>().state as DcaSuccessState;
    final amount = FormatAmount.fiat(
      successState.amount,
      successState.currency.code,
    );
    void goHome() => context.goNamed(ExchangeRoute.exchangeHome.name);
    return BullSuccessScreen(
      title: context.loc.dcaSetupTitle,
      headline: context.loc.dcaSuccessTitle,
      onClose: goHome,
      message: Text(switch (successState.frequency) {
        DcaBuyFrequency.hourly => context.loc.dcaSuccessMessageHourly(amount),
        DcaBuyFrequency.daily => context.loc.dcaSuccessMessageDaily(amount),
        DcaBuyFrequency.weekly => context.loc.dcaSuccessMessageWeekly(amount),
        DcaBuyFrequency.monthly => context.loc.dcaSuccessMessageMonthly(amount),
      }),
      actions: [
        BullButton.secondary(
          label: context.loc.dcaBackToHomeButton,
          onPressed: goHome,
        ),
      ],
    );
  }
}
