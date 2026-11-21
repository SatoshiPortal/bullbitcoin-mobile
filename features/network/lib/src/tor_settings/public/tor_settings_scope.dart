import '../presentation/tor_settings_cubit.dart';

import 'package:get_it/get_it.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class TorSettingsScope extends StatefulWidget {
  final Widget child;

  const TorSettingsScope({required this.child, super.key});

  static Widget provideFrom({
    required BuildContext context,
    required Widget child,
  }) =>
      BlocProvider.value(value: context.read<TorSettingsCubit>(), child: child);

  @override
  State<TorSettingsScope> createState() => _TorSettingsScopeState();
}

final class _TorSettingsScopeState extends State<TorSettingsScope>
    with WidgetsBindingObserver {
  late final TorSettingsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = GetIt.I<TorSettingsCubit>()..init();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _cubit.onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider.value(value: _cubit, child: widget.child);
}
