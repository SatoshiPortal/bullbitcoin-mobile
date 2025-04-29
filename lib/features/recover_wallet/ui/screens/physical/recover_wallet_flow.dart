import 'package:bb_mobile/features/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';
import 'package:bb_mobile/features/recover_wallet/ui/screens/physical/recover_physical_wallet_success_screen.dart';
import 'package:bb_mobile/features/recover_wallet/ui/screens/physical/wallet_input_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverPhysicalWalletFlow extends StatefulWidget {
  const RecoverPhysicalWalletFlow({super.key, required this.fromOnboarding});

  final bool fromOnboarding;

  @override
  State<RecoverPhysicalWalletFlow> createState() =>
      _RecoverPhysicalWalletFlowState();
}

class _RecoverPhysicalWalletFlowState extends State<RecoverPhysicalWalletFlow> {
  late RecoverWalletBloc recoverWalletBloc;

  @override
  void initState() {
    recoverWalletBloc = locator<RecoverWalletBloc>();
    if (widget.fromOnboarding) {
      recoverWalletBloc.add(const RecoverFromOnboarding());
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RecoverWalletBloc>(
      create: (_) => recoverWalletBloc,
      child: BlocSelector<
        RecoverWalletBloc,
        RecoverWalletState,
        RecoverWalletStatus
      >(
        selector: (state) => state.recoverWalletStatus,
        builder: (context, RecoverWalletStatus recoverWalletStatus) {
          return switch (recoverWalletStatus) {
            RecoverWalletInitialized _ =>
              const RecoverPhysicalWalletInputScreen(),
            RecoverWalletLoading _ => const RecoverPhysicalWalletInputScreen(),
            RecoverWalletOK _ => const RecoverPhysicalWalletSuccessScreen(),
            // RecoverWalletFailure() => const RecoverPhysicalWalletErrorScreen(),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}
