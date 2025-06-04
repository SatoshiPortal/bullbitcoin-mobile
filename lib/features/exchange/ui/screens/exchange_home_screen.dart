import 'package:bb_mobile/features/exchange/presentation/exchange_home_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/bullbitcoin_webview.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_top_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ExchangeHomeScreen extends StatelessWidget {
  const ExchangeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hasUser = context.select(
      (ExchangeHomeCubit cubit) => cubit.state.hasUserSummary,
    );

    if (!hasUser) return const BullbitcoinWebview();

    return Column(
      children: [
        const ExchangeHomeTopSection(),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  const Gap(12),
                  SwitchListTile(
                    value: false,
                    onChanged: (value) {},
                    title: const Text('Activate auto-buy'),
                  ),
                  const Gap(12),
                  SwitchListTile(
                    value: false,
                    onChanged: (value) {},
                    title: const Text('Activate recurring buy'),
                  ),
                  const Gap(12),
                  ListTile(
                    title: const Text('View auto-sell address'),
                    onTap: () {},
                    trailing: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
