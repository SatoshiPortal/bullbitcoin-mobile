import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/wizard/presentation/background_activity_cubit.dart';
import 'package:bb_mobile/features/wizard/presentation/permissions_cubit.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/permissions_choice_row.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/permissions_step.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The wizard's Permissions page, offered once after unlock to users who
/// installed before it existed.
class PermissionsIntroScreen extends StatelessWidget {
  const PermissionsIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hPad = Device.screen.width * 0.06;
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => locator<PermissionsCubit>()),
        BlocProvider(create: (_) => locator<BackgroundActivityCubit>()),
      ],
      child: Scaffold(
        backgroundColor: context.appColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: PermissionsStep()),
              Positioned(
                left: hPad,
                right: hPad,
                bottom: hPad,
                child: BlocBuilder<PermissionsCubit, bool>(
                  builder: (context, busy) => PermissionsChoiceRow(
                    busy: busy,
                    onAllow: () => _answer(context, true),
                    onNotNow: () => _answer(context, false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _answer(BuildContext context, bool allowNotifications) async {
    final handled = await context.read<PermissionsCubit>().answer(
      allowNotifications: allowNotifications,
    );
    if (handled && context.mounted) context.pop();
  }
}
