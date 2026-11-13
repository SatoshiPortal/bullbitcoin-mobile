import 'dart:io';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bb_mobile/features/settings/domain/usecases/watch_settings_quick_actions_usecase.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_ui/bull_ui.dart';

class QuickActionsSettingsScreen extends StatefulWidget {
  const QuickActionsSettingsScreen({
    required this.facade,
    required this.watch,
    super.key,
  });
  final QuickActionsFacade facade;
  final WatchSettingsQuickActionsUsecase watch;

  @override
  State<QuickActionsSettingsScreen> createState() =>
      _QuickActionsSettingsScreenState();
}

class _QuickActionsSettingsScreenState
    extends State<QuickActionsSettingsScreen> {
  late final _changes = widget.watch.execute();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<SettingsQuickActionOptions>(
        stream: _changes,
        initialData: widget.watch.current,
        builder: (context, snapshot) {
          final options = snapshot.data ?? widget.watch.current;
          final platformAllowed =
              !Platform.isIOS ||
              context.select(
                (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
              );
          final available = platformAllowed
              ? options.available
              : <QuickAction>{
                  QuickAction.map,
                  QuickAction.transfer,
                  QuickAction.history,
                  QuickAction.settings,
                  QuickAction.support,
                  QuickAction.priceHistory,
                };
          return QuickActionsCustomizationScreen(
            facade: widget.facade,
            available: available,
            defaults: options.defaults,
          );
        },
      );
}
