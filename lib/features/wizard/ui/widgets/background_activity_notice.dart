import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/wizard/presentation/background_activity_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullText;

/// Shown only while Android restricts the app in the background: some vendors
/// then never run the periodic checks, so notifications would never arrive.
class BackgroundActivityNotice extends StatefulWidget {
  const BackgroundActivityNotice({super.key});

  @override
  State<BackgroundActivityNotice> createState() =>
      _BackgroundActivityNoticeState();
}

class _BackgroundActivityNoticeState extends State<BackgroundActivityNotice> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    context.read<BackgroundActivityCubit>().refresh();
    // Back from the system settings: hide the notice once it is allowed.
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<BackgroundActivityCubit>().refresh(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restricted = context.watch<BackgroundActivityCubit>().state;
    if (!restricted) return const SizedBox.shrink();
    final loc = context.loc;
    final bodyStyle = context.font.bodyMedium?.copyWith(
      color: context.appColors.onSurfaceVariant,
      height: 1.4,
    );
    final vGap = Device.screen.height * 0.009;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: vGap * 2),
        BullText(
          loc.permissionsBackgroundTitle,
          style: context.font.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.appColors.onSurface,
          ),
        ),
        SizedBox(height: vGap),
        BullText(loc.permissionsBackgroundDescription, style: bodyStyle),
        SizedBox(height: vGap),
        BullText(loc.permissionsBackgroundHint, style: bodyStyle),
        TextButton(
          onPressed: context.read<BackgroundActivityCubit>().openSettings,
          child: Text(loc.permissionsOpenBatterySettings),
        ),
      ],
    );
  }
}
