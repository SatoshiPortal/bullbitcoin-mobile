import 'package:bull_recoverbull/src/domain/usecases/allow_permission_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_recoverbull_url_usecase.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart'
    show recoverBullDefaultServerUrl;
import 'package:bull_recoverbull/src/support/logger.dart';
import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/router/recoverbull_router.dart';
import 'package:flutter/material.dart';
import 'package:bull_recoverbull/src/l10n/context_localizations.dart';
import 'package:bull_recoverbull/src/ui/support.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestPermissionPage extends StatefulWidget {
  final FetchRecoverbullUrlUsecase fetchUrlUsecase;
  final AllowPermissionUsecase allowPermissionUsecase;
  const RequestPermissionPage({
    super.key,
    required this.fetchUrlUsecase,
    required this.allowPermissionUsecase,
  });

  @override
  State<RequestPermissionPage> createState() => _RequestPermissionPageState();
}

class _RequestPermissionPageState extends State<RequestPermissionPage> {
  bool _isLoading = true;
  String? _serverUrl;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    try {
      final url = await widget.fetchUrlUsecase.execute();
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
          _serverUrl = recoverBullDefaultServerUrl;
          _isLoading = false;
        });
      }
    }
  }

  bool get _isUsingDefaultServer => _serverUrl == recoverBullDefaultServerUrl;

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
          context.loc.recoverbullServerConfirmTitle,
          style: context.font.headlineMedium,
          color: context.appColors.onSurface,
        ),
      ),
      body: _isLoading
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
                    color: _isUsingDefaultServer
                        ? context.appColors.primary
                        : context.appColors.tertiary,
                  ),
                  const Gap(32),
                  BBText(
                    _isUsingDefaultServer
                        ? context.loc.recoverbullServerUsingDefault
                        : context.loc.recoverbullServerUsingCustom,
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
                          context.loc.recoverbullServerUrlLabel,
                          style: context.font.labelSmall?.copyWith(
                            color: context.appColors.textMuted,
                          ),
                        ),
                        const Gap(8),
                        BBText(
                          _serverUrl ?? recoverBullDefaultServerUrl,
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
                      description: context.loc.recoverbullServerCustomWarning,
                      tagColor: context.appColors.error,
                      bgColor: context.appColors.errorContainer,
                    ),
                    const Gap(24),
                  ],
                  BBText(
                    context.loc.recoverbullServerTorNotice,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                    textAlign: .center,
                  ),
                  const Spacer(),
                  BBButton.big(
                    label: context.loc.recoverbullContinue,
                    onPressed: () async {
                      await widget.allowPermissionUsecase.execute(true);
                      if (!context.mounted) return;
                      final state = context.read<RecoverBullBloc>().state;
                      context.goNamed(
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
    );
  }
}
