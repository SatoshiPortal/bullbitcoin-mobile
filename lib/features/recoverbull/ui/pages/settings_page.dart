import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_recoverbull_url_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/store_recoverbull_url_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

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
      _urlController.text = url.toString();
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
      if (mounted) context.pop();
    } catch (e) {
      log.warning('Error saving recoverbull url: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    final borderDecoration = OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: BorderSide(color: context.colour.secondaryFixedDim),
    );

    return Scaffold(
      appBar: AppBar(
        title: BBText(
          'Recoverbull Settings',
          style: context.font.headlineMedium,
          color: context.colour.secondary,
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
                      const Gap(24),
                      TextFormField(
                        controller: _urlController,
                        validator: _validateUrl,
                        decoration: InputDecoration(
                          labelText: 'Key Server URL',
                          hintText: 'http://example.onion',
                          border: borderDecoration,
                          enabledBorder: borderDecoration,
                          focusedBorder: borderDecoration.copyWith(
                            borderSide: BorderSide(
                              color: context.colour.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: Device.screen.height * 0.05,
                        ),
                        child: BBButton.big(
                          label: 'Save',
                          onPressed: () => _saveUrl(),
                          bgColor: context.colour.secondary,
                          textColor: context.colour.onSecondary,
                          disabled: _isSaving,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
