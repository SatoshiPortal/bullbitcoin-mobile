import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_recoverbull_url_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/is_recoverbull_telemetry_enabled_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/set_recoverbull_telemetry_enabled_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/store_recoverbull_url_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _fetchUrlUsecase = locator<FetchRecoverbullUrlUsecase>();
  final _storeUrlUsecase = locator<StoreRecoverbullUrlUsecase>();
  final _isTelemetryEnabledUsecase =
      locator<IsRecoverbullTelemetryEnabledUsecase>();
  final _setTelemetryEnabledUsecase =
      locator<SetRecoverbullTelemetryEnabledUsecase>();
  final _getSettingsUsecase = locator<GetSettingsUsecase>();
  bool _isDevMode = false;
  bool _isTelemetryEnabled = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isEditing = false;
  String _originalUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadUrl() async {
    setState(() => _isLoading = true);
    try {
      final url = await _fetchUrlUsecase.execute();
      _originalUrl = url.toString();
      // The telemetry flag is a rollout gate, not a user preference: the
      // toggle is only surfaced in dev mode so QA can exercise the feature
      // before it is enabled for everyone.
      _isTelemetryEnabled = await _isTelemetryEnabledUsecase.execute();
      _isDevMode =
          (await _getSettingsUsecase.execute()).isDevModeEnabled ?? false;
    } catch (e) {
      log.warning('Error loading recoverbull url: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleTelemetry(bool value) async {
    try {
      await _setTelemetryEnabledUsecase.execute(value);
      if (mounted) setState(() => _isTelemetryEnabled = value);
    } catch (e) {
      log.warning('Error toggling recoverbull telemetry: $e');
    }
  }

  Future<void> _saveUrl() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final url = Uri.parse(_urlController.text);
      await _storeUrlUsecase.execute(url);
      _originalUrl = url.toString();
      if (mounted) {
        setState(() => _isEditing = false);
      }
    } catch (e) {
      log.warning('Error saving recoverbull url: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
      body: _isLoading
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
                    if (_isDevMode) ...[
                      const Gap(24),
                      Row(
                        mainAxisAlignment: .spaceBetween,
                        children: [
                          Expanded(
                            child: BBText(
                              context.loc.recoverbullSettingsTelemetryToggle,
                              style: context.font.titleMedium,
                              color: context.appColors.onSurface,
                            ),
                          ),
                          Switch(
                            value: _isTelemetryEnabled,
                            onChanged: _toggleTelemetry,
                          ),
                        ],
                      ),
                      BBText(
                        context.loc.recoverbullSettingsTelemetryToggleHint,
                        style: context.font.bodySmall,
                        color: context.appColors.textMuted,
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
                              disabled: _isSaving,
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
    );
  }
}
