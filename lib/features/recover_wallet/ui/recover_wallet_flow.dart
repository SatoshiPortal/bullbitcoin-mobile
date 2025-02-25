import 'package:bb_mobile/features/app_startup/app_locator.dart';
import 'package:bb_mobile/features/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';
import 'package:bb_mobile/features/recover_wallet/ui/screens/recover_wallet_input_screen.dart';
import 'package:bb_mobile/features/recover_wallet/ui/screens/recover_wallet_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverWalletFlow extends StatelessWidget {
  const RecoverWalletFlow({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocProvider<RecoverWalletBloc>(
      create: (_) => locator<RecoverWalletBloc>(),
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
