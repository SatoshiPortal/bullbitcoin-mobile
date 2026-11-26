import 'dart:async';

import 'package:settings/src/l10n.dart';
import 'package:settings/src/presentation/bloc/settings_cubit.dart';
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
    return SevenTapUnlocker(
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

class SevenTapUnlocker extends StatefulWidget {
  final VoidCallback onRequiredTaps;
  final Widget child;
  final String tapsReachedMessage;
  final String? semanticsIdentifier;
  final bool showMessage;

  const SevenTapUnlocker({
    super.key,
    required this.onRequiredTaps,
    required this.tapsReachedMessage,
    required this.child,
    this.semanticsIdentifier,
    this.showMessage = true,
  });

  @override
  State<SevenTapUnlocker> createState() => _MultiTapTriggerState();
}

class _MultiTapTriggerState extends State<SevenTapUnlocker> {
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
      if (widget.showMessage) {
        BullSnackBar.show(context, message: widget.tapsReachedMessage);
      }
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
      identifier: widget.semanticsIdentifier,
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
