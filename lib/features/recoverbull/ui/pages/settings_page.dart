import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_recoverbull_url_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/store_recoverbull_url_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
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
    } catch (e) {
      log.warning('Error loading recoverbull url: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      return 'URL is required';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return 'URL is not valid';
    if (uri.scheme != 'http') return 'URL must be HTTP';
    if (!uri.toString().endsWith('.onion')) {
      return 'URL must end with .onion';
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
          'Recoverbull Settings',
          style: context.font.headlineMedium,
          color: context.colorScheme.onSurface,
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Gap(16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          BBText(
                            'Key Server URL',
                            style: context.font.titleMedium,
                            color: context.colorScheme.onSurface,
                          ),
                          if (!_isEditing)
                            TextButton.icon(
                              onPressed: () {
                                _urlController.text = _originalUrl;
                                setState(() => _isEditing = true);
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Edit'),
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
                            hintText: 'http://example.onion',
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
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (_isEditing) ...[
                        Row(
                          children: [
                            Expanded(
                              child: BBButton.big(
                                label: 'Cancel',
                                onPressed: _cancelEdit,
                                bgColor: context.appColors.cardBackground,
                                textColor: context.colorScheme.onSurface,
                              ),
                            ),
                            const Gap(8),
                            Expanded(
                              child: BBButton.big(
                                label: 'Save',
                                onPressed: _saveUrl,
                                bgColor: context.colorScheme.onSurface,
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: context.colorScheme.primary,
                            ),
                            const Gap(8),
                            BBText(
                              'Learn more about Recoverbull',
                              style: context.font.bodyMedium,
                              color: context.colorScheme.primary,
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
