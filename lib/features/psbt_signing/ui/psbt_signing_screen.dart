import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/screens/send_confirm_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/bitcoin_signer_result.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_psbt_review.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/features/psbt_signing/domain/psbt_signing_review.dart';
import 'package:bb_mobile/features/psbt_signing/presentation/psbt_signing_cubit.dart';
import 'package:bb_mobile/features/psbt_signing/presentation/psbt_signing_failure_l10n.dart';
import 'package:bb_mobile/features/psbt_signing/presentation/psbt_signing_state.dart';
import 'package:bb_mobile/features/psbt_signing/ui/psbt_policy_description.dart';
import 'package:bb_mobile/features/psbt_signing/ui/psbt_signing_router.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PsbtSigningScreen extends StatelessWidget {
  const PsbtSigningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PsbtSigningCubit, PsbtSigningState>(
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: Text(context.loc.psbtSigningTitle)),
        body: SafeArea(
          child: switch (state.step) {
            PsbtSigningStep.input => _InputView(state: state),
            PsbtSigningStep.review => _ReviewView(state: state),
            PsbtSigningStep.signed => _SignedView(
              state: state,
              walletId: context.read<PsbtSigningCubit>().walletId,
            ),
          },
        ),
      ),
    );
  }
}

class _InputView extends StatelessWidget {
  final PsbtSigningState state;

  const _InputView({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PsbtSigningCubit>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(16),
          Icon(
            Icons.draw_outlined,
            size: 56,
            color: context.appColors.secondary,
          ),
          const Gap(16),
          BullText(
            context.loc.psbtSigningIntro,
            style: context.font.bodyMedium,
            color: context.appColors.textMuted,
            textAlign: TextAlign.center,
            maxLines: 4,
          ),
          const Gap(32),
          BullPasteInput(
            text: state.input,
            hint: context.loc.psbtSigningPasteHint,
            onChanged: cubit.review,
          ),
          if (state.isReviewing) ...[
            const Gap(16),
            const BullFadingLinearProgress(trigger: true),
          ],
          if (state.failure != null) ...[
            const Gap(16),
            BullText(
              state.failure!.toTranslated(context),
              style: context.font.bodyMedium,
              color: context.appColors.error,
              textAlign: TextAlign.center,
              maxLines: 4,
            ),
          ],
          const Gap(24),
          Row(
            children: [
              Expanded(
                child: BullButton.small(
                  label: context.loc.psbtSigningScanQr,
                  onPressed: () async {
                    final psbt = await context.pushNamed<String>(
                      PsbtSigningRoute.psbtSigningScan.name,
                      pathParameters: {'walletId': cubit.walletId},
                    );
                    if (psbt != null && context.mounted) {
                      await cubit.review(psbt);
                    }
                  },
                  bgColor: context.appColors.surface,
                  textColor: context.appColors.secondary,
                  iconData: Icons.qr_code_scanner,
                  outlined: true,
                  disabled: state.isReviewing,
                ),
              ),
              const Gap(12),
              Expanded(
                child: BullButton.small(
                  label: context.loc.psbtSigningChooseFile,
                  onPressed: () => _chooseFile(context, cubit),
                  bgColor: context.appColors.surface,
                  textColor: context.appColors.secondary,
                  iconData: Icons.file_open_outlined,
                  outlined: true,
                  disabled: state.isReviewing,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _chooseFile(BuildContext context, PsbtSigningCubit cubit) async {
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['psbt', 'txt'],
        withData: false,
      );
      final file = selection?.files.singleOrNull;
      if (file == null) return;
      if (file.size > maxBitcoinPsbtTransportBytes || file.path == null) {
        throw const FormatException('PSBT file is too large or unavailable');
      }
      final bytes = await File(file.path!).readAsBytes();
      final psbt = decodeBitcoinPsbtFileBytes(bytes);
      if (!context.mounted) return;
      await cubit.review(psbt);
    } on Exception {
      if (!context.mounted) return;
      BullSnackBar.show(
        context,
        message: context.loc.psbtSigningFileReadFailed,
      );
    }
  }
}

class _ReviewView extends StatelessWidget {
  final PsbtSigningState state;

  const _ReviewView({required this.state});

  @override
  Widget build(BuildContext context) {
    final review = state.review!;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(8),
                Container(
                  alignment: Alignment.center,
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: context.appColors.secondaryFixedDim,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_user_outlined,
                    size: 24,
                    color: context.appColors.secondary,
                  ),
                ),
                const Gap(16),
                BullText(
                  context.loc.psbtSigningReviewTitle,
                  style: context.font.bodyMedium,
                  color: context.appColors.secondary,
                  textAlign: TextAlign.center,
                ),
                const Gap(4),
                BullText(
                  FormatAmount.sats(
                    review.transaction.recipientAmountSat.toInt(),
                  ),
                  style: context.font.displaySmall,
                  color: context.appColors.secondary,
                  textAlign: TextAlign.center,
                ),
                const Gap(24),
                _TransactionDetails(review: review),
                const Gap(24),
                _AuthorizationSection(review: review),
                if (!review.transactionTimingVerified) ...[
                  const Gap(12),
                  _Notice(
                    icon: Icons.schedule,
                    text: _describeTimingNotice(context, review),
                  ),
                ],
                if (state.failure != null) ...[
                  const Gap(16),
                  BullText(
                    state.failure!.toTranslated(context),
                    style: context.font.bodyMedium,
                    color: context.appColors.error,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                  ),
                ],
                const Gap(16),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: BullButton.big(
              label: context.loc.psbtSigningSignWithDevice,
              onPressed: context.read<PsbtSigningCubit>().sign,
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
              disabled: !review.canSign || state.isSigning,
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionDetails extends StatelessWidget {
  final PsbtSigningReview review;

  const _TransactionDetails({required this.review});

  @override
  Widget build(BuildContext context) {
    final transaction = review.transaction;
    return Column(
      children: [
        CommonInfoRow(
          title: context.loc.coreScreensFromLabel,
          details: BullText(
            review.wallet.displayLabel(context),
            style: context.font.bodyLarge,
            color: context.appColors.secondary,
            textAlign: TextAlign.end,
          ),
        ),
        _divider(context),
        for (final (index, output) in transaction.recipients.indexed) ...[
          CommonInfoRow(
            title: index == 0 ? context.loc.coreScreensToLabel : '',
            details: _OutputDetails(output: output),
          ),
          _divider(context),
        ],
        for (final output in transaction.walletOwnedOutputs) ...[
          CommonInfoRow(
            title: context.loc.psbtSigningWalletOutput,
            details: _OutputDetails(output: output),
          ),
          _divider(context),
        ],
        CommonInfoRow(
          title: context.loc.coreScreensNetworkFeesLabel,
          details: BullText(
            FormatAmount.sats(transaction.feeSat.toInt()),
            style: context.font.bodyLarge,
            color: context.appColors.secondary,
            textAlign: TextAlign.end,
          ),
        ),
        _divider(context),
        CommonInfoRow(
          title: context.loc.coreScreensFeeRateLabel,
          details: BullText(
            context.loc.coreScreensFeeRateValue(
              FormatAmount.satsApprox(transaction.estimatedFeeRateSatPerVbyte),
            ),
            style: context.font.bodyLarge,
            color: context.appColors.secondary,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) =>
      Container(height: 1, color: context.appColors.secondaryFixedDim);
}

class _OutputDetails extends StatelessWidget {
  final BitcoinPsbtOutputReview output;

  const _OutputDetails({required this.output});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      if (output.address case final address?)
        AddressViewer(
          address,
          style: context.font.bodyMedium,
          color: context.appColors.secondary,
          textAlign: TextAlign.end,
        )
      else
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            BullText(
              context.loc.psbtSigningNonAddressOutput,
              style: context.font.bodyMedium,
              color: context.appColors.secondary,
              textAlign: TextAlign.end,
            ),
            const Gap(2),
            BullText(
              output.scriptHex,
              style: context.font.bodySmall,
              color: context.appColors.secondary,
              textAlign: TextAlign.end,
            ),
          ],
        ),
      const Gap(2),
      BullText(
        FormatAmount.sats(output.amountSat.toInt()),
        style: context.font.bodySmall,
        color: context.appColors.textMuted,
        textAlign: TextAlign.end,
      ),
    ],
  );
}

class _AuthorizationSection extends StatefulWidget {
  final PsbtSigningReview review;

  const _AuthorizationSection({required this.review});

  @override
  State<_AuthorizationSection> createState() => _AuthorizationSectionState();
}

class _AuthorizationSectionState extends State<_AuthorizationSection> {
  var _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final root = review.policy.external.root;
    final hasDetails = root is BitcoinThresholdPolicyNode;
    return Semantics(
      button: hasDetails,
      expanded: hasDetails ? _showDetails : null,
      child: BullBorderedTile(
        onTap: hasDetails
            ? () => setState(() => _showDetails = !_showDetails)
            : null,
        backgroundColor: context.appColors.surfaceContainerHighest,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.key_outlined, color: context.appColors.secondary),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BullText(
                        context.loc.psbtSigningAuthorization,
                        style: context.font.bodySmall,
                        color: context.appColors.textMuted,
                      ),
                      const Gap(4),
                      BullText(
                        describePsbtPolicyNode(context, root, review.wallet),
                        style: context.font.bodyMedium,
                        color: context.appColors.secondary,
                      ),
                    ],
                  ),
                ),
                if (hasDetails) ...[
                  const Gap(8),
                  Icon(
                    _showDetails ? Icons.expand_less : Icons.expand_more,
                    color: context.appColors.primary,
                  ),
                ],
              ],
            ),
            if (_showDetails && root is BitcoinThresholdPolicyNode) ...[
              const Gap(12),
              for (final (index, child) in root.children.indexed) ...[
                _PsbtPolicyCondition(node: child, wallet: review.wallet),
                if (index != root.children.length - 1) const Gap(8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PsbtPolicyCondition extends StatelessWidget {
  final BitcoinPolicyNode node;
  final Wallet wallet;

  const _PsbtPolicyCondition({required this.node, required this.wallet});

  @override
  Widget build(BuildContext context) {
    final thresholdNode = node is BitcoinThresholdPolicyNode
        ? node as BitcoinThresholdPolicyNode
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: context.appColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Gap(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullText(
                describePsbtPolicyNode(context, node, wallet),
                style: context.font.bodySmall,
                color: context.appColors.secondary,
              ),
              if (thresholdNode != null) ...[
                const Gap(8),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, child)
                          in thresholdNode.children.indexed) ...[
                        _PsbtPolicyCondition(node: child, wallet: wallet),
                        if (index != thresholdNode.children.length - 1)
                          const Gap(8),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Notice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: context.appColors.textMuted),
      const Gap(8),
      Expanded(
        child: BullText(
          text,
          style: context.font.bodySmall,
          color: context.appColors.textMuted,
          maxLines: 4,
        ),
      ),
    ],
  );
}

String _describeTimingNotice(BuildContext context, PsbtSigningReview review) =>
    switch (review.blockingTimingActivation) {
      BitcoinPolicyActivation(
        type: BitcoinPolicyActivationType.absoluteBlock,
        :final value,
      ) =>
        context.loc.psbtSigningNotMineableBeforeBlock(value),
      BitcoinPolicyActivation(
        type: BitcoinPolicyActivationType.relativeBlocks,
        :final value,
      ) =>
        context.loc.psbtSigningNotMineableForBlocks(value),
      BitcoinPolicyActivation(
        type: BitcoinPolicyActivationType.absoluteTime ||
            BitcoinPolicyActivationType.relativeTime,
        :final value,
      ) =>
        context.loc.psbtSigningNotMineableBeforeTime(
          _formatTimingTimestamp(context, value),
        ),
      null => context.loc.psbtSigningTimingUnverified,
    };

String _formatTimingTimestamp(BuildContext context, int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    timestamp * Duration.millisecondsPerSecond,
    isUtc: true,
  ).toLocal();
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatFullDate(date)} '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

class _SignedView extends StatelessWidget {
  final PsbtSigningState state;
  final String walletId;

  const _SignedView({required this.state, required this.walletId});

  @override
  Widget build(BuildContext context) {
    final result = state.result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(24),
          Icon(
            Icons.check_circle,
            size: 72,
            color: context.appColors.secondary,
          ),
          const Gap(16),
          BullText(
            context.loc.psbtSigningSignedWithDeviceTitle,
            style: context.font.headlineMedium,
            color: context.appColors.secondary,
            textAlign: TextAlign.center,
          ),
          const Gap(8),
          BullText(
            switch (result.status) {
              PsbtSigningResultStatus.partial =>
                context.loc.psbtSigningPartialDescription,
              PsbtSigningResultStatus.finalizable =>
                context.loc.psbtSigningFinalDescription,
            },
            style: context.font.bodyMedium,
            color: context.appColors.textMuted,
            textAlign: TextAlign.center,
            maxLines: 4,
          ),
          const Gap(32),
          BullButton.big(
            label: context.loc.psbtSigningShowQr,
            onPressed: () => context.pushNamed(
              PsbtSigningRoute.psbtSigningQr.name,
              pathParameters: {'walletId': walletId},
              extra: result.psbt,
            ),
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
            iconData: Icons.qr_code,
          ),
          const Gap(12),
          BullButton.big(
            label: context.loc.psbtSigningCopyPsbt,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: result.psbt));
              if (!context.mounted) return;
              BullSnackBar.show(
                context,
                message: context.loc.copiedToClipboardMessage,
              );
            },
            bgColor: context.appColors.surface,
            textColor: context.appColors.secondary,
            iconData: Icons.copy,
            outlined: true,
          ),
          const Gap(12),
          Builder(
            builder: (buttonContext) => BullButton.big(
              label: context.loc.psbtSigningShareFile,
              onPressed: () => _sharePsbt(result.psbt, buttonContext),
              bgColor: context.appColors.surface,
              textColor: context.appColors.secondary,
              iconData: Icons.share_outlined,
              outlined: true,
            ),
          ),
          const Gap(24),
          TextButton(
            onPressed: context.read<PsbtSigningCubit>().edit,
            child: Text(context.loc.psbtSigningEdit),
          ),
        ],
      ),
    );
  }

  Future<void> _sharePsbt(String psbt, BuildContext context) async {
    final temporaryDirectory = await getTemporaryDirectory();
    final exportDirectory = await temporaryDirectory.createTemp('bull-psbt-');
    try {
      final file = File('${exportDirectory.path}/bull-signed.psbt');
      await file.writeAsBytes(base64.decode(psbt), flush: true);
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/psbt')],
          subject: 'bull-signed.psbt',
          sharePositionOrigin: _shareOrigin(context),
        ),
      );
    } finally {
      if (await exportDirectory.exists()) {
        await exportDirectory.delete(recursive: true);
      }
    }
  }
}

Rect _shareOrigin(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}
