import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../l10n/context_localizations.dart';
import '../support.dart';
import 'recoverbull_settings_cubit.dart';
import '../../domain/usecases/fetch_recoverbull_url_usecase.dart';
import '../../domain/usecases/store_recoverbull_url_usecase.dart';
import '../../public/recoverbull.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar, BullSwitch, Gap;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  final LogSink log;
  final RecoverBullSettingsCubit cubit;
  SettingsPage({
    super.key,
    required this.log,
    RecoverBullSettingsCubit? cubit,
    FetchRecoverbullUrlUsecase? fetchUrlUsecase,
    StoreRecoverbullUrlUsecase? storeUrlUsecase,
    RecoverBullAttemptMonitoringController? monitoring,
  }) : cubit =
           cubit ??
           RecoverBullSettingsCubit(
             log: log,
             fetchUrl: fetchUrlUsecase!,
             storeUrl: storeUrlUsecase!,
             monitoring: monitoring,
           );

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  String _originalUrl = '';

  @override
  void initState() {
    super.initState();
    widget.cubit.load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    if (!_formKey.currentState!.validate()) return;

    final saved = await widget.cubit.save(_urlController.text);
    if (saved && mounted) {
      _originalUrl = widget.cubit.state.url;
      setState(() => _isEditing = false);
    } else if (mounted) {
      BullSnackBar.show(
        context,
        message: context.loc.recoverbullErrorUnexpected,
      );
    }
  }

  void _cancelEdit() => setState(() => _isEditing = false);

  Future<void> _openRecoverBullWebsite() async {
    final uri = Uri.parse('https://recoverbull.com/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? _validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return context.loc.recoverbullSettingsUrlRequired;
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return context.loc.recoverbullSettingsUrlInvalid;
    if (uri.scheme != 'http') {
      return context.loc.recoverbullSettingsUrlMustBeHttp;
    }
    if (!uri.toString().endsWith('.onion')) {
      return context.loc.recoverbullSettingsUrlMustBeOnion;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_originalUrl.isEmpty && widget.cubit.state.url.isNotEmpty) {
      _originalUrl = widget.cubit.state.url;
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: BBText(
          context.loc.recoverbullSettingsTitle,
          style: context.font.headlineMedium,
          color: context.appColors.onSurface,
        ),
      ),
      body: BlocBuilder<RecoverBullSettingsCubit, RecoverBullSettingsState>(
        bloc: widget.cubit,
        builder: (context, settings) => settings.loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      const Gap(16),
                      Row(
                        mainAxisAlignment: .spaceBetween,
                        children: [
                          BBText(
                            context.loc.recoverbullSettingsKeyServerUrl,
                            style: context.font.titleMedium,
                            color: context.appColors.onSurface,
                          ),
                          if (!_isEditing)
                            TextButton.icon(
                              onPressed: () {
                                _urlController.text = _originalUrl;
                                setState(() => _isEditing = true);
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: Text(context.loc.recoverbullSettingsEdit),
                            ),
                        ],
                      ),
                      const Gap(12),
                      if (_isEditing) ...[
                        TextFormField(
                          controller: _urlController,
                          validator: _validateUrl,
                          maxLines: null,
                          autofocus: true,
                          style: context.font.bodyMedium,
                          decoration: InputDecoration(
                            hintText: context.loc.recoverbullSettingsUrlHint,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.appColors.cardBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.appColors.border),
                          ),
                          child: BBText(
                            _originalUrl,
                            style: context.font.bodyMedium,
                            color: context.appColors.onSurface,
                          ),
                        ),
                      ],
                      if (settings.monitoring case final monitoring?) ...[
                        const Gap(24),
                        BBText(
                          context.loc.recoverbullMonitoringTitle,
                          style: context.font.titleMedium,
                          color: context.appColors.onSurface,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: BBText(
                                context.loc.recoverbullMonitoringEnabled,
                                style: context.font.bodyMedium,
                                color: context.appColors.onSurface,
                              ),
                            ),
                            BullSwitch(
                              value: monitoring.enabled,
                              onChanged: widget.cubit.setMonitoringEnabled,
                            ),
                          ],
                        ),
                        Text(
                          monitoring.isUncovered
                              ? context.loc.recoverbullMonitoringUncovered
                              : context.loc.recoverbullMonitoringCount(
                                  monitoring.monitoredCount,
                                ),
                          style: context.font.bodyMedium,
                        ),
                        if (monitoring.lastSuccessfulCheck case final date?)
                          Text(
                            context.loc.recoverbullMonitoringLastCheck(
                              MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(date.toLocal()),
                            ),
                            style: context.font.bodySmall,
                          ),
                        const Gap(8),
                        Text(
                          context.loc.recoverbullMonitoringExplanation,
                          style: context.font.bodySmall,
                        ),
                      ],
                      const Spacer(),
                      if (_isEditing) ...[
                        Row(
                          children: [
                            Expanded(
                              child: BBButton.big(
                                label: context.loc.recoverbullSettingsCancel,
                                onPressed: _cancelEdit,
                                bgColor: context.appColors.cardBackground,
                                textColor: context.appColors.onSurface,
                              ),
                            ),
                            const Gap(8),
                            Expanded(
                              child: BBButton.big(
                                label: context.loc.recoverbullSettingsSave,
                                onPressed: _saveUrl,
                                bgColor: context.appColors.onSurface,
                                textColor: context.appColors.surface,
                                disabled: settings.saving,
                              ),
                            ),
                          ],
                        ),
                        const Gap(16),
                      ],
                      GestureDetector(
                        onTap: _openRecoverBullWebsite,
                        child: Row(
                          mainAxisAlignment: .center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: context.appColors.primary,
                            ),
                            const Gap(8),
                            BBText(
                              context.loc.recoverbullLearnMore,
                              style: context.font.bodyMedium,
                              color: context.appColors.primary,
                            ),
                          ],
                        ),
                      ),
                      const Gap(24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
