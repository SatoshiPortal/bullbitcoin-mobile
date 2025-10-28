import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/password_input_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/vault_provider_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverBullFlowNavigator extends StatefulWidget {
  const RecoverBullFlowNavigator({super.key});

  @override
  State<RecoverBullFlowNavigator> createState() =>
      _RecoverBullFlowNavigatorState();
}

class _RecoverBullFlowNavigatorState extends State<RecoverBullFlowNavigator> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<RecoverBullBloc>();
    final flow = bloc.state.flow;
    final hasPreSelectedVault = bloc.state.vault != null;

    return PopScope(
      canPop: !(_navigatorKey.currentState?.canPop() ?? false),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && (_navigatorKey.currentState?.canPop() ?? false)) {
          _navigatorKey.currentState?.pop();
        }
      },
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) {
              return switch (flow) {
                RecoverBullFlow.secureVault => const PasswordInputPage(),
                _ =>
                  hasPreSelectedVault
                      ? const PasswordInputPage()
                      : const VaultProviderSelectionPage(),
              };
            },
          );
        },
      ),
    );
  }
}
