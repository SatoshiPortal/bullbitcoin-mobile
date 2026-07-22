import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/coldcard_firmware/presentation/coldcard_firmware_failure_l10n.dart';
import 'package:bb_mobile/features/coldcard_firmware/presentation/cubit/coldcard_firmware_cubit.dart';
import 'package:bb_mobile/features/coldcard_firmware/presentation/cubit/coldcard_firmware_state.dart';
import 'package:bb_mobile/features/coldcard_firmware/ui/widgets/coldcard_update_instructions_bottom_sheet.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:coldcard_firmware/coldcard_firmware.dart'
    show FirmwareRelease, trustedSignerIdentity;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
import 'package:intl/intl.dart';

class ColdcardUpdateScreen extends StatelessWidget {
  const ColdcardUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ColdcardFirmwareCubit, ColdcardFirmwareState>(
      listenWhen: (previous, current) =>
          previous.exportSucceeded != current.exportSucceeded ||
          previous.exportFailure != current.exportFailure,
      listener: (context, state) {
        final exportFailure = state.exportFailure;
        if (state.exportSucceeded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.loc.coldcardUpdateExportSuccess)),
          );
        } else if (exportFailure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(exportFailure.toTranslated(context))),
          );
        }
        context.read<ColdcardFirmwareCubit>().clearExportFlags();
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              state.model?.displayName ?? context.loc.coldcardUpdateTitle,
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: switch (state.status) {
                ColdcardFirmwareStatus.initial ||
                ColdcardFirmwareStatus.fetchingLatest => _CenteredProgress(
                  message: context.loc.coldcardUpdateCheckingLatest,
                ),
                ColdcardFirmwareStatus.latestReady => _LatestReadyView(
                  state: state,
                ),
                ColdcardFirmwareStatus.downloading => _DownloadingView(
                  state: state,
                ),
                ColdcardFirmwareStatus.verifying => _CenteredProgress(
                  message: context.loc.coldcardUpdateVerifyingSignature,
                ),
                ColdcardFirmwareStatus.verified => _VerifiedView(state: state),
                ColdcardFirmwareStatus.failure => _FailureView(state: state),
              },
            ),
          ),
        );
      },
    );
  }
}

class _CenteredProgress extends StatelessWidget {
  const _CenteredProgress({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: .center,
        children: [
          CircularProgressIndicator(color: context.appColors.primary),
          const Gap(24),
          BBText(message, style: context.font.bodyLarge),
        ],
      ),
    );
  }
}

class _LatestReadyView extends StatelessWidget {
  const _LatestReadyView({required this.state});

  final ColdcardFirmwareState state;

  @override
  Widget build(BuildContext context) {
    final release = state.latestRelease!;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const Gap(16),
        BBText(
          context.loc.coldcardUpdateLatestFirmware,
          style: context.font.bodyLarge,
          color: context.appColors.textMuted,
        ),
        const Gap(12),
        _ReleaseCard(release: release),
        const Spacer(),
        BBButton.big(
          label: context.loc.coldcardUpdateDownloadAndVerifyButton,
          onPressed: () =>
              context.read<ColdcardFirmwareCubit>().downloadAndVerify(),
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
        const Gap(24),
      ],
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release});

  final FirmwareRelease release;

  @override
  Widget build(BuildContext context) {
    final releasedAt = release.releasedAt;
    return BorderedTappableTile(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          BBText('${release.version}', style: context.font.headlineLarge),
          if (releasedAt != null) ...[
            const Gap(4),
            BBText(
              context.loc.coldcardUpdateReleasedOn(
                DateFormat.yMMMMd().format(releasedAt),
              ),
              style: context.font.bodyMedium,
              color: context.appColors.textMuted,
            ),
          ],
          const Gap(12),
          BBText(
            release.filename,
            style: context.font.bodySmall,
            color: context.appColors.textMuted,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _DownloadingView extends StatelessWidget {
  const _DownloadingView({required this.state});

  final ColdcardFirmwareState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.downloadProgress;
    final megabytes = (state.downloadedBytes / (1024 * 1024)).toStringAsFixed(
      1,
    );
    return Center(
      child: Column(
        mainAxisAlignment: .center,
        crossAxisAlignment: .stretch,
        children: [
          BBText(
            context.loc.coldcardUpdateDownloading,
            style: context.font.bodyLarge,
            textAlign: .center,
          ),
          const Gap(24),
          LinearProgressIndicator(
            value: progress,
            color: context.appColors.primary,
            backgroundColor: context.appColors.border,
            minHeight: 6,
          ),
          const Gap(12),
          BBText(
            progress != null
                ? '${(progress * 100).round()}% · $megabytes MB'
                : '$megabytes MB',
            style: context.font.bodyMedium,
            color: context.appColors.textMuted,
            textAlign: .center,
          ),
        ],
      ),
    );
  }
}

class _VerifiedView extends StatelessWidget {
  const _VerifiedView({required this.state});

  final ColdcardFirmwareState state;

  @override
  Widget build(BuildContext context) {
    final release = state.latestRelease!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          const Gap(24),
          Center(
            child: SizedBox(
              height: 160,
              width: 160,
              child: Gif(
                image: AssetImage(Assets.animations.successTick.path),
                autostart: Autostart.once,
                height: 160,
                width: 160,
              ),
            ),
          ),
          const Gap(8),
          BBText(
            context.loc.coldcardUpdateVerifiedTitle,
            style: context.font.headlineLarge,
            textAlign: .center,
          ),
          const Gap(12),
          BBText(
            context.loc.coldcardUpdateVerifiedMessage,
            style: context.font.bodyLarge,
            textAlign: .center,
            maxLines: 5,
          ),
          const Gap(16),
          BBText(
            '${release.version} · ${release.filename}',
            style: context.font.bodySmall,
            color: context.appColors.textMuted,
            textAlign: .center,
            maxLines: 2,
          ),
          const Gap(4),
          BBText(
            context.loc.coldcardUpdateSignedBy(trustedSignerIdentity),
            style: context.font.bodySmall,
            color: context.appColors.textMuted,
            textAlign: .center,
            maxLines: 2,
          ),
          const Gap(32),
          BBButton.big(
            label: context.loc.coldcardUpdateExportButton,
            disabled: state.isExporting,
            onPressed: () =>
                context.read<ColdcardFirmwareCubit>().exportFirmware(),
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
          const Gap(12),
          BBButton.big(
            label: context.loc.coldcardUpdateInstructionsButton,
            onPressed: () =>
                ColdcardUpdateInstructionsBottomSheet.show(context),
            outlined: true,
            bgColor: context.appColors.transparent,
            borderColor: context.appColors.secondary,
            textColor: context.appColors.secondary,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.state});

  final ColdcardFirmwareState state;

  @override
  Widget build(BuildContext context) {
    final failure = state.failure;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        const Spacer(),
        Icon(Icons.error_outline, size: 64, color: context.appColors.error),
        const Gap(16),
        BBText(
          failure != null
              ? failure.toTranslated(context)
              : context.loc.oopsSomethingWentWrong,
          style: context.font.bodyLarge,
          textAlign: .center,
          maxLines: 5,
        ),
        const Spacer(),
        BBButton.big(
          label: context.loc.retry,
          onPressed: () => context.read<ColdcardFirmwareCubit>().retry(),
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
        const Gap(24),
      ],
    );
  }
}
