import 'package:bb_mobile/core/exchange/data/services/exchange_notification_service.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_log_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_message_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/exchange_support_chat/presentation/exchange_support_chat_cubit.dart';
import 'package:bb_mobile/features/exchange_support_chat/presentation/exchange_support_chat_state.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExchangeSupportChatScreen extends StatelessWidget {
  const ExchangeSupportChatScreen({
    super.key,
    this.fromExchange = false,
    this.initialMessage,
  });

  final bool fromExchange;
  final String? initialMessage;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = ExchangeSupportChatCubit(
          getMessagesUsecase: locator<GetSupportChatMessagesUsecase>(),
          sendMessageUsecase: locator<SendSupportChatMessageUsecase>(),
          getAttachmentUsecase:
              locator<GetSupportChatMessageAttachmentUsecase>(),
          getUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
          createLogAttachmentUsecase: locator<CreateLogAttachmentUsecase>(),
          exchangeNotificationService: locator<ExchangeNotificationService>(),
        );
        if (initialMessage case final message? when message.isNotEmpty) {
          cubit.updateMessageText(message);
        }
        cubit.loadMessages();
        return cubit;
      },
      child: BullPage(
        padding: EdgeInsets.zero,
        topBar: BullTopBar(
          title: context.loc.exchangeSupportChatTitle,
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else if (fromExchange) {
              context.goNamed(ExchangeRoute.exchangeHome.name);
            } else {
              context.goNamed(WalletRoute.walletHome.name);
            }
          },
        ),
        child: const _ChatBody(),
      ),
    );
  }
}

class _ChatBody extends StatefulWidget {
  const _ChatBody();

  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> {
  final ScrollController _scrollController = ScrollController();
  bool _hasLoadedInitialMessages = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      final cubit = context.read<ExchangeSupportChatCubit>();
      final state = cubit.state;
      if (!state.loadingOlderMessages &&
          !state.loadingMessages &&
          _hasLoadedInitialMessages) {
        cubit.loadOlderMessages();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child:
              BlocConsumer<ExchangeSupportChatCubit, ExchangeSupportChatState>(
                listener: (context, state) {
                  final code = state.errorCode;
                  if (code != null) {
                    SnackBarUtils.showSnackBar(
                      context,
                      _supportChatErrorMessage(context, code),
                    );
                  }
                },
                builder: (context, state) {
                  if (state.loadingMessages && state.messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.messages.isEmpty && !state.loadingMessages) {
                    return Center(
                      child: BullText(
                        context.loc.exchangeSupportChatEmptyState,
                        style: context.bullText.bodyLarge?.copyWith(
                          color: context.bull.textMuted,
                        ),
                      ),
                    );
                  }

                  if (!_hasLoadedInitialMessages &&
                      !state.loadingMessages &&
                      state.messages.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _hasLoadedInitialMessages = true;
                    });
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        state.messages.length +
                        (state.loadingOlderMessages ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final message = state.messages[index];
                      return _MessageBubble(message: message);
                    },
                  );
                },
              ),
        ),
        const _MessageInput(),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportChatMessage message;

  @override
  Widget build(BuildContext context) {
    final userId = context.select(
      (ExchangeSupportChatCubit cubit) => cubit.state.userId,
    );
    final fromUserId = message.fromUserId;
    final isTempMessage = message.messageId?.startsWith('temp') ?? false;
    final isUserMessage = isTempMessage
        ? true
        : fromUserId != null && userId != null && fromUserId == userId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUserMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUserMessage
                  ? context.bull.secondary
                  : Color.lerp(
                          context.bull.primary,
                          context.bull.secondaryFixed,
                          0.2,
                        ) ??
                        context.bull.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: isUserMessage
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (message.text != null && message.text!.isNotEmpty)
                  BullText(
                    message.text!,
                    style: context.bullText.bodyMedium?.copyWith(
                      color: isUserMessage
                          ? context.bull.onSecondary
                          : context.bull.onPrimary,
                    ),
                  ),
                if (message.attachments != null &&
                    message.attachments!.isNotEmpty) ...[
                  if (message.text != null && message.text!.isNotEmpty)
                    const Gap(8),
                  ...message.attachments!.map(
                    (attachment) => _AttachmentWidget(
                      attachment: attachment,
                      isUserMessage: isUserMessage,
                    ),
                  ),
                ],
                if (message.createdAt != null) ...[
                  const Gap(4),
                  BullText(
                    _formatTime(message.createdAt!, context),
                    style: context.bullText.labelSmall?.copyWith(
                      color: isUserMessage
                          ? context.bull.textMuted
                          : context.bull.onPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime, BuildContext context) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return '${context.loc.exchangeSupportChatYesterday} ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE HH:mm').format(dateTime);
    } else {
      return DateFormat('MMM dd, HH:mm').format(dateTime);
    }
  }
}

class _MessageInput extends StatefulWidget {
  const _MessageInput();

  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ExchangeSupportChatCubit>().state;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: context.bull.background,
          border: Border(
            top: BorderSide(color: context.bull.outline.withValues(alpha: 0.2)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.errorSendingMessage.isNotEmpty) ...[
              BullText(
                state.errorSendingMessage ==
                        ExchangeSupportChatCubit.errorMessageEmpty
                    ? context.loc.exchangeSupportChatMessageEmptyError
                    : state.errorSendingMessage,
                style: context.bullText.labelSmall?.copyWith(
                  color: context.bull.error,
                ),
              ),
              const Gap(8),
            ],
            if (state.newMessageAttachments.isNotEmpty) ...[
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.newMessageAttachments.length,
                  itemBuilder: (context, index) {
                    final attachment = state.newMessageAttachments[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _AttachmentPreviewWidget(
                        attachment: attachment,
                        onRemove: () {
                          if (attachment.attachmentId != null) {
                            context
                                .read<ExchangeSupportChatCubit>()
                                .removeAttachment(attachment.attachmentId!);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const Gap(8),
            ],
            Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: BullButton.big(
                    label: '',
                    iconData: Icons.attach_file,
                    disabled: false,
                    onPressed: () {
                      context.read<ExchangeSupportChatCubit>().addAttachment();
                    },
                    bgColor: context.bull.surfaceContainer,
                    textColor: context.bull.onSurface,
                    width: 52,
                    height: 52,
                  ),
                ),
                const Gap(8),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: BullButton.big(
                    label: '',
                    iconData: Icons.description,
                    disabled: false,
                    onPressed: () {
                      context.read<ExchangeSupportChatCubit>().attachLogs();
                    },
                    bgColor: context.bull.surfaceContainer,
                    textColor: context.bull.onSurface,
                    width: 52,
                    height: 52,
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: BullInputText(
                    value: state.newMessageText,
                    hint:
                        state.newMessageAttachments.isNotEmpty &&
                            state.newMessageText.trim().isEmpty
                        ? context.loc.exchangeSupportChatMessageRequired
                        : context.loc.exchangeSupportChatInputHint,
                    maxLines: 4,
                    onChanged: (text) {
                      context
                          .read<ExchangeSupportChatCubit>()
                          .updateMessageText(text);
                    },
                  ),
                ),
                const Gap(8),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: BullButton.big(
                    label: '',
                    iconData: Icons.send,
                    disabled:
                        state.sendingMessage ||
                        state.newMessageText.trim().isEmpty,
                    onPressed: () {
                      context.read<ExchangeSupportChatCubit>().sendMessage();
                    },
                    bgColor:
                        Color.lerp(
                          context.bull.primary,
                          context.bull.secondaryFixed,
                          0.2,
                        ) ??
                        context.bull.primary,
                    textColor: context.bull.onPrimary,
                    width: 52,
                    height: 52,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentWidget extends StatelessWidget {
  const _AttachmentWidget({
    required this.attachment,
    required this.isUserMessage,
  });

  final SupportChatMessageAttachment attachment;
  final bool isUserMessage;

  String _shortenFileName(String fileName) {
    if (fileName.length <= 20) return fileName;
    final extension = fileName.split('.').last;
    final nameWithoutExt = fileName.substring(
      0,
      fileName.length - extension.length - 1,
    );
    if (nameWithoutExt.length <= 15) return fileName;
    return '${nameWithoutExt.substring(0, 15)}...$extension';
  }

  @override
  Widget build(BuildContext context) {
    final isImage = attachment.fileType?.startsWith('image/') ?? false;
    final isPdf = attachment.fileType == 'application/pdf';
    final isLog = attachment.fileName?.contains('.BullLog.') ?? false;
    final isLoading = context.select(
      (ExchangeSupportChatCubit cubit) =>
          cubit.state.loadingAttachmentId == attachment.attachmentId,
    );

    if (isImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap:
              attachment.attachmentId == null ||
                  attachment.attachmentId!.startsWith('temp')
              ? null
              : () {
                  context.read<ExchangeSupportChatCubit>().downloadAttachment(
                    attachment.attachmentId!,
                  );
                },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isUserMessage
                  ? context.bull.secondary
                  : context.bull.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isUserMessage
                    ? context.bull.onSecondary
                    : context.bull.secondary,
                width: isUserMessage ? 1 : 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image,
                  size: 30,
                  color: isUserMessage
                      ? context.bull.onSecondary
                      : context.bull.secondary,
                ),
                const Gap(8),
                Flexible(
                  child: BullText(
                    attachment.fileName != null
                        ? _shortenFileName(attachment.fileName!)
                        : context.loc.exchangeSupportChatAttachmentImage,
                    style: context.bullText.bodySmall?.copyWith(
                      color: isUserMessage ? context.bull.onSecondary : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isUserMessage &&
                    attachment.attachmentId != null &&
                    !attachment.attachmentId!.startsWith('temp')) ...[
                  const Gap(8),
                  if (isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.download,
                      size: 20,
                      color: context.bull.onPrimary,
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap:
            attachment.attachmentId == null ||
                attachment.attachmentId!.startsWith('temp')
            ? null
            : () {
                context.read<ExchangeSupportChatCubit>().downloadAttachment(
                  attachment.attachmentId!,
                );
              },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isUserMessage
                ? context.bull.secondaryFixedDim
                : context.bull.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isUserMessage
                  ? context.bull.outline.withValues(alpha: 0.2)
                  : context.bull.secondary,
              width: isUserMessage ? 1 : 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPdf)
                Icon(
                  Icons.picture_as_pdf,
                  size: 30,
                  color: isUserMessage
                      ? context.bull.onSecondary
                      : context.bull.secondary,
                )
              else if (isLog)
                Icon(
                  Icons.description,
                  size: 30,
                  color: isUserMessage
                      ? context.bull.onSecondary
                      : context.bull.secondary,
                )
              else
                Icon(
                  Icons.file_present,
                  size: 30,
                  color: isUserMessage
                      ? context.bull.onSecondary
                      : context.bull.secondary,
                ),
              const Gap(8),
              Flexible(
                child: BullText(
                  attachment.fileName != null
                      ? _shortenFileName(attachment.fileName!)
                      : context.loc.exchangeSupportChatAttachmentUnknownFile,
                  style: context.bullText.bodySmall?.copyWith(
                    color: isUserMessage ? context.bull.onSecondary : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isUserMessage &&
                  attachment.attachmentId != null &&
                  !attachment.attachmentId!.startsWith('temp')) ...[
                const Gap(8),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.download, size: 20, color: context.bull.onPrimary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentPreviewWidget extends StatelessWidget {
  const _AttachmentPreviewWidget({
    required this.attachment,
    required this.onRemove,
  });

  final SupportChatMessageAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isImage = attachment.fileType?.startsWith('image/') ?? false;
    final isPdf = attachment.fileType == 'application/pdf';
    final isLog = attachment.fileName?.contains('.BullLog.') ?? false;

    return Stack(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: context.bull.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.bull.outline.withValues(alpha: 0.2),
            ),
          ),
          child: isImage && attachment.fileData != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    attachment.fileData!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image),
                  ),
                )
              : isPdf
              ? const Icon(Icons.picture_as_pdf)
              : isLog
              ? const Icon(Icons.description)
              : const Icon(Icons.file_present),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: IconButton(
            icon: const Icon(Icons.cancel, size: 20),
            color: context.bull.primary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}

String _supportChatErrorMessage(
  BuildContext context,
  SupportChatErrorCode code,
) => switch (code) {
  SupportChatErrorCode.permissionDenied =>
    context.loc.exchangeSupportChatPermissionDenied,
  SupportChatErrorCode.permissionDeniedNeedsSettings =>
    context.loc.exchangeSupportChatPermissionDeniedSettings,
  SupportChatErrorCode.pickFilesFailed =>
    context.loc.exchangeSupportChatPickFilesFailed,
  SupportChatErrorCode.attachLogsFailed =>
    context.loc.exchangeSupportChatAttachLogsFailed,
  SupportChatErrorCode.fetchFileDataFailed =>
    context.loc.exchangeSupportChatFetchFileDataFailed,
};
