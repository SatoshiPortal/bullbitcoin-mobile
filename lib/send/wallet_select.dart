import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/send/send_page.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SelectSendWalletStep extends Cubit<({bool selectWallet, WalletBloc? walletBloc, bool sent})> {
  SelectSendWalletStep() : super((selectWallet: true, walletBloc: null, sent: false));

  void goBack() => emit((selectWallet: true, walletBloc: null, sent: false));
  void goNext(WalletBloc bloc) => emit((selectWallet: false, walletBloc: bloc, sent: false));
  void sent() => emit((selectWallet: false, walletBloc: state.walletBloc, sent: true));
}

class SelectSendWalletPage extends StatefulWidget {
  const SelectSendWalletPage({super.key, this.walletBloc});

  final WalletBloc? walletBloc;

  @override
  State<SelectSendWalletPage> createState() => _SelectSendWalletPageState();
}

class _SelectSendWalletPageState extends State<SelectSendWalletPage> {
  late SelectSendWalletStep stepBloc;

  @override
  void initState() {
    stepBloc = SelectSendWalletStep();
    if (widget.walletBloc != null) stepBloc.goNext(widget.walletBloc!);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final homeCubit = locator<HomeCubit>();

    return BlocProvider.value(
      value: homeCubit,
      child: BlocProvider.value(
        value: stepBloc,
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
    final network = context.select((NetworkCubit _) => _.state.getBBNetwork());
    final walletBlocs =
        context.select((HomeCubit _) => _.state.walletBlocsFromNetwork(network)).reversed;

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
    final sent = context.select((SelectSendWalletStep _) => _.state.sent);

    if (sent)
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.green,
      );

    return BBAppBar(
      text: 'Send Bitcoin',
      onBack: () {
        // final walletNotSelected = context.read<SelectSendWalletStep>().state.selectWallet;

        // if (walletNotSelected) {
        context.pop();
        //   return;
        // }

        // context.read<SelectSendWalletStep>().goBack();
      },
    );
  }
}
