import 'package:bb_mobile/core/ark/ark.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/ark/presentation/cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ArkAboutPage extends StatelessWidget {
  const ArkAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ArkCubit>();
    final wallet = cubit.wallet;
    final serverInfo = wallet.serverInfo;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: TopBar(title: 'About', onBack: () => context.pop()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            const _CopyField(label: 'Server URL', value: Ark.server),
            const SizedBox(height: 18),
            _CopyField(label: 'Server pubkey', value: serverInfo.pk),
            const SizedBox(height: 18),
            _CopyField(
              label: 'Forfeit address',
              value: serverInfo.forfeitAddress,
            ),
            const SizedBox(height: 18),
            const _InfoField(label: 'Network', value: Ark.network),
            const SizedBox(height: 18),
            _InfoField(label: 'Dust', value: '${serverInfo.dust} SATS'),
            const SizedBox(height: 18),
            _InfoField(
              label: 'Session duration',
              value: _formatDuration(serverInfo.roundInterval),
            ),
            const SizedBox(height: 18),
            _InfoField(
              label: 'Boarding exit delay',
              value: _formatDuration(serverInfo.boardingExitDelay),
            ),
            const SizedBox(height: 18),
            _InfoField(
              label: 'Unilateral exit delay',
              value: _formatDuration(serverInfo.unilateralExitDelay),
            ),
            const SizedBox(height: 18),
            const _CopyField(label: 'Esplora URL', value: Ark.esplora),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(dynamic seconds) {
    if (seconds == null) return 'N/A';
    final int secs = seconds is int ? seconds : (seconds as BigInt).toInt();

    if (secs < 60) {
      return '$secs seconds';
    } else if (secs < 3600) {
      final minutes = (secs / 60).round();
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    } else if (secs < 86400) {
      final hours = (secs / 3600).round();
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    } else {
      final days = (secs / 86400).round();
      return '$days ${days == 1 ? 'day' : 'days'}';
    }
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final String value;
  const _InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          label,
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.surfaceContainer,
          ),
        ),
        const Gap(4),
        BBText(
          value,
          style: context.font.bodyMedium?.copyWith(
            color: context.colour.outline,
          ),
        ),
      ],
    );
  }
}

class _CopyField extends StatelessWidget {
  final String label;
  final String value;
  const _CopyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          label,
          style: context.font.bodyLarge?.copyWith(
            color: context.colour.surfaceContainer,
          ),
        ),
        const Gap(4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            BBText(
              value,
              style: context.font.bodyMedium?.copyWith(
                color: context.colour.outline,
              ),
            ),

            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied to clipboard'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BBText(
                    'Copy',
                    style: context.font.bodyMedium?.copyWith(
                      color: context.colour.primary,
                      fontSize: 14,
                    ),
                  ),
                  const Gap(4),
                  Icon(Icons.copy, size: 16, color: context.colour.primary),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
