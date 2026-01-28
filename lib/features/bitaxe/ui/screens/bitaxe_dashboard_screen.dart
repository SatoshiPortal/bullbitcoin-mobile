import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitaxe/presentation/bloc/bitaxe_bloc.dart';
import 'package:bb_mobile/features/bitaxe/presentation/bloc/bitaxe_event.dart';
import 'package:bb_mobile/features/bitaxe/presentation/bloc/bitaxe_state.dart';
import 'package:bb_mobile/features/bitaxe/ui/bitaxe_router.dart';
import 'package:bb_mobile/features/bitaxe/ui/widgets/mining_status_widget.dart';
import 'package:bb_mobile/features/bitaxe/ui/widgets/pool_config_widget.dart';
import 'package:bb_mobile/features/bitaxe/ui/widgets/remove_connection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BitaxeDashboardScreen extends StatefulWidget {
  const BitaxeDashboardScreen({super.key});

  @override
  State<BitaxeDashboardScreen> createState() => _BitaxeDashboardScreenState();
}

class _BitaxeDashboardScreenState extends State<BitaxeDashboardScreen> {
  BitaxeBloc? _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<BitaxeBloc>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bloc?.add(const BitaxeEvent.startPolling());
    });
  }

  @override
  void dispose() {
    _bloc?.add(const BitaxeEvent.stopPolling());
    super.dispose();
  }

  Future<void> _showRemoveConnectionDialog(BuildContext context) async {
    final confirmed = await RemoveConnectionDialog.show(context);
    if (confirmed == true && context.mounted) {
      context.read<BitaxeBloc>().add(const BitaxeEvent.removeConnection());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Bitaxe Dashboard',
          onBack: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: context.appColors.text),
            onPressed: () {
              context.read<BitaxeBloc>().add(
                const BitaxeEvent.refreshSystemInfo(),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<BitaxeBloc, BitaxeState>(
        listenWhen: (previous, current) {
          final deviceRemoved =
              previous.device != null &&
              current.device == null &&
              !current.isConnecting;
          return deviceRemoved;
        },
        listener: (context, state) {
          if (state.device == null && !state.isConnecting) {
            context.pushReplacementNamed(BitaxeRoute.connection.name);
            SnackBarUtils.showSnackBar(
              context,
              'Connection removed successfully',
            );
          }

          if (state.error != null) {
            SnackBarUtils.showSnackBar(context, state.error!.message);
            context.read<BitaxeBloc>().add(const BitaxeEvent.clearError());
          }
        },
        builder: (context, state) {
          // Show loading overlay when removing connection
          final isRemovingConnection = state.isRemovingConnection;

          if (state.device == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.device_unknown,
                    size: 64,
                    color: context.appColors.textMuted,
                  ),
                  const Gap(16),
                  BBText(
                    'No device connected',
                    style: context.font.bodyLarge,
                    color: context.appColors.textMuted,
                  ),
                ],
              ),
            );
          }

          final device = state.device!;
          final systemInfo = device.systemInfo;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(16),
                    _ConnectionStatusIndicator(
                      isConnected: device.isConnected,
                      isLoading: state.isLoadingSystemInfo,
                    ),
                    const Gap(16),
                    if (systemInfo != null) ...[
                      MiningStatusWidget(systemInfo: systemInfo),
                      const Gap(16),
                      PoolConfigWidget(systemInfo: systemInfo),
                      const Gap(16),
                      BBButton.big(
                        label: 'Identify Device',
                        onPressed: () {
                          if (!isRemovingConnection) {
                            context.read<BitaxeBloc>().add(
                              const BitaxeEvent.identifyDevice(),
                            );
                            SnackBarUtils.showSnackBar(
                              context,
                              'Device will say "Hi!" for 30 seconds',
                            );
                          }
                        },
                        bgColor: context.appColors.secondary,
                        textColor: context.appColors.onSecondary,
                        disabled: isRemovingConnection,
                      ),
                      const Gap(16),
                      BBButton.big(
                        label: isRemovingConnection
                            ? 'Removing Connection...'
                            : 'Remove Connection',
                        onPressed: () {
                          if (!isRemovingConnection) {
                            _showRemoveConnectionDialog(context);
                          }
                        },
                        bgColor: context.appColors.error,
                        textColor: context.appColors.onError,
                        disabled: isRemovingConnection,
                      ),
                    ] else ...[
                      InfoCard(
                        description:
                            'Device is offline or unreachable. Please check your connection.',
                        tagColor: context.appColors.warning,
                        bgColor: context.appColors.warningContainer,
                      ),
                    ],
                    const Gap(16),
                  ],
                ),
              ),

              // Loading overlay when removing connection
              if (isRemovingConnection)
                Container(
                  color: context.appColors.background.withValues(alpha: 0.8),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: context.appColors.primary,
                        ),
                        const Gap(16),
                        BBText(
                          'Removing connection...',
                          style: context.font.bodyLarge,
                          color: context.appColors.text,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectionStatusIndicator extends StatelessWidget {
  const _ConnectionStatusIndicator({
    required this.isConnected,
    required this.isLoading,
  });

  final bool isConnected;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.appColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.appColors.primary,
                ),
              )
            else
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected
                      ? context.appColors.success
                      : context.appColors.error,
                ),
              ),
            const Gap(12),
            Expanded(
              child: BBText(
                isLoading
                    ? 'Connecting...'
                    : isConnected
                    ? 'Connected'
                    : 'Disconnected',
                style: context.font.bodyMedium,
                color: context.appColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
