import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_permission_usecase.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
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

  /// Guards the one-shot connection kickoff below.
  bool _connectionRequested = false;

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
        } else if (!_connectionRequested) {
          // Dispatched once, and after the frame rather than during it.
          //
          // This used to fire on every rebuild of the FutureBuilder, which
          // started a second key-server check on top of the one already in
          // flight — the duplicated "waiting for Tor" traces came from here, not
          // from two isolates. Repeated dispatch also makes any Tor restart
          // unsafe: a rebuild storm would tear the client down mid-bootstrap.
          //
          // `OnServerCheck` is not dispatched here: `OnTorInitialization`
          // already chains to it once Tor is up, so sending both raced them.
          _connectionRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.read<RecoverBullBloc>().add(const OnTorInitialization());
          });
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
