import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/connecting_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/settings_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/view_backup_key_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/derive_vault_key_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverBullFlowNavigator extends StatefulWidget {
  final bool viewKeyMethodSelection;
  const RecoverBullFlowNavigator({
    super.key,
    this.viewKeyMethodSelection = false,
  });

  @override
  State<RecoverBullFlowNavigator> createState() =>
      _RecoverBullFlowNavigatorState();
}

class _RecoverBullFlowNavigatorState extends State<RecoverBullFlowNavigator> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<RecoverBullBloc>();
      if (bloc.state.flow != RecoverBullFlow.settings &&
          !widget.viewKeyMethodSelection &&
          !bloc.state.deriveKeyLocally) {
        // Tor initialization chains the server check. Start it once per flow,
        // not on rebuild, and never connect merely to edit server settings.
        bloc.add(const OnTorInitialization());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.viewKeyMethodSelection) return const ViewBackupKeyPage();
    if (context.read<RecoverBullBloc>().state.deriveKeyLocally) {
      return const DeriveVaultKeyPage();
    }
    final page = switch (context.read<RecoverBullBloc>().state.flow) {
      RecoverBullFlow.settings => const SettingsPage(),
      _ => const ConnectingPage(),
    };
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
          return MaterialPageRoute(builder: (context) => page);
        },
      ),
    );
  }
}
