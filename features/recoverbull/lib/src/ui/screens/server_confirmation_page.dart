import 'package:primitives/primitives.dart';
import '../../domain/recoverbull_failure.dart';
import '../../presentation/recoverbull_failure_l10n.dart';
import '../../domain/usecases/allow_permission_usecase.dart';
import '../../domain/usecases/fetch_recoverbull_url_usecase.dart';
import '../../public/recoverbull.dart' show recoverBullDefaultServerUrl;
import 'package:bull_logger/bull_logger.dart';
import '../../presentation/bloc.dart';
import '../../router/recoverbull_router.dart';
import '../../l10n/context_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestPermissionPage extends StatefulWidget {
  final LogSink log;
  final FetchRecoverbullUrlUsecase fetchUrlUsecase;
  final AllowPermissionUsecase allowPermissionUsecase;
  const RequestPermissionPage({
    super.key,
    required this.log,
    required this.fetchUrlUsecase,
    required this.allowPermissionUsecase,
  });

  @override
  State<RequestPermissionPage> createState() => _RequestPermissionPageState();
}

class _RequestPermissionPageState extends State<RequestPermissionPage> {
  bool _isLoading = true;
  String? _serverUrl;
  RecoverBullFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    final result = await widget.fetchUrlUsecase.execute();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      switch (result) {
        case Ok(:final value):
          _serverUrl = value.toString();
        case Err(:final failure):
          _failure = failure;
      }
    });
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
    return BullScaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: BullText(
          context.loc.recoverbullServerConfirmTitle,
          style: context.bullText.headlineMedium,
          color: context.bull.onSurface,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _failure != null && _serverUrl == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BullText(
                    _failure!.toTranslated(context),
                    style: context.bullText.bodyMedium,
                  ),
                  BullButton.big(
                    label: context.loc.recoverbullRetry,
                    bgColor: context.bull.primary,
                    textColor: context.bull.onPrimary,
                    onPressed: _loadServerUrl,
                  ),
                ],
              ),
            )
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
                        ? context.bull.primary
                        : context.bull.tertiary,
                  ),
                  const Gap(32),
                  BullText(
                    _isUsingDefaultServer
                        ? context.loc.recoverbullServerUsingDefault
                        : context.loc.recoverbullServerUsingCustom,
                    style: context.bullText.headlineMedium,
                    textAlign: .center,
                  ),
                  const Gap(16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.bull.cardBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.bull.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        BullText(
                          context.loc.recoverbullServerUrlLabel,
                          style: context.bullText.labelSmall?.copyWith(
                            color: context.bull.textMuted,
                          ),
                        ),
                        const Gap(8),
                        BullText(
                          _serverUrl ?? recoverBullDefaultServerUrl,
                          style: context.bullText.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(24),
                  if (!_isUsingDefaultServer) ...[
                    BullInfoCard(
                      description: context.loc.recoverbullServerCustomWarning,
                      tagColor: context.bull.error,
                      bgColor: context.bull.errorContainer,
                    ),
                    const Gap(24),
                  ],
                  BullText(
                    context.loc.recoverbullServerTorNotice,
                    style: context.bullText.bodyMedium?.copyWith(
                      color: context.bull.textMuted,
                    ),
                    textAlign: .center,
                  ),
                  const Spacer(),
                  BullButton.big(
                    label: context.loc.recoverbullContinue,
                    disabled: _isSaving,
                    onPressed: () async {
                      if (_isSaving) return;
                      setState(() => _isSaving = true);
                      final result = await widget.allowPermissionUsecase
                          .execute(true);
                      if (!context.mounted) return;
                      setState(() => _isSaving = false);
                      if (result case Err(:final failure)) {
                        BullSnackBar.show(
                          context,
                          message: failure.toTranslated(context),
                        );
                        return;
                      }
                      final state = context.read<RecoverBullBloc>().state;
                      context.pushReplacementNamed(
                        RecoverBullRoute.recoverbullFlows.name,
                        extra: RecoverBullFlowsExtra(
                          flow: state.flow,
                          vault: state.vault,
                        ),
                      );
                    },
                    bgColor: context.bull.onSurface,
                    textColor: context.bull.surface,
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
    );
  }
}
