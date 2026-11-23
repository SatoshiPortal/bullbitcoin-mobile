import 'package:startup/src/ui/screens/restore_default_secret_screen.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:startup/src/l10n.dart';
import 'package:bull_logs/bull_logs.dart';
import 'package:get_it/get_it.dart';
import 'package:startup/src/domain/app_startup_failure.dart';
import 'package:startup/src/presentation/app_startup_failure_l10n.dart';
import 'package:startup/src/presentation/bloc/app_startup_bloc.dart';
import 'package:access/access.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullShapesX, BullSupportButton, Gap, BullTypographyX;

class AppStartupWidget extends StatefulWidget {
  const AppStartupWidget({
    super.key,
    required this.app,
    required this.onUnlocked,
    required this.splash,
    required this.openOnboarding,
  });

  final Widget app;
  final Widget splash;
  final VoidCallback openOnboarding;
  final Future<void> Function() onUnlocked;

  @override
  State<AppStartupWidget> createState() => _AppStartupWidgetState();
}

class _AppStartupWidgetState extends State<AppStartupWidget> {
  @override
  Widget build(BuildContext context) {
    return AppStartupListener(
      openOnboarding: widget.openOnboarding,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: BlocBuilder<AppStartupBloc, AppStartupState>(
          builder: (context, state) {
            if (state is AppStartupInitial) {
              return widget.splash;
            } else if (state is AppStartupLoadingInProgress) {
              return widget.splash;
              // show status of migration
            } else if (state is AppStartupSuccess) {
              if (state.isPinCodeSet) {
                // The PIN may already be required when this widget mounts.
                return Overlay.wrap(
                  child: const Access().buildReauthenticationGate(
                    onSuccess: (_) async {
                      await widget.onUnlocked();
                      if (!context.mounted) return;
                      context.read<AppStartupBloc>().add(
                        const AppStartupUnlocked(),
                      );
                    },
                  ),
                );
              }
              return widget.app;
            } else if (state is AppStartupFailureState) {
              return AppStartupFailureScreen(failure: state.failure);
            }

            // TODO: remove this when all states are handled and return the
            //  appropriate widget
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class AppStartupListener extends StatelessWidget {
  const AppStartupListener({
    super.key,
    required this.child,
    required this.openOnboarding,
  });

  final Widget child;
  final VoidCallback openOnboarding;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AppStartupBloc, AppStartupState>(
          listenWhen: (previous, current) =>
              current is AppStartupSuccess &&
              !current.isPinCodeSet &&
              !current.hasDefaultWallets &&
              previous != current,
          listener: (context, state) {
            openOnboarding();
          },
        ),
      ],
      child: child,
    );
  }
}

class AppStartupFailureScreen extends StatefulWidget {
  const AppStartupFailureScreen({super.key, required this.failure});

  final AppStartupFailure failure;

  @override
  State<AppStartupFailureScreen> createState() =>
      _AppStartupFailureScreenState();
}

class _AppStartupFailureScreenState extends State<AppStartupFailureScreen> {
  bool _restoring = false;

  @override
  Widget build(BuildContext context) {
    final failure = widget.failure;
    if (_restoring && failure is AppStartupMissingDefaultSecretFailure) {
      return RestoreDefaultSecretScreen(
        onCancel: () => setState(() => _restoring = false),
      );
    }
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: .center,
            mainAxisSize: .min,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.bullShapes.card),
                ),
                tileColor: context.appColors.error.withValues(alpha: 0.1),
                title: Row(
                  children: [
                    Icon(Icons.error_outline, color: context.appColors.error),
                    const Gap(8),
                    Text(
                      context.loc.appStartupErrorTitle,
                      style: context.bullType.subtitle
                          .copyWith(fontWeight: FontWeight.w700)
                          .copyWith(color: context.appColors.error),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    failure.toTranslated(context),
                    style: context.bullType.body.copyWith(
                      color: context.appColors.secondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              // The seed is gone but the wallets are not: the user's own
              // backup brings it back, checked against the missing wallet.
              if (failure is AppStartupMissingDefaultSecretFailure) ...[
                const SizedBox(height: 24),
                BullButton.secondary(
                  onPressed: () => setState(() => _restoring = true),
                  label: context.loc.appStartupRestoreSecretButton,
                ),
              ],
              const SizedBox(height: 24),
              Text(
                context.loc.appStartupContactSupportMessage,
                style: context.bullType.label
                    .copyWith(fontWeight: FontWeight.w400)
                    .copyWith(
                      color: context.appColors.secondary.withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              BullSupportButton.big(
                label: context.loc.appStartupContactSupportButton,
                bgColor: context.appColors.primary,
                textColor: context.appColors.onPrimary,
              ),
              const SizedBox(height: 24),
              ShareLogsWidget(facade: GetIt.I<LogsFacade>()),
            ],
          ),
        ),
      ),
    );
  }
}
