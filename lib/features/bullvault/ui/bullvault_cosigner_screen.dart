import 'dart:async';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/privacy_unavailable_notice.dart';
import 'package:bb_mobile/features/app_unlock/public/app_unlock_facade.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_cosigner_cubit.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullInputText, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_privacy/screen_privacy.dart';

class BullVaultCosignerScreen extends StatefulWidget {
  final String walletId;
  final AppUnlockFacade appUnlock;
  const BullVaultCosignerScreen({
    super.key,
    required this.walletId,
    this.appUnlock = const AppUnlockFacade(),
  });
  @override
  State<BullVaultCosignerScreen> createState() =>
      _BullVaultCosignerScreenState();
}

class _BullVaultCosignerScreenState extends State<BullVaultCosignerScreen>
    with PrivacyScreen, WidgetsBindingObserver {
  late final Future<void> _privacy = _protect();
  bool _consented = false;
  bool _authenticated = false;
  bool _active = true;
  String _words = '';
  String _passphrase = '';

  Future<void> _protect() async {
    if (!ScreenCaptureProtection.instance.enabledByUser) {
      throw const ScreenCaptureProtectionException();
    }
    await enableScreenPrivacy();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _confirm());
  }

  Future<void> _confirm() async {
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.loc.bullVaultCosignerWarningTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.loc.bullVaultCosignerWarning),
              const Gap(16),
              Text(context.loc.bullVaultCosignerWarningClarification),
              const Gap(16),
              Text(context.loc.bullVaultCosignerStored),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.loc.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.loc.bullVaultCosignerContinue),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (accepted != true) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _consented = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _active = state == AppLifecycleState.resumed;
      if (!_active) {
        _words = '';
        _passphrase = '';
      }
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {
        _authenticated = false;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _words = '';
    _passphrase = '';
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_consented) return Scaffold(appBar: AppBar());
    return PrivacyGate(
      protection: _privacy,
      unprotected: const PrivacyUnavailableNotice(),
      builder: (context) {
        if (!_authenticated) {
          return widget.appUnlock.buildReauthenticationGate(
            canPop: true,
            onSuccess: (_) => setState(() => _authenticated = true),
          );
        }
        return BlocConsumer<BullVaultCosignerCubit, BullVaultCosignerState>(
          listener: (context, state) {
            if (state.imported) Navigator.of(context).pop(true);
          },
          builder: (context, state) => PopScope(
            canPop: !state.busy,
            child: Scaffold(
              appBar: AppBar(title: Text(context.loc.bullVaultImportCosigner)),
              body: SafeArea(
                child: !_active
                    ? const SizedBox.shrink()
                    : state.imported
                    ? Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(context.loc.continueButton),
                        ),
                      )
                    : ExcludeSemantics(
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Text(context.loc.bullVaultCosignerStored),
                            const Gap(24),
                            BullInputText(
                              label: context.loc.bip85Mnemonic,
                              value: _words,
                              onChanged: (value) =>
                                  setState(() => _words = value),
                              maxLines: 4,
                              maxLength: 2048,
                              disabled: state.busy,
                              enableSuggestions: false,
                              autocorrect: false,
                            ),
                            const Gap(16),
                            Text(context.loc.passphraseLabel),
                            BullInputText(
                              value: _passphrase,
                              onChanged: (value) =>
                                  setState(() => _passphrase = value),
                              maxLines: 1,
                              maxLength: 1024,
                              obscure: true,
                              disabled: state.busy,
                              enableSuggestions: false,
                              autocorrect: false,
                            ),
                            if (state.failure != null) ...[
                              const Gap(16),
                              Text(
                                state.failure is BullVaultInvalidSignerFailure
                                    ? context.loc.bullVaultCosignerMismatch
                                    : context.loc.oopsSomethingWentWrong,
                              ),
                            ],
                            const Gap(24),
                            BullButton.big(
                              label: context.loc.bullVaultImportCosigner,
                              bgColor: context.appColors.primary,
                              textColor: context.appColors.onPrimary,
                              disabled: state.busy || _words.trim().isEmpty,
                              loading: state.busy,
                              onPressed: () {
                                final words = _words, passphrase = _passphrase;
                                setState(() {
                                  _words = '';
                                  _passphrase = '';
                                });
                                context.read<BullVaultCosignerCubit>().import(
                                  walletId: widget.walletId,
                                  words: words,
                                  passphrase: passphrase,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
