import 'dart:async';

import 'package:bb_mobile/features/backup_settings/domain/usecases/update_data_backup_lifecycle_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_setup_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DataBackupScope extends StatefulWidget {
  final Widget child;
  final bool ready;
  const DataBackupScope({super.key, required this.child, required this.ready});

  @override
  State<DataBackupScope> createState() => _DataBackupScopeState();
}

class _DataBackupScopeState extends State<DataBackupScope> {
  late final UpdateDataBackupLifecycleUsecase _lifecycle;
  late final DataBackupSetupCubit _setup;
  late final AppLifecycleListener _listener;
  late final StreamSubscription<void> _changes;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = locator<UpdateDataBackupLifecycleUsecase>();
    _setup = DataBackupSetupCubit(_lifecycle);
    final current = WidgetsBinding.instance.lifecycleState;
    _foreground = current == null || current == AppLifecycleState.resumed;
    _listener = AppLifecycleListener(
      onStateChange: (state) {
        _foreground = state == AppLifecycleState.resumed;
        _update();
      },
    );
    _changes = _lifecycle.changes.listen(
      (_) => _update(),
      onError: (Object _) {
        unawaited(_setup.update(ready: false, foreground: _foreground));
      },
    );
    _update();
  }

  void _update() =>
      unawaited(_setup.update(ready: widget.ready, foreground: _foreground));

  @override
  void didUpdateWidget(DataBackupScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ready != widget.ready) _update();
  }

  @override
  void dispose() {
    _listener.dispose();
    unawaited(_changes.cancel());
    unawaited(_setup.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider<DataBackupSetupCubit>.value(
        value: _setup,
        child: widget.child,
      );
}
