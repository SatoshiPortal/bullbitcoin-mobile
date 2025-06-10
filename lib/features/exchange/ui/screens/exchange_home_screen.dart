import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/widgets/exchange_home_top_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ExchangeHomeScreen extends StatelessWidget {
  const ExchangeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isFetchingUserSummary = context.select(
      (ExchangeCubit cubit) => cubit.state.isFetchingUserSummary,
    );
    final isApiKeyInvalid = context.select(
      (ExchangeCubit cubit) => cubit.state.isApiKeyInvalid,
    );

    if (isFetchingUserSummary || isApiKeyInvalid) {
      return const Center(child: CircularProgressIndicator());
    }

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
