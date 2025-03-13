import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';
import 'package:bb_mobile/recover_wallet/ui/screens/recover_wallet_input_screen.dart';
import 'package:bb_mobile/recover_wallet/ui/screens/recover_wallet_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverWalletFlow extends StatefulWidget {
  const RecoverWalletFlow({super.key, required this.fromOnboarding});

  final bool fromOnboarding;

  @override
  State<RecoverWalletFlow> createState() => _RecoverWalletFlowState();
}

class _RecoverWalletFlowState extends State<RecoverWalletFlow> {
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
      child: BlocSelector<RecoverWalletBloc, RecoverWalletState,
          RecoverWalletStatus>(
        selector: (state) => state.status,
        builder: (context, status) {
          switch (status) {
            case RecoverWalletStatus.inProgress:
              return const RecoverWalletInputScreen();
            case RecoverWalletStatus.success:
              return const RecoverWalletSuccessScreen();
          }
        },
      ),
    );
  }
}
