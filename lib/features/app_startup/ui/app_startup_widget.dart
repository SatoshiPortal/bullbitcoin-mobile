import 'package:screen_privacy/screen_privacy.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'dart:async';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bull_logs/bull_logs.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/presentation/app_startup_failure_l10n.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_unlock/ui/app_unlock_router.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/onboarding/ui/screens/onboarding_splash.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:url_launcher/url_launcher.dart';

class AppStartupWidget extends StatefulWidget {
  const AppStartupWidget({super.key, required this.app});

  final Widget app;

  @override
  State<AppStartupWidget> createState() => _AppStartupWidgetState();
}

class _AppStartupWidgetState extends State<AppStartupWidget> {
  @override
  Widget build(BuildContext context) {
    return AppStartupListener(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: BlocBuilder<AppStartupBloc, AppStartupState>(
          builder: (context, state) {
            if (state is AppStartupInitial) {
              return const OnboardingSplash(loading: true);
            } else if (state is AppStartupLoadingInProgress) {
              return const OnboardingSplash(loading: true);
              // show status of migration
            } else if (state is AppStartupSuccess) {
              // if (!state.hasDefaultWallets) return const OnboardingScreen();
              // if (state.isPinCodeSet) return const PinCodeUnlockScreen();
              // return const HomeScreen();
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
  const AppStartupListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AppStartupBloc, AppStartupState>(
          listenWhen: (previous, current) =>
              current is AppStartupSuccess && previous != current,
          listener: (context, state) {
            if (state is AppStartupSuccess && state.isPinCodeSet) {
              AppRouter.router.go(AppUnlockRoute.appUnlock.path);
            }

            if (state is AppStartupSuccess && !state.hasDefaultWallets) {
              AppRouter.router.go(OnboardingRoute.onboarding.path);
            }
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
      return _RestoreDefaultSecret(
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
                  borderRadius: BorderRadius.circular(2.0),
                ),
                tileColor: context.appColors.error.withValues(alpha: 0.1),
                title: Row(
                  children: [
                    Icon(Icons.error_outline, color: context.appColors.error),
                    const Gap(8),
                    Text(
                      context.loc.appStartupErrorTitle,
                      style: context.font.headlineLarge?.copyWith(
                        color: context.appColors.error,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    failure.toTranslated(context),
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.secondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              // The seed is gone but the wallets are not: the user's own
              // backup brings it back, checked against the missing wallet.
              if (failure is AppStartupMissingDefaultSecretFailure) ...[
                const SizedBox(height: 24),
                BBButton.big(
                  onPressed: () => setState(() => _restoring = true),
                  label: context.loc.appStartupRestoreSecretButton,
                  bgColor: context.appColors.secondary,
                  textColor: context.appColors.onSecondary,
                ),
              ],
              const SizedBox(height: 24),
              Text(
                context.loc.appStartupContactSupportMessage,
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.secondary.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              BBButton.big(
                onPressed: () {
                  final url = Uri.parse(SettingsConstants.webSupportLink);
                  // ignore: deprecated_member_use
                  launchUrl(url, mode: LaunchMode.externalApplication);
                },
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

/// Entry of the recovery phrase of a default wallet whose secret is missing.
///
/// The words go straight to the bloc, which checks them against the missing
/// wallet before storing them; a refusal is shown under the entry.
class _RestoreDefaultSecret extends StatefulWidget {
  const _RestoreDefaultSecret({required this.onCancel});

  final VoidCallback onCancel;

  @override
  State<_RestoreDefaultSecret> createState() => _RestoreDefaultSecretState();
}

class _RestoreDefaultSecretState extends State<_RestoreDefaultSecret>
    with PrivacyScreen {
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Best-effort, like every screen where words are typed: refusing entry
    // over a platform hiccup would block the only way back.
    unawaited(enableScreenPrivacy());
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  Future<void> _submit(List<String> words) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await context.read<AppStartupBloc>().restoreDefaultSecret(
      words,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result case Err(:final failure)) {
        _error = failure.toTranslated(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onCancel),
        title: Text(context.loc.appStartupRestoreSecretButton),
      ),
      body: SafeArea(
        child: IgnorePointer(
          ignoring: _busy,
          child: Opacity(
            opacity: _busy ? 0.5 : 1.0,
            child: MnemonicWidget(
              initialLength: bip39.MnemonicLength.words12,
              allowMultipleMnemonicLength: true,
              allowLabel: false,
              // Default wallets never have a passphrase.
              allowPassphrase: false,
              externalError: _error,
              submitLabel: context.loc.onboardingRecover,
              onSubmit: (mnemonic) => unawaited(_submit(mnemonic.words)),
            ),
          ),
        ),
      ),
    );
  }
}
