import 'package:bb_mobile/core/ark/ark.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
        flexibleSpace: TopBar(
          title: context.loc.arkAboutTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            _CopyField(label: context.loc.arkAboutServerUrl, value: Ark.server),
            const SizedBox(height: 18),
            _SecretKeyField(
              label: context.loc.arkAboutSecretKey,
              value: wallet.secretHex,
            ),
            const SizedBox(height: 18),
            _CopyField(
              label: context.loc.arkAboutServerPubkey,
              value: serverInfo.signerPubkey,
            ),
            const SizedBox(height: 18),
            _CopyField(
              label: context.loc.arkAboutForfeitAddress,
              value: serverInfo.forfeitAddress,
            ),
            const SizedBox(height: 18),
            _InfoField(label: context.loc.arkAboutNetwork, value: Ark.network),
            const SizedBox(height: 18),
            _InfoField(
              label: context.loc.arkAboutDust,
              value: context.loc.arkAboutDustValue(serverInfo.dust),
            ),
            const SizedBox(height: 18),
            _InfoField(
              label: context.loc.arkAboutSessionDuration,
              value: _formatDuration(context, serverInfo.sessionDuration),
            ),
            const SizedBox(height: 18),
            _InfoField(
              label: context.loc.arkAboutBoardingExitDelay,
              value: _formatDuration(context, serverInfo.boardingExitDelay),
            ),
            const SizedBox(height: 18),
            _InfoField(
              label: context.loc.arkAboutUnilateralExitDelay,
              value: _formatDuration(context, serverInfo.unilateralExitDelay),
            ),
            const SizedBox(height: 18),
            _CopyField(
              label: context.loc.arkAboutEsploraUrl,
              value: Ark.esplora,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(BuildContext context, dynamic seconds) {
    if (seconds == null) return 'N/A';
    final int secs = seconds is int ? seconds : (seconds as BigInt).toInt();

    if (secs < 60) {
      return context.loc.arkAboutDurationSeconds(secs);
    } else if (secs < 3600) {
      final minutes = (secs / 60).round();
      return minutes == 1
          ? context.loc.arkAboutDurationMinute(minutes)
          : context.loc.arkAboutDurationMinutes(minutes);
    } else if (secs < 86400) {
      final hours = (secs / 3600).round();
      return hours == 1
          ? context.loc.arkAboutDurationHour(hours)
          : context.loc.arkAboutDurationHours(hours);
    } else {
      final days = (secs / 86400).round();
      return days == 1
          ? context.loc.arkAboutDurationDay(days)
          : context.loc.arkAboutDurationDays(days);
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
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(4),
        BBText(
          value,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _CopyField extends StatefulWidget {
  final String label;
  final String value;
  const _CopyField({required this.label, required this.value});

  @override
  State<_CopyField> createState() => _CopyFieldState();
}

class _CopyFieldState extends State<_CopyField> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          widget.label,
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            BBText(
              widget.value,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),

            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.loc.arkAboutCopiedMessage(widget.label),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BBText(
                    context.loc.arkAboutCopy,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.primary,
                      fontSize: 14,
                    ),
                  ),
                  const Gap(4),
                  Icon(Icons.copy, size: 16, color: context.appColors.primary),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SecretKeyField extends StatefulWidget {
  final String label;
  final String value;
  const _SecretKeyField({required this.label, required this.value});

  @override
  State<_SecretKeyField> createState() => _SecretKeyFieldState();
}

class _SecretKeyFieldState extends State<_SecretKeyField> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          widget.label,
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            BBText(
              _isVisible ? widget.value : '••••••••••••••••••••••••••••••••',
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
                fontFamily: _isVisible ? null : 'monospace',
              ),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  _isVisible = !_isVisible;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BBText(
                    _isVisible
                        ? context.loc.arkAboutHide
                        : context.loc.arkAboutShow,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.primary,
                      fontSize: 14,
                    ),
                  ),
                  const Gap(4),
                  Icon(
                    _isVisible ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                    color: context.appColors.primary,
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.loc.arkAboutCopiedMessage(widget.label),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BBText(
                    context.loc.arkAboutCopy,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.primary,
                      fontSize: 14,
                    ),
                  ),
                  const Gap(4),
                  Icon(Icons.copy, size: 16, color: context.appColors.primary),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
