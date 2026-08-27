import 'package:bb_mobile/features/tor_settings/presentation/bloc/embedded_tor_status_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

Future<bool> _neverShowTorStatus() async => false;

class EmbeddedTorStatusScope extends StatefulWidget {
  final Widget child;
  final Future<bool> Function() shouldShow;

  const EmbeddedTorStatusScope({
    super.key,
    required this.child,
    this.shouldShow = _neverShowTorStatus,
  });

  @override
  State<EmbeddedTorStatusScope> createState() => _EmbeddedTorStatusScopeState();
}

class _EmbeddedTorStatusScopeState extends State<EmbeddedTorStatusScope>
    with WidgetsBindingObserver {
  late final EmbeddedTorStatusCubit _cubit;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = locator<EmbeddedTorStatusCubit>();
    _cubit.setVisibilityChecker(widget.shouldShow);
    _cubit.init().ignore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (identical(router, _router)) return;
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _router = router;
    router.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cubit.refreshConfiguration().ignore();
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close().ignore();
    super.dispose();
  }

  void _onRouteChanged() {
    _cubit.refreshConfiguration().ignore();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(value: _cubit, child: widget.child);
  }
}
