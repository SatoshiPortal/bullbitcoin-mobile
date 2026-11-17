import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:screen_privacy/screen_privacy.dart';

import '../../domain/common_passwords.dart';
import '../../domain/entities/recoverbull_flow.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/vault_flow_cubit.dart';
import '../recoverbull_flow_navigator.dart';
import '../widgets/recoverbull_widgets.dart';
import 'fetch_vault_key_page.dart';
import 'vault_provider_selection_page.dart';

enum InputType { pin, password, vaultKey }

const _minPasswordLength = 6;

String? _validatePassword(BuildContext context, String? value) {
  if (value == null || value.isEmpty) {
    return context.loc.recoverbullPasswordRequired;
  }
  if (value.length < _minPasswordLength) {
    return context.loc.recoverbullPasswordTooShort;
  }
  if (commonPasswordsTop1000.contains(value)) {
    return context.loc.recoverbullPasswordTooCommon;
  }
  return null;
}

/// PIN, password or vault-key entry; a new backup asks for it twice.
class PasswordInputPage extends StatefulWidget {
  /// The user skipped the key server: only the vault key can open the vault.
  final bool vaultKeyOnly;

  const PasswordInputPage({super.key, this.vaultKeyOnly = false});

  @override
  State<PasswordInputPage> createState() => _PasswordInputPageState();
}

class _PasswordInputPageState extends State<PasswordInputPage>
    with PrivacyScreen {
  bool _isObscured = false;
  late InputType _inputType = widget.vaultKeyOnly
      ? InputType.vaultKey
      : InputType.pin;
  String _validatedPassword = '';
  bool _passphraseAccepted = false;
  final _inputController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Future<bool> _protection = Completer<bool>().future;
  bool _visible = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Leaving the app forgets what was typed: a secret never outlives the screen it was entered on.
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.resumed) {
          if (_visible) _retryPrivacy();
        } else if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) {
          _inputController.clear();
          if (mounted) setState(() => _validatedPassword = '');
        }
      },
    );
  }

  /// Capture is blocked only while this page is on top: the screens pushed
  /// over it hold no secret and stay capturable.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      _protection = enableScreenPrivacy();
    } else {
      _protection = Completer<bool>().future;
      unawaited(disableScreenPrivacy());
    }
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
    _inputController.clear();
    _validatedPassword = '';
    _inputController.dispose();
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  String _inputTypeString(BuildContext context, InputType type) =>
      switch (type) {
        InputType.pin => context.loc.recoverbullPIN,
        InputType.password => context.loc.recoverbullPassword,
        InputType.vaultKey => context.loc.recoverbullVaultKeyInput,
      };

  void _switchTo(InputType type) {
    setState(() {
      _inputType = type;
      _inputController.clear();
      _validatedPassword = '';
    });
  }

  Future<void> _continue(RecoverBullFlow flow, bool needsPassphraseAck) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (flow == RecoverBullFlow.secureVault) {
      if (_validatedPassword.isEmpty) {
        setState(() {
          _validatedPassword = _inputController.text;
          _inputController.clear();
          _isObscured = false;
        });
        return;
      }
      if (needsPassphraseAck && !_passphraseAccepted) return;
      final password = _validatedPassword;
      _inputController.clear();
      setState(() => _validatedPassword = '');
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VaultProviderSelectionPage(
            password: SealingPassword(password),
            passphraseWarningAccepted: _passphraseAccepted,
          ),
        ),
      );
      return;
    }
    final outcome = startVaultKeyFetch(
      context,
      input: _inputController.text,
      inputType: _inputType,
    );
    _inputController.clear();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FetchVaultKeyPage(outcome: outcome),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = RecoverBullFlowScope.of(context);
    final flow = scope.flow;
    final confirming =
        flow == RecoverBullFlow.secureVault && _validatedPassword.isNotEmpty;
    final needsPassphraseAck =
        flow == RecoverBullFlow.secureVault &&
        scope.presentation.defaultHasPassphrase;
    final hasVaultKeyInput = [
      RecoverBullFlow.testVault,
      RecoverBullFlow.recoverVault,
    ].contains(flow);
    final inputTypeString = _inputTypeString(context, _inputType);

    final title = switch (flow) {
      RecoverBullFlow.secureVault => context.loc.recoverbullSecureBackup,
      _ => context.loc.recoverbullEnterInput(inputTypeString),
    };
    final description = switch (flow) {
      RecoverBullFlow.secureVault =>
        confirming
            ? context.loc.recoverbullReenterConfirm(inputTypeString)
            : context.loc.recoverbullMemorizeWarning(inputTypeString),
      RecoverBullFlow.recoverVault => context.loc.recoverbullEnterToDecrypt(
        inputTypeString,
      ),
      RecoverBullFlow.testVault => context.loc.recoverbullEnterToTest(
        inputTypeString,
      ),
      RecoverBullFlow.viewVaultKey || RecoverBullFlow.settings =>
        context.loc.recoverbullEnterToView(inputTypeString),
    };
    final borderDecoration = OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.bullShapes.input),
      borderSide: BorderSide(color: context.bull.border),
    );

    return Scaffold(
      appBar: RecoverBullAppBar(title: title),
      body: BlocBuilder<VaultFlowCubit, VaultFlowState>(
        // A sealed backup waiting for its save keeps the password it was sealed
        // with: resume it or discard it before choosing another one.
        builder: (context, state) =>
            flow == RecoverBullFlow.secureVault && state.hasPendingProviderSave
            ? _PendingBackup(busy: state.busy)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: .stretch,
                            children: [
                              SizedBox(
                                height: 50,
                                child: Center(
                                  child: BullText(
                                    description,
                                    textAlign: .center,
                                    style: context.bullType.caption.copyWith(
                                      color: context.bull.textMuted,
                                    ),
                                    maxLines: 3,
                                  ),
                                ),
                              ),
                              const Gap(12),
                              BullText(
                                confirming
                                    ? context.loc.recoverbullConfirmInput(
                                        inputTypeString,
                                      )
                                    : inputTypeString,
                                textAlign: .start,
                                style: context.bullType.caption.copyWith(
                                  color: context.bull.textMuted,
                                ),
                              ),
                              const Gap(2),
                              _gated(
                                context,
                                (_) => ExcludeSemantics(
                                  child: TextFormField(
                                    controller: _inputController,
                                    obscureText: _isObscured,
                                    readOnly: _inputType == InputType.pin,
                                    enableSuggestions: false,
                                    autocorrect: false,
                                    smartQuotesType: SmartQuotesType.disabled,
                                    smartDashesType: SmartDashesType.disabled,
                                    textAlignVertical: TextAlignVertical.center,
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    style: context.bullType.subtitle
                                        .copyWith(fontWeight: FontWeight.w400)
                                        .copyWith(
                                          color: context.bull.onSurface,
                                        ),
                                    validator: (value) {
                                      if (_inputType == InputType.vaultKey) {
                                        return value == null || value.isEmpty
                                            ? context
                                                  .loc
                                                  .recoverbullPasswordRequired
                                            : null;
                                      }
                                      if (flow != RecoverBullFlow.secureVault) {
                                        return value == null || value.isEmpty
                                            ? context
                                                  .loc
                                                  .recoverbullPasswordRequired
                                            : null;
                                      }
                                      if (confirming) {
                                        if (value == null || value.isEmpty) {
                                          return context.loc
                                              .recoverbullReenterRequired(
                                                inputTypeString,
                                              );
                                        }
                                        final error = _validatePassword(
                                          context,
                                          value,
                                        );
                                        if (error != null) return error;
                                        return value == _validatedPassword
                                            ? null
                                            : context
                                                  .loc
                                                  .recoverbullPasswordMismatch;
                                      }
                                      return _validatePassword(context, value);
                                    },
                                    decoration: InputDecoration(
                                      suffixIcon: IconButton(
                                        padding: const EdgeInsets.all(5),
                                        icon: _isObscured
                                            ? const Icon(
                                                Icons.visibility_outlined,
                                              )
                                            : const Icon(
                                                Icons.visibility_off_outlined,
                                              ),
                                        onPressed: () => setState(
                                          () => _isObscured = !_isObscured,
                                        ),
                                      ),
                                      border: borderDecoration,
                                      enabledBorder: borderDecoration,
                                      focusedBorder: borderDecoration,
                                      disabledBorder: borderDecoration,
                                      contentPadding: const EdgeInsets.all(16),
                                      errorMaxLines: 4,
                                    ),
                                  ),
                                ),
                                unavailable: true,
                              ),
                              const Gap(16),
                              if (confirming)
                                BullButton.small(
                                  label: context.loc.recoverbullGoBackEdit,
                                  bgColor: context.bull.transparent,
                                  textColor: context.bull.info,
                                  textStyle: context.bullType.caption,
                                  onPressed: () => setState(() {
                                    _validatedPassword = '';
                                    _inputController.clear();
                                  }),
                                )
                              else if (!widget.vaultKeyOnly)
                                Row(
                                  children: [
                                    Expanded(
                                      child: BullButton.big(
                                        label: _inputType == InputType.pin
                                            ? context
                                                  .loc
                                                  .recoverbullSwitchToPassword
                                            : context
                                                  .loc
                                                  .recoverbullSwitchToPIN,
                                        bgColor: context.bull.transparent,
                                        textColor: context.bull.info,
                                        textStyle: context.bullType.caption,
                                        onPressed: () => _switchTo(
                                          _inputType == InputType.pin
                                              ? InputType.password
                                              : InputType.pin,
                                        ),
                                      ),
                                    ),
                                    if (_inputType != InputType.vaultKey &&
                                        hasVaultKeyInput)
                                      Expanded(
                                        child: BullButton.small(
                                          label: context
                                              .loc
                                              .recoverbullEnterVaultKeyInstead,
                                          bgColor: context.bull.transparent,
                                          textColor: context.bull.info,
                                          textStyle: context.bullType.caption,
                                          onPressed: () =>
                                              _switchTo(InputType.vaultKey),
                                        ),
                                      ),
                                  ],
                                ),
                              if (needsPassphraseAck) ...[
                                const Gap(8),
                                BullText(
                                  context
                                      .loc
                                      .recoverbullVaultPassphraseNotIncluded,
                                  style: context.bullType.label.copyWith(
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 4,
                                ),
                                Row(
                                  children: [
                                    BullCheckbox(
                                      checked: _passphraseAccepted,
                                      onChanged: (value) => setState(
                                        () => _passphraseAccepted = value,
                                      ),
                                    ),
                                    Expanded(
                                      child: BullText(
                                        context
                                            .loc
                                            .recoverbullPassphraseAcknowledgement,
                                        style: context.bullType.label.copyWith(
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 4,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (_inputType == InputType.pin)
                        _gated(
                          context,
                          (_) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: BullPinPad(
                              scrambleHint:
                                  context.loc.recoverbullScrambleKeypadHint,
                              onDigit: (digit) =>
                                  _inputController.text += '$digit',
                              onBackspace: () {
                                final text = _inputController.text;
                                if (text.isNotEmpty) {
                                  _inputController.text = text.substring(
                                    0,
                                    text.length - 1,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      if (_inputType == InputType.pin) const Gap(12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 60),
                        child: BullButton.big(
                          label: confirming
                              ? context.loc.recoverbullConfirm
                              : context.loc.recoverbullContinue,
                          textStyle: context.bullType.subtitle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          bgColor: context.bull.onSurface,
                          textColor: context.bull.surface,
                          disabled:
                              state.busy ||
                              (confirming &&
                                  needsPassphraseAck &&
                                  !_passphraseAccepted),
                          onPressed: () => _continue(flow, needsPassphraseAck),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// Draws a secret input only once screen capture is blocked; the other
  /// controls stay usable meanwhile.
  Widget _gated(
    BuildContext context,
    WidgetBuilder builder, {
    bool unavailable = false,
  }) => BullScreenPrivacyGate(
    protection: _protection,
    unavailableMessage: context.loc.recoverbullUnexpectedError,
    retryLabel: context.loc.recoverbullRetry,
    onRetry: () => _retryPrivacy(),
    builder: builder,
    unavailableBuilder: (context) => unavailable
        ? Column(
            mainAxisSize: .min,
            children: [
              BullText(
                context.loc.recoverbullUnexpectedError,
                style: context.bullType.body.copyWith(
                  color: context.bull.error,
                ),
                textAlign: .center,
              ),
              BullButton.small(
                label: context.loc.recoverbullRetry,
                onPressed: () => _retryPrivacy(),
                bgColor: context.bull.secondary,
                textColor: context.bull.onSecondary,
              ),
            ],
          )
        : const SizedBox.shrink(),
  );
}

class _PendingBackup extends StatelessWidget {
  final bool busy;

  const _PendingBackup({required this.busy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          BullText(
            context.loc.recoverbullPendingProviderSave,
            style: context.bullType.body,
            maxLines: 6,
          ),
          const Gap(24),
          BullButton.big(
            label: context.loc.recoverbullRetryProviderSave,
            bgColor: context.bull.onSurface,
            textColor: context.bull.surface,
            disabled: busy,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const VaultProviderSelectionPage(),
              ),
            ),
          ),
          const Gap(12),
          BullButton.big(
            label: context.loc.recoverbullDiscardPendingBackup,
            bgColor: context.bull.surface,
            textColor: context.bull.onSurface,
            outlined: true,
            borderColor: context.bull.onSurface,
            disabled: busy,
            onPressed: () =>
                context.read<VaultFlowCubit>().abandonPendingProviderSave(),
          ),
        ],
      ),
    );
  }
}
