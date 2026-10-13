import '../../presentation/recoverbull_failure_l10n.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/recoverbull_settings_cubit.dart';
import '../../domain/usecases/fetch_recoverbull_url_usecase.dart';
import '../../domain/usecases/store_recoverbull_url_usecase.dart';
import '../../public/recoverbull.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  final LogSink log;
  final RecoverBullSettingsCubit? cubit;
  final FetchRecoverbullUrlUsecase? fetchUrlUsecase;
  final StoreRecoverbullUrlUsecase? storeUrlUsecase;
  final RecoverBullAttemptMonitoringController? monitoring;

  const SettingsPage({
    super.key,
    required this.log,
    this.cubit,
    this.fetchUrlUsecase,
    this.storeUrlUsecase,
    this.monitoring,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isChangingMonitoring = false;
  bool _isRetryingMonitoring = false;
  late final RecoverBullSettingsCubit _cubit;

  @override
  void initState() {
    super.initState();
    final monitoring = widget.monitoring == null
        ? null
        : createRecoverBullMonitoringSettingsUsecases(
            widget.monitoring!,
            log: widget.log,
          );
    _cubit =
        widget.cubit ??
        RecoverBullSettingsCubit(
          log: widget.log,
          fetchUrl: widget.fetchUrlUsecase!,
          storeUrl: widget.storeUrlUsecase!,
          monitoringStatus: monitoring?.load,
          changeMonitoring: monitoring?.change,
        );
    _cubit.load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    if (widget.cubit == null) _cubit.close();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    if (!_formKey.currentState!.validate()) return;

    final saved = await _cubit.save(_urlController.text);
    if (saved && mounted) {
      setState(() => _isEditing = false);
    } else if (mounted) {
      BullSnackBar.show(
        context,
        message:
            _cubit.state.failure?.toTranslated(context) ??
            context.loc.oopsSomethingWentWrong,
      );
    }
  }

  void _cancelEdit() => setState(() => _isEditing = false);

  Future<void> _setMonitoringEnabled(bool enabled) async {
    if (_isChangingMonitoring) return;
    setState(() => _isChangingMonitoring = true);
    try {
      if (!enabled) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.loc.recoverbullMonitoringDisableTitle),
            content: Text(context.loc.recoverbullMonitoringDisableWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.loc.recoverbullMonitoringDisableCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.loc.recoverbullMonitoringDisableConfirm),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      await _cubit.setMonitoringEnabled(enabled);
      final failure = _cubit.state.failure;
      if (mounted && failure != null) {
        BullSnackBar.show(context, message: failure.toTranslated(context));
      }
    } finally {
      if (mounted) setState(() => _isChangingMonitoring = false);
    }
  }

  Future<void> _retryMonitoring() async {
    if (_isRetryingMonitoring) return;
    setState(() => _isRetryingMonitoring = true);
    try {
      // Reloading the persisted settings never writes into the text controller,
      // so an unfinished server URL edit remains intact while monitoring retries.
      await _cubit.load();
    } finally {
      if (mounted) setState(() => _isRetryingMonitoring = false);
    }
  }

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
    if (!uri.host.toLowerCase().endsWith('.onion')) {
      return context.loc.recoverbullSettingsUrlMustBeOnion;
    }
    // The domain rule decides the rest (port, credentials, query), so the
    // form accepts exactly what the key-server settings accept.
    try {
      validateRecoverBullServerUrl(uri);
    } on ArgumentError {
      return context.loc.recoverbullSettingsUrlInvalid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BullScaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: BullText(
          context.loc.recoverbullSettingsTitle,
          style: context.bullText.headlineMedium,
          color: context.bull.onSurface,
        ),
      ),
      body: BlocBuilder<RecoverBullSettingsCubit, RecoverBullSettingsState>(
        bloc: _cubit,
        builder: (context, settings) => settings.loading
            ? const Center(child: CircularProgressIndicator())
            : settings.failure != null && settings.url.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BullText(
                      settings.failure!.toTranslated(context),
                      style: context.bullText.bodyMedium,
                    ),
                    BullButton.big(
                      label: context.loc.recoverbullRetry,
                      bgColor: context.bull.primary,
                      textColor: context.bull.onPrimary,
                      onPressed: _cubit.load,
                    ),
                  ],
                ),
              )
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
                          BullText(
                            context.loc.recoverbullSettingsKeyServerUrl,
                            style: context.bullText.titleMedium,
                            color: context.bull.onSurface,
                          ),
                          if (!_isEditing)
                            TextButton.icon(
                              onPressed: () {
                                _urlController.text = settings.url;
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
                          style: context.bullText.bodyMedium,
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
                            color: context.bull.cardBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.bull.border),
                          ),
                          child: BullText(
                            settings.url,
                            style: context.bullText.bodyMedium,
                            color: context.bull.onSurface,
                          ),
                        ),
                      ],
                      if (_cubit.monitoringStatus != null &&
                          settings.monitoring == null) ...[
                        const Gap(24),
                        BullText(
                          context.loc.recoverbullMonitoringTitle,
                          style: context.bullText.titleMedium,
                        ),
                        const Gap(8),
                        BullText(
                          settings.failure?.toTranslated(context) ??
                              context.loc.oopsSomethingWentWrong,
                          style: context.bullText.bodyMedium,
                        ),
                        const Gap(8),
                        BullButton.big(
                          label: context.loc.recoverbullRetry,
                          bgColor: context.bull.primary,
                          textColor: context.bull.onPrimary,
                          disabled: _isRetryingMonitoring,
                          onPressed: _retryMonitoring,
                        ),
                      ],
                      if (settings.monitoring case final monitoring?) ...[
                        const Gap(24),
                        BullText(
                          context.loc.recoverbullMonitoringTitle,
                          style: context.bullText.titleMedium,
                          color: context.bull.onSurface,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: BullText(
                                context.loc.recoverbullMonitoringEnabled,
                                style: context.bullText.bodyMedium,
                                color: context.bull.onSurface,
                              ),
                            ),
                            BullSwitch(
                              value: monitoring.enabled,
                              onChanged: _isChangingMonitoring
                                  ? null
                                  : _setMonitoringEnabled,
                            ),
                          ],
                        ),
                        Text(
                          monitoring.serverUnsupported
                              ? context
                                    .loc
                                    .recoverbullMonitoringServerUnsupported
                              : monitoring.isUncovered
                              ? context.loc.recoverbullMonitoringUncovered
                              : context.loc.recoverbullMonitoringCount(
                                  monitoring.monitoredCount,
                                ),
                          style: context.bullText.bodyMedium,
                        ),
                        if (monitoring case RecoverBullMonitoringStatus(
                          serverUnsupported: false,
                          lastSuccessfulCheck: final date?,
                        ))
                          Text(
                            context.loc.recoverbullMonitoringLastCheck(
                              MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(date.toLocal()),
                            ),
                            style: context.bullText.bodySmall,
                          ),
                        const Gap(8),
                        Text(
                          context.loc.recoverbullMonitoringExplanation,
                          style: context.bullText.bodySmall,
                        ),
                      ],
                      const Spacer(),
                      if (_isEditing) ...[
                        Row(
                          children: [
                            Expanded(
                              child: BullButton.big(
                                label: context.loc.recoverbullSettingsCancel,
                                onPressed: _cancelEdit,
                                bgColor: context.bull.cardBackground,
                                textColor: context.bull.onSurface,
                              ),
                            ),
                            const Gap(8),
                            Expanded(
                              child: BullButton.big(
                                label: context.loc.recoverbullSettingsSave,
                                onPressed: _saveUrl,
                                bgColor: context.bull.onSurface,
                                textColor: context.bull.surface,
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
                              color: context.bull.primary,
                            ),
                            const Gap(8),
                            BullText(
                              context.loc.recoverbullLearnMore,
                              style: context.bullText.bodyMedium,
                              color: context.bull.primary,
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
