import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/background_activity_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/notification_permission_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Optional OS permissions. The OS stays the source of truth: the page reads
/// its state, asks through the OS prompt, and sends to the system settings
/// once the OS no longer prompts.
class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => locator<NotificationPermissionCubit>()..refresh(),
      ),
      BlocProvider(
        create: (_) => locator<BackgroundActivityCubit>()..refresh(),
      ),
    ],
    child: Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsPermissionsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.loc.permissionsIntro,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const Gap(24),
            const _NotificationPermissionSection(),
            const _BackgroundActivitySection(),
          ],
        ),
      ),
    ),
  );
}

class _NotificationPermissionSection extends StatefulWidget {
  const _NotificationPermissionSection();

  @override
  State<_NotificationPermissionSection> createState() =>
      _NotificationPermissionSectionState();
}

class _NotificationPermissionSectionState
    extends State<_NotificationPermissionSection> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from the system settings: show what the user changed there.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        context.read<NotificationPermissionCubit>().refresh();
        context.read<BackgroundActivityCubit>().refresh();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotificationPermissionCubit>().state;
    final cubit = context.read<NotificationPermissionCubit>();
    final loc = context.loc;
    final status = switch (state.status) {
      NotificationPermissionStatus.loading => '',
      NotificationPermissionStatus.allowed => loc.permissionsStatusAllowed,
      NotificationPermissionStatus.off => loc.permissionsStatusOff,
      NotificationPermissionStatus.unavailable =>
        loc.permissionsStatusUnavailable,
    };
    final askOs =
        state.status == NotificationPermissionStatus.off &&
        !state.promptDeclined;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                loc.permissionsNotificationsTitle,
                style: context.font.titleMedium,
              ),
            ),
            Text(
              status,
              style: context.font.bodyMedium?.copyWith(
                color: state.status == NotificationPermissionStatus.allowed
                    ? context.appColors.success
                    : context.appColors.textMuted,
              ),
            ),
          ],
        ),
        const Gap(8),
        Text(
          loc.permissionsNotificationsDescription,
          style: context.font.bodyMedium,
        ),
        if (state.promptDeclined &&
            state.status == NotificationPermissionStatus.off) ...[
          const Gap(8),
          Text(
            loc.permissionsNotificationsOffHint,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
        ],
        const Gap(16),
        if (askOs)
          BullButton.big(
            label: loc.permissionsAllowNotifications,
            onPressed: cubit.request,
            disabled: state.busy,
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          )
        else if (state.status != NotificationPermissionStatus.loading)
          BullButton.big(
            label: loc.permissionsOpenSystemSettings,
            onPressed: cubit.openSystemSettings,
            outlined: true,
            bgColor: Colors.transparent,
            textColor: context.appColors.secondary,
          ),
      ],
    );
  }
}

/// Android only: some vendors stop periodic work entirely until the user
/// allows unrestricted battery use, so notifications would never arrive.
class _BackgroundActivitySection extends StatelessWidget {
  const _BackgroundActivitySection();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<BackgroundActivityCubit>().state;
    if (status == BackgroundActivityStatus.unknown ||
        status == BackgroundActivityStatus.notApplicable) {
      return const SizedBox.shrink();
    }
    final loc = context.loc;
    final unrestricted = status == BackgroundActivityStatus.unrestricted;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.permissionsBackgroundTitle,
                  style: context.font.titleMedium,
                ),
              ),
              Text(
                unrestricted
                    ? loc.permissionsStatusUnrestricted
                    : loc.permissionsStatusRestricted,
                style: context.font.bodyMedium?.copyWith(
                  color: unrestricted
                      ? context.appColors.success
                      : context.appColors.textMuted,
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            loc.permissionsBackgroundDescription,
            style: context.font.bodyMedium,
          ),
          if (!unrestricted) ...[
            const Gap(8),
            Text(
              loc.permissionsBackgroundHint,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
          ],
          const Gap(16),
          BullButton.big(
            label: loc.permissionsOpenBatterySettings,
            onPressed: context.read<BackgroundActivityCubit>().openSettings,
            outlined: unrestricted,
            bgColor: unrestricted
                ? Colors.transparent
                : context.appColors.primary,
            textColor: unrestricted
                ? context.appColors.secondary
                : context.appColors.onPrimary,
          ),
        ],
      ),
    );
  }
}
