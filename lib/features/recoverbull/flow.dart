import 'package:bb_mobile/core_deprecated/recoverbull/domain/usecases/fetch_permission_usecase.dart';
import 'package:bb_mobile/core_deprecated/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/connecting_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/server_confirmation_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/settings_page.dart';
import 'package:bb_mobile/locator.dart';
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
  final _fetchPermissionUsecase = locator<FetchPermissionUsecase>();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _fetchPermissionUsecase.execute(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: FadingLinearProgress(trigger: true)),
          );
        }

        final flow = context.read<RecoverBullBloc>().state.flow;

        Widget page = switch (flow) {
          RecoverBullFlow.settings => const SettingsPage(),
          _ => const ConnectingPage(),
        };

        final hasPermission = snapshot.data ?? false;
        if (!hasPermission) {
          page = const RequestPermissionPage();
        } else {
          context.read<RecoverBullBloc>().add(const OnTorInitialization());
          context.read<RecoverBullBloc>().add(const OnServerCheck());
        }

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
      },
    );
  }
}
