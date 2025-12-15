import 'package:bb_mobile/core_deprecated/recoverbull/domain/usecases/allow_permission_usecase.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/domain/usecases/fetch_recoverbull_url_usecase.dart';
import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/constants.dart';
import 'package:bb_mobile/core_deprecated/utils/logger.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/core_deprecated/widgets/cards/info_card.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestPermissionPage extends StatefulWidget {
  const RequestPermissionPage({super.key});

  @override
  State<RequestPermissionPage> createState() => _RequestPermissionPageState();
}

class _RequestPermissionPageState extends State<RequestPermissionPage> {
  final _fetchUrlUsecase = locator<FetchRecoverbullUrlUsecase>();
  final _allowPermissionUsecase = locator<AllowPermissionUsecase>();

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

  Future<void> _openRecoverBullWebsite() async {
    final uri = Uri.parse('https://recoverbull.com/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
          'Vault Recovery Server',
          style: context.font.headlineMedium,
          color: context.appColors.onSurface,
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    const Gap(24),
                    Icon(
                      _isUsingDefaultServer
                          ? Icons.verified_user
                          : Icons.warning_amber,
                      size: 64,
                      color:
                          _isUsingDefaultServer
                              ? context.appColors.primary
                              : context.appColors.tertiary,
                    ),
                    const Gap(32),
                    BBText(
                      _isUsingDefaultServer
                          ? 'Using Default Server'
                          : 'Using Custom Server',
                      style: context.font.headlineMedium,
                      textAlign: .center,
                    ),
                    const Gap(16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.appColors.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: context.appColors.border,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          BBText(
                            'Server URL:',
                            style: context.font.labelSmall?.copyWith(
                              color: context.appColors.textMuted,
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
                      InfoCard(
                        description:
                            'You are using a custom Recoverbull server. Make sure you trust this server.',
                        tagColor: context.appColors.error,
                        bgColor: context.appColors.errorContainer,
                      ),
                      const Gap(24),
                    ],
                    BBText(
                      'We will connect to this server through Tor',
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                      textAlign: .center,
                    ),
                    const Spacer(),
                    BBButton.big(
                      label: 'Continue',
                      onPressed: () async {
                        await _allowPermissionUsecase.execute(true);
                        if (!context.mounted) return;
                        final state = context.read<RecoverBullBloc>().state;
                        await context.pushNamed(
                          RecoverBullRoute.recoverbullFlows.name,
                          extra: RecoverBullFlowsExtra(
                            flow: state.flow,
                            vault: state.vault,
                          ),
                        );
                      },
                      bgColor: context.appColors.onSurface,
                      textColor: context.appColors.surface,
                    ),
                    const Gap(16),
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
                            'Learn more about Recoverbull',
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
    );
  }
}
