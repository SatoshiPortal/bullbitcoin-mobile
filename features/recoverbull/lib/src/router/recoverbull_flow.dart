import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';
import '../domain/recoverbull_failure.dart';
import '../presentation/recoverbull_failure_l10n.dart';
import '../l10n/context_localizations.dart';
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
  late Future<Result<bool, RecoverBullFailure>> _permissionFuture;
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
    return FutureBuilder<Result<bool, RecoverBullFailure>>(
      future: _permissionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const BullScaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final result = snapshot.data;
        if (result case Err(:final failure)) {
          return BullScaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BullText(
                    failure.toTranslated(context),
                    style: context.bullText.bodyMedium,
                  ),
                  BullButton.big(
                    label: context.loc.recoverbullRetry,
                    bgColor: context.bull.primary,
                    textColor: context.bull.onPrimary,
                    onPressed: () => setState(() {
                      _permissionFuture = widget.fetchPermissionUsecase
                          .execute();
                    }),
                  ),
                ],
              ),
            ),
          );
        }
        final hasPermission =
            result is Ok<bool, RecoverBullFailure> && result.value;
        final page = switch (widget.flow) {
          RecoverBullFlow.settings => widget.settingsPageBuilder(context),
          _ when !hasPermission => widget.requestPermissionPageBuilder(context),
          _ => const ConnectingPage(),
        };

        if (hasPermission &&
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
              _navigatorKey.currentState?.maybePop();
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
