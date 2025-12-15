import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/tor/tor_status.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/password_input_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/vault_provider_selection_page.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';

class ConnectingPage extends StatelessWidget {
  const ConnectingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecoverBullBloc, RecoverBullState>(
      listenWhen:
          (previous, current) =>
              previous.torStatus != current.torStatus ||
              previous.keyServerStatus != current.keyServerStatus,
      listener: (context, state) {
        if (state.torStatus == TorStatus.online &&
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
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: BlocBuilder<RecoverBullBloc, RecoverBullState>(
            builder: (context, state) {
              final torOnline = state.torStatus == TorStatus.online;
              final serverOnline =
                  state.keyServerStatus == KeyServerStatus.online;
              final hasError =
                  state.torStatus == TorStatus.offline ||
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
                    status: state.torStatus,
                    isKeyServer: false,
                  ),
                  const Gap(12),
                  _StatusRow(
                    label: context.loc.recoverbullRecoverBullServer,
                    status: state.keyServerStatus,
                    isKeyServer: true,
                  ),
                  const Gap(40),
                  if (hasError) ...[
                    BBText(
                      state.error?.toTranslated(context) ??
                          context.loc.recoverbullConnectionFailed,
                      textAlign: .center,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.error,
                      ),
                      maxLines: 3,
                    ),
                    const Gap(24),
                    BBButton.big(
                      label: context.loc.recoverbullRetry,
                      textStyle: context.font.headlineLarge,
                      bgColor: context.appColors.onSurface,
                      textColor: context.appColors.surface,
                      onPressed: () {
                        context.read<RecoverBullBloc>()
                          ..add(const OnTorInitialization())
                          ..add(const OnServerCheck());
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
  final dynamic status;
  final bool isKeyServer;

  const _StatusRow({
    required this.label,
    required this.status,
    required this.isKeyServer,
  });

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
    if (isKeyServer) {
      return switch (status as KeyServerStatus) {
        KeyServerStatus.unknown => context.loc.recoverbullWaiting,
        KeyServerStatus.connecting => context.loc.recoverbullConnecting,
        KeyServerStatus.online => context.loc.recoverbullConnected,
        KeyServerStatus.offline => context.loc.recoverbullFailed,
      };
    } else {
      return switch (status as TorStatus) {
        TorStatus.unknown => context.loc.recoverbullWaiting,
        TorStatus.connecting => context.loc.recoverbullConnecting,
        TorStatus.online => context.loc.recoverbullConnected,
        TorStatus.offline => context.loc.recoverbullFailed,
      };
    }
  }

  Color _getStatusColor(BuildContext context) {
    final statusEnum =
        isKeyServer ? (status as KeyServerStatus) : (status as TorStatus);

    return switch (statusEnum.toString().split('.').last) {
      'online' => context.appColors.success,
      'offline' => context.appColors.error,
      'connecting' => context.appColors.textMuted,
      _ => context.appColors.textMuted,
    };
  }

  IconData _getIcon() {
    final statusEnum =
        isKeyServer ? (status as KeyServerStatus) : (status as TorStatus);

    return switch (statusEnum.toString().split('.').last) {
      'online' => Icons.check_circle,
      'offline' => Icons.error,
      'connecting' => Icons.hourglass_empty,
      _ => Icons.circle_outlined,
    };
  }
}
