import '../../../exchange_l10n.dart';
import '../../presentation/secure_file_upload_bloc.dart';
import '../../domain/secure_file_upload_state.dart';
import '../../domain/secure_file_upload_event.dart';

import 'package:bull_exchange/src/presentation/exchange_failure_l10n.dart';

import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SecureFileUploadScreen extends StatelessWidget {
  const SecureFileUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SecureUploadBloc, SecureUploadState>(
      listenWhen: (previous, current) =>
          previous is! UploadDone && current is UploadDone,
      listener: (context, state) => BullSnackBar.show(
        context,
        message: context.loc.exchangeFileUploadSuccess,
      ),
      child: BullScaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: BullTopBar(
            title: context.loc.exchangeFileUploadTitle,
            onBack: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(BullSpacing.md),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_ErrorMessage(), _UploadOptionCard()],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SecureUploadBloc>().state;
    final (failure, event) = switch (state) {
      UploadStatusFailed(:final failure) => (
        failure,
        const UploadRetryPressed(),
      ),
      UploadReady(problem: final failure?) => (
        failure,
        const UploadProblemDismissed(),
      ),
      UploadStatusLoading() ||
      UploadReady() ||
      UploadBlocked() ||
      UploadPicking() ||
      UploadSending() ||
      UploadDone() => (null, null),
    };

    if (failure == null || event == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: BullSpacing.md),
      padding: const EdgeInsets.all(BullSpacing.sm),
      decoration: BoxDecoration(
        color: context.bull.error.withAlpha(26),
        borderRadius: BorderRadius.circular(context.bullShapes.card),
        border: Border.all(color: context.bull.error),
      ),
      child: Row(
        children: [
          BullIcon(BullIcons.errorOutline, color: context.bull.error, size: 20),
          const Gap(BullSpacing.xs),
          Expanded(
            child: BullText(
              failure.toTranslated(context),
              style: context.bullType.label
                  .copyWith(fontWeight: FontWeight.w400)
                  .copyWith(color: context.bull.error),
            ),
          ),
          IconButton(
            icon: BullIcon(
              event is UploadRetryPressed ? BullIcons.sync : BullIcons.close,
              color: context.bull.error,
              size: 18,
            ),
            tooltip: event is UploadRetryPressed ? context.loc.retry : null,
            onPressed: () => context.read<SecureUploadBloc>().add(event),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _UploadOptionCard extends StatelessWidget {
  const _UploadOptionCard();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SecureUploadBloc>().state;
    final (status, isLoading, isUploading) = switch (state) {
      UploadStatusLoading() || UploadDone() => (null, true, false),
      UploadStatusFailed() => (null, false, false),
      UploadReady(:final status) => (status, false, false),
      UploadBlocked(:final status) => (status, false, false),
      UploadPicking(:final account) || UploadSending(:final account) => (
        secureUploadStatusOf(account.status),
        false,
        true,
      ),
    };
    void upload() =>
        context.read<SecureUploadBloc>().add(const UploadPressed());

    final shouldIgnore = state is! UploadReady;

    return IgnorePointer(
      ignoring: shouldIgnore,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: shouldIgnore ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(BullSpacing.md),
          decoration: BoxDecoration(
            color: context.bull.surface,
            border: Border.all(
              color: context.bull.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(context.bullShapes.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BullText(
                          context.loc.exchangeFileUploadDocumentTitle,
                          style: context.bullType.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: context.bull.onSurface,
                          ),
                        ),
                        const Gap(BullSpacing.xs),
                        BullText(
                          context.loc.exchangeFileUploadInstructions,
                          style: context.bullType.label
                              .copyWith(fontWeight: FontWeight.w400)
                              .copyWith(color: context.bull.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (status != SecureUploadStatus.rejected) ...[
                    const Gap(BullSpacing.md),
                    if (isLoading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.bull.primary,
                        ),
                      )
                    else if (status != null)
                      _UploadStatusButton(
                        status: status,
                        isUploading: isUploading,
                        onPressed: upload,
                      ),
                  ],
                ],
              ),
              if (status == SecureUploadStatus.rejected) ...[
                const Gap(BullSpacing.sm),
                _RejectedStatusWithReupload(
                  isUploading: isUploading,
                  onPressed: upload,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadStatusButton extends StatelessWidget {
  const _UploadStatusButton({
    required this.status,
    required this.isUploading,
    required this.onPressed,
  });

  final SecureUploadStatus status;
  final bool isUploading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SecureUploadStatus.upload:
        return InkWell(
          onTap: isUploading ? null : onPressed,
          borderRadius: BorderRadius.circular(context.bullShapes.button),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BullSpacing.sm,
              vertical: BullSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.bullShapes.button),
              color: context.bull.surfaceContainerHighest,
            ),
            child: isUploading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.bull.primary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 20,
                        color: context.bull.onSurface,
                      ),
                      const Gap(BullSpacing.xxs),
                      BullText(
                        context.loc.exchangeFileUploadButton,
                        style: context.bullType.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.bull.onSurface,
                        ),
                      ),
                    ],
                  ),
          ),
        );

      case SecureUploadStatus.inReview:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BullSpacing.sm,
            vertical: BullSpacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.bullShapes.badge),
            border: Border.all(
              color: context.bull.warning.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: BullText(
            context.loc.exchangeFileUploadStatusInReview,
            style: context.bullType.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: context.bull.warning,
            ),
          ),
        );

      case SecureUploadStatus.accepted:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BullSpacing.sm,
            vertical: BullSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: context.bull.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(context.bullShapes.badge),
          ),
          child: BullText(
            context.loc.exchangeFileUploadStatusAccepted,
            style: context.bullType.caption.copyWith(
              color: context.bull.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

      case SecureUploadStatus.rejected:
        return const SizedBox.shrink();

      case SecureUploadStatus.unknown:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BullSpacing.sm,
            vertical: BullSpacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.bullShapes.badge),
            border: Border.all(
              color: context.bull.outline.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: BullText(
            context.loc.exchangeFileUploadStatusUnknown,
            style: context.bullType.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: context.bull.onSurface,
            ),
          ),
        );
    }
  }
}

class _RejectedStatusWithReupload extends StatelessWidget {
  const _RejectedStatusWithReupload({
    required this.isUploading,
    required this.onPressed,
  });

  final bool isUploading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BullSpacing.xs,
            vertical: BullSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: context.bull.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(context.bullShapes.badge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BullIcon(
                BullIcons.errorOutline,
                size: 14,
                color: context.bull.error,
              ),
              const Gap(BullSpacing.xxs),
              BullText(
                context.loc.exchangeFileUploadStatusRejectedBadge,
                style: context.bullType.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.bull.error,
                ),
              ),
            ],
          ),
        ),
        const Gap(BullSpacing.sm),
        InkWell(
          onTap: isUploading ? null : onPressed,
          borderRadius: BorderRadius.circular(context.bullShapes.button),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BullSpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.bullShapes.button),
              color: context.bull.surfaceContainerHighest,
            ),
            child: isUploading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.bull.primary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 20,
                        color: context.bull.onSurface,
                      ),
                      const Gap(BullSpacing.xs),
                      BullText(
                        context.loc.exchangeFileUploadTapToReupload,
                        style: context.bullType.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.bull.onSurface,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
