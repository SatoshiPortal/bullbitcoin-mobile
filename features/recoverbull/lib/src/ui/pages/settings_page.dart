import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/recoverbull_server_url.dart';
import '../../domain/usecases/manage_backup_settings_usecase.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/recoverbull_failure_l10n.dart';
import '../../presentation/vault_flow_cubit.dart';
import '../recoverbull_flow_navigator.dart';
import '../widgets/backup_monitoring_panel.dart';
import 'server_confirmation_page.dart';

/// Key-server URL and attempt monitoring.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cubit = context.read<VaultFlowCubit>();
    await cubit.settings(ChangeBackupServer(_urlController.text.trim()));
    if (mounted && cubit.state.failure == null) {
      setState(() => _isEditing = false);
    }
  }

  String? _validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return context.loc.recoverbullSettingsUrlRequired;
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return context.loc.recoverbullSettingsUrlInvalid;
    if (uri.scheme != 'http') {
      return context.loc.recoverbullSettingsUrlMustBeHttp;
    }
    if (!isValidRecoverBullServerUrl(uri)) {
      return context.loc.recoverbullSettingsUrlMustBeOnion;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scope = RecoverBullFlowScope.of(context);
    final onOpenTorSettings = scope.onOpenTorSettings;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => recoverBullBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: BullText(
          context.loc.recoverbullSettingsTitle,
          style: context.bullType.subtitle.copyWith(
            fontWeight: FontWeight.w500,
          ),
          color: context.bull.onSurface,
        ),
      ),
      body: BlocBuilder<VaultFlowCubit, VaultFlowState>(
        builder: (context, state) {
          final settings = state.settings;
          final url = settings?.server.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  if (scope.presentation.monitoring case final monitoring?)
                    BackupMonitoringPanel(cubit: monitoring),
                  const Gap(16),
                  if (onOpenTorSettings != null) ...[
                    BullSettingsEntryItem(
                      icon: Icons.vpn_lock,
                      title: context.loc.torTitle,
                      onTap: onOpenTorSettings,
                    ),
                    const Gap(24),
                  ],
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Expanded(
                        child: BullText(
                          context.loc.recoverbullSettingsKeyServerUrl,
                          style: context.bullType.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          color: context.bull.onSurface,
                        ),
                      ),
                      if (!_isEditing && (settings?.serverEditable ?? false))
                        BullButton.secondary(
                          label: context.loc.recoverbullSettingsEdit,
                          onPressed: settings == null || state.busy
                              ? null
                              : () {
                                  _urlController.text = url;
                                  setState(() => _isEditing = true);
                                },
                          size: BullButtonSize.small,
                          compact: true,
                        ),
                    ],
                  ),
                  const Gap(12),
                  if (_isEditing)
                    TextFormField(
                      controller: _urlController,
                      validator: _validateUrl,
                      maxLines: null,
                      autofocus: true,
                      style: context.bullType.body,
                      decoration: InputDecoration(
                        hintText: context.loc.recoverbullSettingsUrlHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            context.bullShapes.input,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.bull.cardBackground,
                        borderRadius: BorderRadius.circular(
                          context.bullShapes.card,
                        ),
                        border: Border.all(color: context.bull.border),
                      ),
                      child: BullText(
                        url,
                        style: context.bullType.body,
                        color: context.bull.onSurface,
                      ),
                    ),
                  if (settings != null) ...[
                    const Gap(16),
                    Row(
                      children: [
                        BullCheckbox(
                          checked: settings.monitoringEnabled,
                          onChanged: state.busy
                              ? null
                              : (value) => context
                                    .read<VaultFlowCubit>()
                                    .settings(SetBackupMonitoring(value)),
                        ),
                        Expanded(
                          child: BullText(
                            context.loc.recoverbullMonitoringTitle,
                            style: context.bullType.body,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (state.failure case final failure?) ...[
                    const Gap(12),
                    BullText(
                      failure.toTranslated(context),
                      style: context.bullType.body.copyWith(
                        color: context.bull.error,
                      ),
                      maxLines: 4,
                    ),
                  ],
                  const Spacer(),
                  if (_isEditing) ...[
                    Row(
                      children: [
                        Expanded(
                          child: BullButton.secondary(
                            label: context.loc.recoverbullSettingsCancel,
                            onPressed: () => setState(() => _isEditing = false),
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: BullButton.primary(
                            label: context.loc.recoverbullSettingsSave,
                            onPressed: (state.busy) ? null : _saveUrl,
                          ),
                        ),
                      ],
                    ),
                    const Gap(16),
                  ],
                  GestureDetector(
                    onTap: openRecoverBullWebsite,
                    child: Row(
                      mainAxisAlignment: .center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: context.bull.primary,
                        ),
                        const Gap(8),
                        BullText(
                          context.loc.recoverbullLearnMore,
                          style: context.bullType.body,
                          color: context.bull.primary,
                        ),
                      ],
                    ),
                  ),
                  const Gap(24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
