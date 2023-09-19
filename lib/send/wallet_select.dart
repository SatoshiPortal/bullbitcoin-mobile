import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/home_card.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SelectSendWalletPage extends StatelessWidget {
  const SelectSendWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final homeCubit = locator<HomeCubit>();

    return BlocProvider.value(
      value: homeCubit,
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: BBAppBar(
            text: 'Send Bitcoin',
            onBack: () {
              context.pop();
            },
          ),
        ),
        body: const _Screen(),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final walletBlocs = context.select((HomeCubit _) => _.state.walletBlocs ?? []);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Gap(32),
            const BBText.body('Select wallet to send from'),
            const Gap(24),
            for (final wallet in walletBlocs) ...[
              InkWell(
                onTap: () {
                  context.push('/send/one', extra: wallet);
                },
                borderRadius: BorderRadius.circular(32),
                child: BlocProvider.value(
                  value: wallet,
                  child: const HomeCard(hideSettings: true),
                ),
              ),
              const Gap(16),
            ],
          ],
        ),
      ),
    );
  }
}
