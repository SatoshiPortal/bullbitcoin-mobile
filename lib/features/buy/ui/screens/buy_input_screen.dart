import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_amount_input_fields.dart';
import 'package:bb_mobile/features/buy/ui/widgets/buy_destination_input_fields.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BuyInputScreen extends StatelessWidget {
  const BuyInputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final canCreateOrder = context.select(
      (BuyBloc bloc) => bloc.state.canCreateOrder,
    );

    return Scaffold(
      appBar: AppBar(
        // Adding the leading icon button here manually since we are in the first
        // route of a shellroute and so no back button is provided by default.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
        ),
        title: const Text('Buy Bitcoin'),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Gap(24),
                BuyAmountInputFields(),
                Gap(16.0),
                BuyDestinationInputFields(),
                Gap(24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BBButton.big(
            label: 'Continue',
            disabled: !canCreateOrder,
            onPressed: () {
              context.read<BuyBloc>().add(const BuyEvent.createOrder());
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onSecondary,
          ),
        ),
      ),
    );
  }
}
