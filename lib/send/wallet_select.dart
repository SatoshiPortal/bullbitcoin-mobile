import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/wallet_card.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/send/send_page.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SelectSendWalletStep extends Cubit<({bool selectWallet, WalletBloc? walletBloc})> {
  SelectSendWalletStep() : super((selectWallet: true, walletBloc: null));

  void goBack() => emit((selectWallet: true, walletBloc: null));
  void goNext(WalletBloc bloc) => emit((selectWallet: false, walletBloc: bloc));
}

class SelectSendWalletPage extends StatefulWidget {
  const SelectSendWalletPage({super.key});

  @override
  State<SelectSendWalletPage> createState() => _SelectSendWalletPageState();
}

class _SelectSendWalletPageState extends State<SelectSendWalletPage> {
  SelectSendWalletStep? stepBloc;

  @override
  void initState() {
    stepBloc = SelectSendWalletStep();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final homeCubit = locator<HomeCubit>();

    return BlocProvider.value(
      value: homeCubit,
      child: BlocProvider.value(
        value: stepBloc!,
        child: Scaffold(
          appBar: AppBar(
            flexibleSpace: const SendAppBar(),
            automaticallyImplyLeading: false,
          ),
          body: const SelectStepScreen(),
        ),
      ),
    );
  }
}

class SelectStepScreen extends StatelessWidget {
  const SelectStepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final walletNotSelected = context.select((SelectSendWalletStep _) => _.state.selectWallet);

    return AnimatedSwitcher(
      duration: 400.ms,
      child: walletNotSelected ? const SelectWalletScreen() : const SendScreen(),
    );
  }
}

class SelectWalletScreen extends StatelessWidget {
  const SelectWalletScreen();

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
              BlocProvider.value(
                value: wallet,
                child: HomeCard(
                  onTap: () {
                    context.read<SelectSendWalletStep>().goNext(wallet);
                  },
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

class SendAppBar extends StatelessWidget {
  const SendAppBar();

  @override
  Widget build(BuildContext context) {
    return BBAppBar(
      text: 'Send Bitcoin',
      onBack: () {
        final walletNotSelected = context.read<SelectSendWalletStep>().state.selectWallet;

        if (walletNotSelected) {
          context.pop();
          return;
        }

        context.read<SelectSendWalletStep>().goBack();
      },
    );
  }
}
