import 'package:settings/src/l10n.dart';
import 'package:settings/src/presentation/bloc/background_preferences_cubit.dart';
import 'package:settings/src/presentation/settings_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullInfoBar,
        BullInfoTone,
        BullSettingsEntryItem,
        BullSwitch;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// Background tasks, then the notifications they send. Every state shown here
/// is read again from the system when the user comes back to the app.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The user may have changed a permission in the system settings.
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<BackgroundPreferencesCubit>().load(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BackgroundPreferencesCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.permissionsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child:
              BlocBuilder<
                BackgroundPreferencesCubit,
                BackgroundPreferencesState
              >(
                builder: (context, state) {
                  final enabled = state.enabled;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MergeSemantics(
                        child: BullSettingsEntryItem(
                          icon: Icons.sync,
                          title: context.loc.backgroundTasksTitle,
                          trailing: BullSwitch(
                            value: enabled ?? false,
                            onChanged: enabled == null
                                ? null
                                : (value) => cubit.load(enabled: value),
                          ),
                        ),
                      ),
                      if (enabled ?? false) ...[
                        MergeSemantics(
                          child: BullSettingsEntryItem(
                            icon: Icons.notifications_none,
                            title: context.loc.notificationsTitle,
                            // Only the system can take the permission back.
                            trailing: BullSwitch(
                              value: state.allowed,
                              onChanged: (value) => value
                                  ? cubit.load(requestPermission: true)
                                  : cubit.load(openSettings: true),
                            ),
                          ),
                        ),
                        if (state.refused)
                          // Aligned with the content of the rows above.
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                BullInfoBar(
                                  tone: BullInfoTone.warning,
                                  icon: Icons.notifications_off_outlined,
                                  message:
                                      context.loc.notificationsBlockedMessage,
                                ),
                                const SizedBox(height: 16),
                                BullButton.secondary(
                                  label: context.loc.openSystemSettings,
                                  onPressed: () =>
                                      cubit.load(openSettings: true),
                                ),
                              ],
                            ),
                          ),
                      ],
                      if (state.failure case final failure?) ...[
                        const SizedBox(height: 16),
                        Text(failure.toTranslated(context)),
                      ],
                    ],
                  );
                },
              ),
        ),
      ),
    );
  }
}
