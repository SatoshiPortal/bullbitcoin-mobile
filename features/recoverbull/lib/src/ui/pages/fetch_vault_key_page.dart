import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:screen_awake/screen_awake.dart';
import 'package:screen_privacy/screen_privacy.dart';
import 'package:secrets/secrets.dart' show VaultKey;

import '../../domain/entities/backup_settings.dart';
import '../../domain/entities/recoverbull_flow.dart';
import '../../domain/entities/vault_completion.dart';
import '../../domain/entities/vault_recovery.dart';
import '../../domain/recoverbull_failure.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/recoverbull_failure_l10n.dart';
import '../../presentation/vault_flow_cubit.dart';
import '../recoverbull_flow_navigator.dart';
import '../screens/view_vault_key_page.dart';
import '../widgets/recoverbull_widgets.dart';
import 'password_input_page.dart';
import 'vault_completed_pages.dart';

/// Recovery network, or null when the flow does not restore wallets.
Result<BitcoinNetwork?, RecoverBullFailure> _network(BuildContext context) {
  final scope = RecoverBullFlowScope.of(context);
  if (scope.flow != RecoverBullFlow.recoverVault) return const Ok(null);
  return switch (scope.presentation.network) {
    Ok(:final value) => Ok(value),
    Err(:final failure) => Err(failure),
  };
}

/// Shows where a finished verification or recovery leads.
Future<void> _showCompletion(BuildContext context, VaultCompletion completion) {
  final scope = RecoverBullFlowScope.of(context);
  if (completion.recovery is VaultRecovered &&
      completion.warning == null &&
      scope.onRecovered != null) {
    scope.onRecovered?.call();
    return Future.value();
  }
  return Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => VaultVerifiedPage(completion: completion),
    ),
  );
}

void _showFailure(BuildContext context, RecoverBullFailure failure) {
  BullSnackBar.show(context, message: failure.toTranslated(context));
  context.read<VaultFlowCubit>().clearFailure();
  // Only the user can fix their own proxy, in Tor settings.
  if (failure is ExternalTorProxyUnavailableFailure) {
    RecoverBullFlowScope.of(context).onOpenTorSettings?.call();
  }
}

/// What a vault-key fetch ended with; the progress page navigates from it.
sealed class VaultKeyOutcome {
  const VaultKeyOutcome();
}

final class _Failed extends VaultKeyOutcome {
  final RecoverBullFailure failure;
  const _Failed(this.failure);
}

final class _InvalidKey extends VaultKeyOutcome {
  const _InvalidKey();
}

final class _Revealed extends VaultKeyOutcome {
  final VaultKey key;
  const _Revealed(this.key);
}

final class _NeedsPassphrase extends VaultKeyOutcome {
  final VaultKey key;
  final BackupSettings? settings;
  final BitcoinNetwork? network;
  const _NeedsPassphrase(this.key, this.settings, this.network);
}

final class _Completed extends VaultKeyOutcome {
  final VaultCompletion completion;
  const _Completed(this.completion);
}

final class _Nothing extends VaultKeyOutcome {
  const _Nothing();
}

/// Starts the fetch as soon as the secret is submitted, then tests, restores
/// or reveals; the entered secret is not retained once the call is made.
Future<VaultKeyOutcome> startVaultKeyFetch(
  BuildContext context, {
  required String input,
  required InputType inputType,
}) async {
  final cubit = context.read<VaultFlowCubit>();
  final flow = RecoverBullFlowScope.of(context).flow;
  final BitcoinNetwork? network;
  switch (_network(context)) {
    case Err(:final failure):
      return _Failed(failure);
    case Ok(:final value):
      network = value;
  }

  VaultKey? key;
  BackupSettings? settings;
  if (inputType == InputType.vaultKey) {
    try {
      key = VaultKey(input);
    } on FormatException {
      return const _InvalidKey();
    }
    await cubit.manual(key, network);
  } else if (flow == RecoverBullFlow.viewVaultKey) {
    final revealed = await cubit.reveal(input);
    if (revealed != null) return _Revealed(revealed);
  } else {
    final recovered = await cubit.verificationKey(input);
    if (recovered != null) {
      key = recovered.key;
      settings = recovered.settings;
      await cubit.manual(key, network, capturedSettings: settings);
    }
  }

  final state = cubit.state;
  if (state.failure is VaultPassphraseRequiredFailure && key != null) {
    cubit.clearFailure();
    return _NeedsPassphrase(key, settings, network);
  }
  if (state.failure case final failure?) return _Failed(failure);
  if (state.completion case final completion?) return _Completed(completion);
  return const _Nothing();
}

/// Shows progress while the vault key is fetched, then leads to the outcome.
class FetchVaultKeyPage extends StatefulWidget {
  final Future<VaultKeyOutcome> outcome;

  const FetchVaultKeyPage({super.key, required this.outcome});

  @override
  State<FetchVaultKeyPage> createState() => _FetchVaultKeyPageState();
}

class _FetchVaultKeyPageState extends State<FetchVaultKeyPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.outcome.then(_show));
  }

  Future<void> _show(VaultKeyOutcome outcome) async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    switch (outcome) {
      case _Failed(:final failure):
        _showFailure(context, failure);
        navigator.pop();
      case _InvalidKey():
        BullSnackBar.show(
          context,
          message: context.loc.recoverbullErrorInvalidCredentials,
        );
        navigator.pop();
      case _Revealed(:final key):
        await navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ViewVaultKeyPage(
              vaultKey: key,
              copiedMessage: RecoverBullFlowScope.of(context).copiedMessage,
            ),
          ),
        );
      case _NeedsPassphrase(:final key, :final settings, :final network):
        await navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PassphrasePage(
              vaultKey: key,
              settings: settings,
              network: network,
            ),
          ),
        );
      case _Completed(:final completion):
        await _showCompletion(context, completion);
      case _Nothing():
        navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RecoverBullAppBar(title: context.loc.recoverbullFetchVaultKey),
      body: ScreenAwakeScope(
        enabled: true,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: RecoverBullProgress(
                title: context.loc.recoverbullFetchingVaultKey,
                description: context.loc.recoverbullConnectingTor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for the BIP39 passphrase the vault does not contain.
class PassphrasePage extends StatefulWidget {
  final VaultKey vaultKey;
  final BackupSettings? settings;
  final BitcoinNetwork? network;

  const PassphrasePage({
    super.key,
    required this.vaultKey,
    required this.settings,
    required this.network,
  });

  @override
  State<PassphrasePage> createState() => _PassphrasePageState();
}

class _PassphrasePageState extends State<PassphrasePage> with PrivacyScreen {
  late Future<bool> _protection;
  String _passphrase = '';
  int _attempt = 0;
  String? _error;
  bool _confirmWithout = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _protection = enableScreenPrivacy();
    // Leaving the app drops the fetched key and the typed passphrase: the user
    // starts again from the password rather than finding them on return.
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.paused &&
            state != AppLifecycleState.hidden) {
          return;
        }
        if (!mounted || context.read<VaultFlowCubit>().state.busy) return;
        setState(() => _passphrase = '');
        if (ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  void _retryPrivacy() {
    final protection = enableScreenPrivacy();
    setState(() {
      _protection = protection;
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _passphrase = '';
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  Future<void> _submit({bool without = false}) async {
    final cubit = context.read<VaultFlowCubit>();
    if (cubit.state.busy) return;
    final candidate = without ? '' : _passphrase;
    setState(() {
      _passphrase = '';
      _attempt++;
      _error = null;
      _confirmWithout = false;
    });
    await cubit.manual(
      widget.vaultKey,
      widget.network,
      passphrase: candidate,
      allowUnverified: without,
      capturedSettings: widget.settings,
    );
    if (!mounted) return;
    final state = cubit.state;
    if (state.failure is VaultPassphraseRequiredFailure) {
      cubit.clearFailure();
      setState(() => _error = context.loc.recoverbullPassphraseMismatch);
      return;
    }
    // Any other failure invalidates this key: start again from the password.
    if (state.failure case final failure?) {
      _showFailure(context, failure);
      Navigator.of(context).pop();
      return;
    }
    if (state.completion case final completion?) {
      await _showCompletion(context, completion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recovering =
        RecoverBullFlowScope.of(context).flow == RecoverBullFlow.recoverVault;
    return Scaffold(
      appBar: RecoverBullAppBar(
        title: context.loc.recoverbullPassphraseRequired,
      ),
      body: BullScreenPrivacyGate(
        protection: _protection,
        unavailableMessage: context.loc.recoverbullUnexpectedError,
        retryLabel: context.loc.recoverbullRetry,
        onRetry: () => _retryPrivacy(),
        builder: (context) => BlocBuilder<VaultFlowCubit, VaultFlowState>(
          builder: (context, state) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                BullText(
                  context.loc.recoverbullPassphraseNotVaultPassword,
                  textAlign: .center,
                  style: context.bullType.caption.copyWith(
                    color: context.bull.textMuted,
                  ),
                  maxLines: 4,
                ),
                const Gap(16),
                BullSecretTextInput(
                  key: ValueKey(_attempt),
                  label: context.loc.recoverbullPassphraseRequired,
                  onChanged: (value) => setState(() => _passphrase = value),
                  showLabel: context.loc.recoverbullPassphraseShow,
                  hideLabel: context.loc.recoverbullPassphraseHide,
                ),
                if (_passphrase.trim() != _passphrase) ...[
                  const Gap(8),
                  BullText(
                    context.loc.recoverbullPassphraseWhitespace,
                    style: context.bullType.label
                        .copyWith(fontWeight: FontWeight.w400)
                        .copyWith(color: context.bull.warning),
                    maxLines: 3,
                  ),
                ],
                if (_error case final error?) ...[
                  const Gap(8),
                  Semantics(
                    liveRegion: true,
                    child: BullText(
                      error,
                      style: context.bullType.label
                          .copyWith(fontWeight: FontWeight.w400)
                          .copyWith(color: context.bull.error),
                      maxLines: 4,
                    ),
                  ),
                ],
                const Gap(24),
                if (state.busy)
                  RecoverBullProgress(title: context.loc.recoverbullPleaseWait)
                else ...[
                  if (recovering && _confirmWithout)
                    BullButton.secondary(
                      label: context.loc.recoverbullPassphraseVerify,
                      onPressed: _submit,
                    )
                  else
                    BullButton.primary(
                      label: context.loc.recoverbullPassphraseVerify,
                      onPressed: _submit,
                    ),
                  if (recovering) ...[
                    const Gap(12),
                    if (!_confirmWithout)
                      BullButton.secondary(
                        label: context.loc.recoverbullContinueWithoutPassphrase,
                        onPressed: () => setState(() => _confirmWithout = true),
                      )
                    else ...[
                      BullInfoCard(
                        description: context
                            .loc
                            .recoverbullContinueWithoutPassphraseWarning,
                        tagColor: context.bull.warning,
                        bgColor: context.bull.warningContainer,
                      ),
                      const Gap(12),
                      Row(
                        children: [
                          Expanded(
                            child: BullButton.secondary(
                              label: context.loc.recoverbullSettingsCancel,
                              onPressed: () =>
                                  setState(() => _confirmWithout = false),
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: BullButton.primary(
                              label: context.loc.recoverbullConfirm,
                              onPressed: () => _submit(without: true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
                const Gap(24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
