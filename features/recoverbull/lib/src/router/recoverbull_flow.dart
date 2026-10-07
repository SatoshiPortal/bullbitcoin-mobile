import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/usecases/fetch_permission_usecase.dart';
import '../presentation/bloc.dart';
import '../ui/screens/connecting_page.dart';
import 'flow_type.dart';

/// Owns the permission gate and nested navigation used by every flow.
class RecoverBullFlowNavigator extends StatefulWidget {
  final RecoverBullFlow flow;
  final FetchPermissionUsecase fetchPermissionUsecase;
  final WidgetBuilder settingsPageBuilder;
  final WidgetBuilder requestPermissionPageBuilder;

  const RecoverBullFlowNavigator({
    super.key,
    required this.flow,
    required this.fetchPermissionUsecase,
    required this.settingsPageBuilder,
    required this.requestPermissionPageBuilder,
  });

  @override
  State<RecoverBullFlowNavigator> createState() =>
      _RecoverBullFlowNavigatorState();
}

class _RecoverBullFlowNavigatorState extends State<RecoverBullFlowNavigator> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final Future<bool> _permissionFuture;
  bool _initializationRequested = false;
  bool _nestedNavigatorCanPop = false;

  @override
  void initState() {
    super.initState();
    _permissionFuture = widget.fetchPermissionUsecase.execute();
  }

  void _updateNestedNavigatorCanPop() {
    final canPop = _navigatorKey.currentState?.canPop() ?? false;
    if (canPop != _nestedNavigatorCanPop && mounted) {
      setState(() => _nestedNavigatorCanPop = canPop);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _permissionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final page = switch (widget.flow) {
          RecoverBullFlow.settings => widget.settingsPageBuilder(context),
          _ when snapshot.data != true => widget.requestPermissionPageBuilder(
            context,
          ),
          _ => const ConnectingPage(),
        };

        if (snapshot.data == true &&
            widget.flow != RecoverBullFlow.settings &&
            !_initializationRequested) {
          _initializationRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.read<RecoverBullBloc>().add(const OnTorInitialization());
            }
          });
        }

        return PopScope(
          canPop: !_nestedNavigatorCanPop,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _nestedNavigatorCanPop) {
              _navigatorKey.currentState!.pop();
            }
          },
          child: Navigator(
            key: _navigatorKey,
            observers: [
              _NestedNavigatorObserver(onChanged: _updateNestedNavigatorCanPop),
            ],
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => page),
          ),
        );
      },
    );
  }
}

class _NestedNavigatorObserver extends NavigatorObserver {
  final VoidCallback onChanged;

  _NestedNavigatorObserver({required this.onChanged});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onChanged();
}
