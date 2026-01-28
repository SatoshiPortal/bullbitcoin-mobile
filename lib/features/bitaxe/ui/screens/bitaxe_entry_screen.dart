import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/bitaxe/presentation/bloc/bitaxe_bloc.dart';
import 'package:bb_mobile/features/bitaxe/presentation/bloc/bitaxe_event.dart';
import 'package:bb_mobile/features/bitaxe/presentation/bloc/bitaxe_state.dart';
import 'package:bb_mobile/features/bitaxe/ui/bitaxe_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Smart entry point that checks for stored connection and routes accordingly
class BitaxeEntryScreen extends StatefulWidget {
  const BitaxeEntryScreen({super.key});

  @override
  State<BitaxeEntryScreen> createState() => _BitaxeEntryScreenState();
}

class _BitaxeEntryScreenState extends State<BitaxeEntryScreen> {
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    // Give BLoC a moment to load, then check and navigate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        final state = context.read<BitaxeBloc>().state;
        _navigateBasedOnState(state);
      });
    });
  }

  void _navigateBasedOnState(BitaxeState state) {
    if (!mounted || _hasChecked) return;

    final device = state.device;

    // If device exists and no error, go to dashboard
    if (device != null && state.error == null) {
      _hasChecked = true;
      context.pushReplacementNamed(BitaxeRoute.dashboard.name);
    } else if (device == null && !state.isConnecting) {
      // No device and not connecting, go to connection screen
      _hasChecked = true;
      context.pushReplacementNamed(BitaxeRoute.connection.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BitaxeBloc, BitaxeState>(
      listener: (context, state) {
        _navigateBasedOnState(state);
      },
      child: BlocBuilder<BitaxeBloc, BitaxeState>(
        builder: (context, state) {
          final device = state.device;

          // If device exists but there's an error, show error UI
          if (device != null && state.error != null && !state.isConnecting) {
            return Scaffold(
              backgroundColor: context.appColors.background,
              appBar: AppBar(
                title: BBText(
                  'Connection Error',
                  style: context.font.headlineSmall,
                  color: context.appColors.text,
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: context.appColors.error,
                    ),
                    const Gap(16),
                    BBText(
                      'Device Unreachable',
                      style: context.font.headlineMedium,
                      color: context.appColors.text,
                      textAlign: TextAlign.center,
                    ),
                    const Gap(8),
                    BBText(
                      'The device at ${device.ipAddress} is not reachable. Please check your connection and try again.',
                      style: context.font.bodyMedium,
                      color: context.appColors.textMuted,
                      textAlign: TextAlign.center,
                    ),
                    const Gap(24),
                    BBButton.big(
                      label: 'Retry',
                      onPressed: () {
                        context.read<BitaxeBloc>().add(
                          const BitaxeEvent.loadStoredConnection(),
                        );
                      },
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                    ),
                    const Gap(8),
                    TextButton(
                      onPressed: () {
                        // Replace entry screen with connection screen
                        context.pushReplacementNamed(
                          BitaxeRoute.connection.name,
                        );
                      },
                      child: BBText(
                        'Enter New IP Address',
                        style: context.font.bodyMedium,
                        color: context.appColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Show loading
          return Scaffold(
            backgroundColor: context.appColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: context.appColors.primary),
                  const Gap(16),
                  BBText(
                    'Checking for stored connection...',
                    style: context.font.bodyMedium,
                    color: context.appColors.text,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
