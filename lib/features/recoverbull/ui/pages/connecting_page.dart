import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/presentation/recoverbull_failure_l10n.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/password_input_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/vault_provider_selection_page.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_tor/tor.dart' as tor;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullPage, Gap;
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

class ConnectingPage extends StatelessWidget {
  const ConnectingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecoverBullBloc, RecoverBullState>(
      listenWhen: (previous, current) =>
          previous.torConnection != current.torConnection ||
          previous.keyServerStatus != current.keyServerStatus,
      listener: (context, state) {
        if (state.torConnection is tor.TorReady &&
            state.keyServerStatus == KeyServerStatus.online) {
          final flow = state.flow;
          final hasPreSelectedVault = state.vault != null;

          final nextPage = switch (flow) {
            RecoverBullFlow.secureVault => const PasswordInputPage(),
            _ =>
              hasPreSelectedVault
                  ? const PasswordInputPage()
                  : const VaultProviderSelectionPage(),
          };

          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (context) => nextPage));
        }
      },
      child: BullPage(
        // This page intentionally has a titleless AppBar; BullTopBar requires
        // a title and would add visible chrome that is not present today.
        topBar: AppBar(
          forceMaterialTransparency: true,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: BlocBuilder<RecoverBullBloc, RecoverBullState>(
            builder: (context, state) {
              final torStatus = switch (state.torConnection) {
                tor.TorReady() => KeyServerStatus.online,
                tor.TorUnavailable() => KeyServerStatus.offline,
                tor.TorConnecting() => KeyServerStatus.connecting,
                tor.TorUninitialized() ||
                tor.TorStopped() => KeyServerStatus.unknown,
              };
              final torOnline = torStatus == KeyServerStatus.online;
              final serverOnline =
                  state.keyServerStatus == KeyServerStatus.online;
              final hasError =
                  torStatus == KeyServerStatus.offline ||
                  state.keyServerStatus == KeyServerStatus.offline;

              return Column(
                mainAxisAlignment: .center,
                crossAxisAlignment: .center,
                children: [
                  if (!torOnline || !serverOnline)
                    Gif(
                      autostart: Autostart.loop,
                      width: 200,
                      height: 200,
                      image: AssetImage(Assets.animations.cubesLoading.path),
                    )
                  else
                    const SizedBox(height: 200),
                  const Gap(24),
                  BBText(
                    context.loc.recoverbullCheckingConnection,
                    textAlign: .center,
                    style: context.font.headlineLarge?.copyWith(
                      fontWeight: .bold,
                    ),
                  ),
                  const Gap(24),
                  _StatusRow(
                    label: context.loc.recoverbullTorNetwork,
                    status: torStatus,
                  ),
                  const Gap(12),
                  _StatusRow(
                    label: context.loc.recoverbullRecoverBullServer,
                    status: state.keyServerStatus,
                  ),
                  const Gap(40),
                  if (hasError) ...[
                    BBText(
                      state.failure?.toTranslated(context) ??
                          context.loc.recoverbullConnectionFailed,
                      textAlign: .center,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.error,
                      ),
                      maxLines: 3,
                    ),
                    const Gap(24),
                    BullButton.big(
                      label: context.loc.recoverbullRetry,
                      textStyle: context.font.headlineLarge,
                      bgColor: context.appColors.onSurface,
                      textColor: context.appColors.surface,
                      onPressed: () {
                        context.read<RecoverBullBloc>().add(
                          const OnTorInitialization(restart: true),
                        );
                      },
                    ),
                  ] else ...[
                    BBText(
                      context.loc.recoverbullPleaseWait,
                      textAlign: .center,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final KeyServerStatus status;

  const _StatusRow({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final statusText = _getStatusText(context);
    final statusColor = _getStatusColor(context);
    final icon = _getIcon();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: statusColor),
          const Gap(12),
          Expanded(
            child: BBText(
              label,
              style: context.font.bodyLarge?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
          BBText(
            statusText,
            style: context.font.bodyMedium?.copyWith(
              color: statusColor,
              fontWeight: .w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(BuildContext context) {
    return switch (status) {
      KeyServerStatus.unknown => context.loc.recoverbullWaiting,
      KeyServerStatus.connecting => context.loc.recoverbullConnecting,
      KeyServerStatus.online => context.loc.recoverbullConnected,
      KeyServerStatus.offline => context.loc.recoverbullFailed,
    };
  }

  Color _getStatusColor(BuildContext context) {
    return switch (status) {
      KeyServerStatus.online => context.appColors.success,
      KeyServerStatus.offline => context.appColors.error,
      KeyServerStatus.connecting ||
      KeyServerStatus.unknown => context.appColors.textMuted,
    };
  }

  IconData _getIcon() {
    return switch (status) {
      KeyServerStatus.online => Icons.check_circle,
      KeyServerStatus.offline => Icons.error,
      KeyServerStatus.connecting => Icons.hourglass_empty,
      KeyServerStatus.unknown => Icons.circle_outlined,
    };
  }
}
