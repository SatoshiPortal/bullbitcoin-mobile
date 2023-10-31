import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/wallet_card.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/receive/receive_page.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SelectReceiveWalletStep extends Cubit<({bool selectWallet, WalletBloc? walletBloc})> {
  SelectReceiveWalletStep() : super((selectWallet: true, walletBloc: null));

  void goBack() => emit((selectWallet: true, walletBloc: null));
  void goNext(WalletBloc bloc) => emit((selectWallet: false, walletBloc: bloc));
}

class SelectReceiveWalletPage extends StatefulWidget {
  const SelectReceiveWalletPage({super.key, this.walletBloc});

  final WalletBloc? walletBloc;

  @override
  State<SelectReceiveWalletPage> createState() => _SelectReceiveWalletPageState();
}

class _SelectReceiveWalletPageState extends State<SelectReceiveWalletPage> {
  late SelectReceiveWalletStep stepBloc;

  @override
  void initState() {
    stepBloc = SelectReceiveWalletStep();
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
            flexibleSpace: const ReceiveAppBar(),
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
    final walletNotSelected = context.select((SelectReceiveWalletStep _) => _.state.selectWallet);

    return AnimatedSwitcher(
      duration: 400.ms,
      child: walletNotSelected ? const SelectWalletScreen() : const ReceiveScreen(),
    );
  }
}

class SelectWalletScreen extends StatelessWidget {
  const SelectWalletScreen();

  @override
  Widget build(BuildContext context) {
    final network = context.select((SettingsCubit _) => _.state.getBBNetwork());
    final walletBlocs =
        context.select((HomeCubit _) => _.state.walletBlocsFromNetwork(network).reversed);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Gap(32),
            const BBText.body('Select wallet to receive in'),
            const Gap(24),
            for (final wallet in walletBlocs) ...[
              BlocProvider.value(
                value: wallet,
                child: HomeCard(
                  onTap: () {
                    context.read<SelectReceiveWalletStep>().goNext(wallet);
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

class ReceiveAppBar extends StatelessWidget {
  const ReceiveAppBar();

  @override
  Widget build(BuildContext context) {
    return BBAppBar(
      text: 'Receive Bitcoin',
      onBack: () {
        final walletNotSelected = context.read<SelectReceiveWalletStep>().state.selectWallet;

        if (walletNotSelected) {
          context.pop();
          return;
        }

        context.read<SelectReceiveWalletStep>().goBack();
      },
    );
  }
}
