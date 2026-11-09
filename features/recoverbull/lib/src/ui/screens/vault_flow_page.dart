import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:screen_privacy/screen_privacy.dart';
import 'package:secrets/secrets.dart' show VaultKey;

import '../../domain/entities/drive_file_metadata.dart';
import '../../domain/common_passwords.dart';
import '../../domain/entities/recoverbull_flow.dart';
import '../../domain/entities/vault_provider.dart';
import '../../domain/entities/vault_recovery.dart';
import '../../domain/usecases/manage_backup_settings_usecase.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/recoverbull_failure_l10n.dart';
import '../../presentation/vault_flow_cubit.dart';
import '../../presentation/vault_flow_presentation.dart';
import '../widgets/backup_monitoring_panel.dart';
import 'view_vault_key_page.dart';

class VaultFlowPage extends StatefulWidget {
  final RecoverBullFlow flow;
  final Future<VaultFlowPresentation> Function() presentation;
  final VoidCallback? onRecovered;
  final String copiedMessage;

  const VaultFlowPage({
    super.key,
    required this.flow,
    required this.presentation,
    required this.copiedMessage,
    this.onRecovered,
  });

  @override
  State<VaultFlowPage> createState() => _VaultFlowPageState();
}

class _VaultFlowPageState extends State<VaultFlowPage> with PrivacyScreen {
  VaultFlowPresentation? _presentation;
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _server = TextEditingController();
  VaultProvider _provider = VaultProvider.customLocation;
  DriveFileMetadata? _deleting;
  bool _manual = false;
  bool _keyWarningAccepted = false;
  bool? _protected;
  int _privacyGeneration = 0;
  String? _inputError;
  VaultKey? _key;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.resumed) {
          unawaited(_acquirePrivacy());
        } else {
          _privacyGeneration++;
          _password.clear();
          _confirmation.clear();
          if (mounted) {
            setState(() {
              _protected = null;
              _key = null;
            });
          }
        }
      },
    );
    unawaited(_acquirePrivacy());
    unawaited(_load());
  }

  Future<void> _load() async {
    final presentation = await widget.presentation();
    if (!mounted) {
      await presentation.close();
      return;
    }
    setState(() => _presentation = presentation);
    await presentation.cubit.settings();
    if (mounted) {
      _server.text = presentation.cubit.state.settings?.server.toString() ?? '';
    }
  }

  Future<void> _acquirePrivacy() async {
    final generation = ++_privacyGeneration;
    final protected = await enableScreenPrivacy();
    if (mounted && generation == _privacyGeneration) {
      setState(() => _protected = protected);
    }
  }

  @override
  void dispose() {
    _privacyGeneration++;
    _lifecycle.dispose();
    _password.clear();
    _confirmation.clear();
    _key = null;
    _password.dispose();
    _confirmation.dispose();
    _server.dispose();
    unawaited(_presentation?.close() ?? Future.value());
    disableScreenPrivacy();
    super.dispose();
  }

  Widget _text(String value) =>
      BullText(value, style: context.bullText.bodyLarge);
  Widget _button(String label, VoidCallback action, {bool disabled = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: BullSpacing.sm),
        child: BullButton.small(
          label: label,
          onPressed: action,
          disabled: disabled,
          bgColor: context.bull.primary,
          textColor: context.bull.onPrimary,
        ),
      );

  Future<void> _submit(VaultFlowPresentation presentation) async {
    final cubit = presentation.cubit;
    if (_protected != true || cubit.state.busy) return;
    final input = _password.text;
    final privacyGeneration = _privacyGeneration;
    if (input.isEmpty) {
      setState(() => _inputError = context.loc.recoverbullPasswordRequired);
      return;
    }
    if (widget.flow == RecoverBullFlow.secureVault) {
      if (input.length < 6) {
        setState(() => _inputError = context.loc.recoverbullPasswordTooShort);
        return;
      }
      if (commonPasswordsTop1000.contains(input)) {
        setState(() => _inputError = context.loc.recoverbullPasswordTooCommon);
        return;
      }
      if (input != _confirmation.text) {
        setState(() => _inputError = context.loc.recoverbullPasswordMismatch);
        return;
      }
    }
    final BitcoinNetwork? network;
    if (widget.flow == RecoverBullFlow.recoverVault) {
      switch (presentation.network) {
        case Err(:final failure):
          setState(() => _inputError = failure.toTranslated(context));
          return;
        case Ok(:final value):
          network = value;
      }
    } else {
      network = null;
    }
    VaultKey? manualKey;
    if (_manual) {
      try {
        manualKey = VaultKey(input);
      } on ArgumentError {
        setState(
          () => _inputError = context.loc.recoverbullErrorInvalidCredentials,
        );
        return;
      }
    }
    setState(() => _inputError = null);
    _password.clear();
    _confirmation.clear();
    if (manualKey != null) {
      await cubit.manual(manualKey, network);
    } else if (widget.flow == RecoverBullFlow.secureVault) {
      await cubit.create(_provider, input);
    } else if (widget.flow == RecoverBullFlow.viewVaultKey) {
      final key = await cubit.reveal(input);
      if (mounted &&
          _protected == true &&
          privacyGeneration == _privacyGeneration) {
        setState(() => _key = key);
      }
    } else {
      await cubit.verify(input, network);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = _key;
    if (key != null) {
      return ViewVaultKeyPage(
        vaultKey: key,
        copiedMessage: widget.copiedMessage,
      );
    }
    final presentation = _presentation;
    return BullScaffold(
      body: SafeArea(
        child: Column(
          children: [
            BullTopBar(
              title: widget.flow == RecoverBullFlow.settings
                  ? context.loc.recoverbullSettingsTitle
                  : context.loc.recoverbullSecureBackup,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(BullSpacing.lg),
                child: presentation == null
                    ? _text(context.loc.recoverbullPleaseWait)
                    : BlocBuilder<VaultFlowCubit, VaultFlowState>(
                        bloc: presentation.cubit,
                        builder: (context, state) => _body(presentation, state),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(VaultFlowPresentation presentation, VaultFlowState state) {
    final cubit = presentation.cubit;
    final settings = state.settings;
    final completion = state.completion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (presentation.monitoring case final monitoring?)
          BackupMonitoringPanel(cubit: monitoring),
        if (state.failure case final failure?)
          _text(failure.toTranslated(context)),
        if (state.busy) _text(context.loc.recoverbullPleaseWait),
        if (completion != null) ...[
          _text(switch (completion.recovery) {
            VaultRecoveryNeedsWallets() =>
              context.loc.recoverbullVaultImportedSuccess,
            VaultRecovered() => context.loc.recoverbullVaultImportedSuccess,
            null =>
              completion.verifiedContext != null
                  ? context.loc.recoverbullTestCompletedTitle
                  : context.loc.recoverbullVaultCreatedSuccess,
          }),
          if (completion.recovery case VaultRecoveryNeedsWallets(
            :final failure,
          ))
            _text(failure.toTranslated(context)),
          if (completion.warning case final warning?)
            _text(warning.toTranslated(context)),
          _button(context.loc.recoverbullContinue, () {
            if (completion.recovery is VaultRecovered &&
                widget.onRecovered != null) {
              widget.onRecovered?.call();
            } else {
              Navigator.of(context).pop(true);
            }
          }),
        ] else ...[
          if (widget.flow == RecoverBullFlow.settings) ...[
            _text(context.loc.recoverbullSettingsKeyServerUrl),
            BullInputText(
              controller: _server,
              value: _server.text,
              onChanged: (_) {},
              disabled: state.busy,
            ),
            _button(
              context.loc.recoverbullSettingsSave,
              () => cubit.settings(ChangeBackupServer(_server.text)),
              disabled: state.busy,
            ),
            if (settings != null)
              Row(
                children: [
                  BullCheckbox(
                    checked: settings.monitoringEnabled,
                    onChanged: state.busy
                        ? null
                        : (value) => cubit.settings(SetBackupMonitoring(value)),
                  ),
                  Expanded(
                    child: _text(context.loc.recoverbullMonitoringTitle),
                  ),
                ],
              ),
            _text(context.loc.recoverbullHistoricalUnknown),
          ],
          if (settings != null && !settings.permissionGranted) ...[
            _text(context.loc.recoverbullServerConfirmTitle),
            _text(settings.server.toString()),
            _text(context.loc.recoverbullServerCustomWarning),
            _text(context.loc.recoverbullServerTorNotice),
            _button(
              context.loc.recoverbullConfirm,
              () => cubit.settings(AcceptBackupServer(settings.server)),
              disabled: state.busy,
            ),
          ],
          if (widget.flow == RecoverBullFlow.viewVaultKey &&
              !_keyWarningAccepted) ...[
            _text(context.loc.backupKeyWarningMessage),
            _text(context.loc.backupKeySeparationWarning),
            _text(context.loc.backupKeyExampleWarning),
            _button(
              context.loc.recoverbullContinue,
              () => setState(() => _keyWarningAccepted = true),
            ),
          ] else if (widget.flow != RecoverBullFlow.settings) ...[
            if (widget.flow == RecoverBullFlow.secureVault) ...[
              _text(context.loc.recoverbullSelectVaultProvider),
              _button(
                context.loc.recoverbullSelectGoogleDrive,
                () => setState(() => _provider = VaultProvider.googleDrive),
                disabled: state.busy,
              ),
              _button(
                context.loc.recoverbullSelectCustomLocationProvider,
                () => setState(() => _provider = VaultProvider.customLocation),
                disabled: state.busy,
              ),
              _text(
                _provider == VaultProvider.googleDrive
                    ? context.loc.recoverbullSelectGoogleDrive
                    : context.loc.recoverbullSelectCustomLocationProvider,
              ),
            ] else if (state.vault == null) ...[
              _button(
                context.loc.recoverbullSelectCustomLocationProvider,
                cubit.pick,
                disabled: state.busy,
              ),
              _button(
                context.loc.recoverbullSelectGoogleDrive,
                cubit.list,
                disabled: state.busy,
              ),
              if (state.files case final files?) ...[
                if (files.isEmpty)
                  _text(context.loc.recoverbullGoogleDriveNoBackupsFound),
                for (final file in files) ...[
                  _button(
                    file.name,
                    () => cubit.select(file),
                    disabled: state.busy,
                  ),
                  _button(
                    context.loc.recoverbullGoogleDriveExportButton,
                    () => cubit.export(file),
                    disabled: state.busy,
                  ),
                  _button(
                    context.loc.recoverbullGoogleDriveDeleteButton,
                    () => setState(() => _deleting = file),
                    disabled: state.busy,
                  ),
                ],
              ],
              if (_deleting case final file?) ...[
                _text(context.loc.recoverbullGoogleDriveDeleteConfirmation),
                _text(file.name),
                _button(context.loc.recoverbullConfirm, () {
                  setState(() => _deleting = null);
                  unawaited(cubit.delete(file));
                }, disabled: state.busy),
                _button(
                  context.loc.recoverbullSettingsCancel,
                  () => setState(() => _deleting = null),
                ),
              ],
            ],
            if (state.vault != null ||
                widget.flow == RecoverBullFlow.secureVault) ...[
              if (state.vault != null)
                _text(context.loc.recoverbullVaultSelected),
              if (widget.flow == RecoverBullFlow.testVault)
                _text(context.loc.recoverbullHistoricalUnknown),
              if ([
                RecoverBullFlow.testVault,
                RecoverBullFlow.recoverVault,
              ].contains(widget.flow))
                _button(
                  _manual
                      ? context.loc.recoverbullSwitchToPassword
                      : context.loc.recoverbullEnterVaultKeyInstead,
                  () => setState(() {
                    _manual = !_manual;
                    _password.clear();
                    _inputError = null;
                  }),
                  disabled: state.busy,
                ),
              if (_protected != true)
                _text(
                  _protected == null
                      ? context.loc.recoverbullPleaseWait
                      : context.loc.recoverbullUnexpectedError,
                )
              else ...[
                _text(
                  _manual
                      ? context.loc.recoverbullVaultKeyInput
                      : context.loc.recoverbullPassword,
                ),
                ExcludeSemantics(
                  child: BullInputText(
                    controller: _password,
                    value: _password.text,
                    onChanged: (_) {},
                    obscure: true,
                    disabled: state.busy,
                    enableSuggestions: false,
                    autocorrect: false,
                    smartQuotesType: SmartQuotesType.disabled,
                    smartDashesType: SmartDashesType.disabled,
                  ),
                ),
                if (widget.flow == RecoverBullFlow.secureVault) ...[
                  _text(
                    context.loc.recoverbullReenterConfirm(
                      context.loc.recoverbullPassword,
                    ),
                  ),
                  ExcludeSemantics(
                    child: BullInputText(
                      controller: _confirmation,
                      value: _confirmation.text,
                      onChanged: (_) {},
                      obscure: true,
                      disabled: state.busy,
                      enableSuggestions: false,
                      autocorrect: false,
                      smartQuotesType: SmartQuotesType.disabled,
                      smartDashesType: SmartDashesType.disabled,
                    ),
                  ),
                ],
                if (_inputError case final message?) _text(message),
                _button(
                  context.loc.recoverbullContinue,
                  () => _submit(presentation),
                  disabled:
                      state.busy ||
                      (!_manual && settings?.permissionGranted != true),
                ),
              ],
            ],
            if (settings?.permissionGranted == true) ...[
              _button(
                context.loc.recoverbullRetry,
                cubit.connect,
                disabled: state.busy,
              ),
              _button(
                context.loc.recoverbullNewRoute,
                () => cubit.connect(newRoute: true),
                disabled: state.busy,
              ),
            ],
          ],
        ],
      ],
    );
  }
}
