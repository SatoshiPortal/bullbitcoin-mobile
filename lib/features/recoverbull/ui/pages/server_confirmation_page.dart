import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_recoverbull_url_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ServerConfirmationPage extends StatefulWidget {
  const ServerConfirmationPage({super.key, required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  State<ServerConfirmationPage> createState() => _ServerConfirmationPageState();
}

class _ServerConfirmationPageState extends State<ServerConfirmationPage> {
  final _fetchUrlUsecase = locator<FetchRecoverbullUrlUsecase>();
  bool _isLoading = true;
  String? _serverUrl;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    try {
      final url = await _fetchUrlUsecase.execute();
      if (mounted) {
        setState(() {
          _serverUrl = url.toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      log.warning('Error loading recoverbull url: $e');
      if (mounted) {
        setState(() {
          _serverUrl = SettingsConstants.recoverbullUrl;
          _isLoading = false;
        });
      }
    }
  }

  bool get _isUsingDefaultServer =>
      _serverUrl == SettingsConstants.recoverbullUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BBText(
          'Vault Recovery Server',
          style: context.font.headlineMedium,
          color: context.colour.secondary,
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(24),
                    Icon(
                      _isUsingDefaultServer
                          ? Icons.verified_user
                          : Icons.warning_amber,
                      size: 64,
                      color:
                          _isUsingDefaultServer
                              ? context.colour.primary
                              : context.colour.tertiary,
                    ),
                    const Gap(32),
                    BBText(
                      _isUsingDefaultServer
                          ? 'Using Default Server'
                          : 'Using Custom Server',
                      style: context.font.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const Gap(16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colour.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: context.colour.outline,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BBText(
                            'Server URL:',
                            style: context.font.labelSmall?.copyWith(
                              color: context.colour.onSurfaceVariant,
                            ),
                          ),
                          const Gap(8),
                          BBText(
                            _serverUrl ?? SettingsConstants.recoverbullUrl,
                            style: context.font.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(24),
                    if (!_isUsingDefaultServer) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.colour.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: context.colour.onTertiaryContainer,
                              size: 20,
                            ),
                            const Gap(12),
                            Expanded(
                              child: BBText(
                                'You are using a custom Recoverbull server. Make sure you trust this server.',
                                style: context.font.bodySmall?.copyWith(
                                  color: context.colour.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(24),
                    ],
                    const Spacer(),
                    BBText(
                      'We will connect to this server to recover your encrypted vault backup.',
                      style: context.font.bodyMedium?.copyWith(
                        color: context.colour.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(32),
                    BBButton.big(
                      label: 'Continue',
                      onPressed: widget.onConfirm,
                      bgColor: context.colour.primary,
                      textColor: context.colour.onPrimary,
                    ),
                    const Gap(16),
                  ],
                ),
              ),
    );
  }
}
