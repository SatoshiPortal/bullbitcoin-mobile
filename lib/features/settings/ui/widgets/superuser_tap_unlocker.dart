import 'dart:async';

import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SuperuserTapUnlocker extends StatelessWidget {
  const SuperuserTapUnlocker({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isSuperuser = context.select(
      (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
    );
    return _MultiTapTrigger(
      onRequiredTaps: () async {
        await context.read<SettingsCubit>().toggleSuperuserMode(!isSuperuser);
      },
      tapsReachedMessage: isSuperuser
          ? context.loc.settingsSuperuserModeDisabledMessage
          : context.loc.settingsSuperuserModeUnlockedMessage,
      child: child,
    );
  }
}

class _MultiTapTrigger extends StatefulWidget {
  final VoidCallback onRequiredTaps;
  final Widget child;
  final String tapsReachedMessage;

  const _MultiTapTrigger({
    required this.onRequiredTaps,
    required this.tapsReachedMessage,
    required this.child,
  });

  @override
  State<_MultiTapTrigger> createState() => _MultiTapTriggerState();
}

class _MultiTapTriggerState extends State<_MultiTapTrigger> {
  int _tapCount = 0;
  Timer? _resetTimer;

  void _onTap() {
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 2), () {
      setState(() {
        _tapCount = 0;
      });
    });

    setState(() {
      _tapCount++;
    });

    if (_tapCount >= 7) {
      _resetTimer?.cancel();
      widget.onRequiredTaps();
      BullSnackBar.show(context, message: widget.tapsReachedMessage);
      setState(() {
        _tapCount = 0;
      });
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.loc.onboardingBullBitcoin,
      button: true,
      child: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: widget.child,
      ),
    );
  }
}
