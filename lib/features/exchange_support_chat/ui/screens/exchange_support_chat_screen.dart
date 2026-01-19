import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_log_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/exchange_notification_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_message_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange_support_chat/presentation/exchange_support_chat_cubit.dart';
import 'package:bb_mobile/features/exchange_support_chat/presentation/exchange_support_chat_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class ExchangeSupportChatScreen extends StatelessWidget {
  const ExchangeSupportChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExchangeSupportChatCubit(
        getMessagesUsecase: locator<GetSupportChatMessagesUsecase>(),
        sendMessageUsecase: locator<SendSupportChatMessageUsecase>(),
        getAttachmentUsecase: locator<GetSupportChatMessageAttachmentUsecase>(),
        getUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        createLogAttachmentUsecase: locator<CreateLogAttachmentUsecase>(),
        exchangeNotificationUsecase: locator<ExchangeNotificationUsecase>(),
      )..loadMessages(),
      child: Scaffold(
        appBar: AppBar(
          title: BBText(
            context.loc.exchangeSupportChatTitle,
            style: context.font.headlineMedium,
          ),
          backgroundColor: context.appColors.background,
        ),
        backgroundColor: context.appColors.background,
        body: const _ChatBody(),
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
                  if (state.errorPermissionDenied.isNotEmpty) {
                    SnackBarUtils.showSnackBar(
                      context,
                      state.errorPermissionDenied,
                    );
                  }
                },
                builder: (context, state) {
                  if (state.loadingMessages && state.messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.messages.isEmpty && !state.loadingMessages) {
                    return Center(
                      child: BBText(
                        context.loc.exchangeSupportChatEmptyState,
                        style: context.font.bodyLarge?.copyWith(
                          color: context.appColors.textMuted,
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
                  ? context.appColors.secondary
                  : Color.lerp(
                          context.appColors.primary,
                          context.appColors.secondaryFixed,
                          0.2,
                        ) ??
                        context.appColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: isUserMessage
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (message.text != null && message.text!.isNotEmpty)
                  BBText(
                    message.text!,
                    style: context.font.bodyMedium?.copyWith(
                      color: isUserMessage
                          ? context.appColors.onSecondary
                          : context.appColors.onPrimary,
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
                  BBText(
                    _formatTime(message.createdAt!, context),
                    style: context.font.labelSmall?.copyWith(
                      color: isUserMessage
                          ? context.appColors.textMuted
                          : context.appColors.onPrimary.withValues(alpha: 0.7),
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
          color: context.appColors.background,
          border: Border(
            top: BorderSide(
              color: context.appColors.outline.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.errorSendingMessage.isNotEmpty) ...[
              BBText(
                state.errorSendingMessage ==
                        ExchangeSupportChatCubit.errorMessageEmpty
                    ? context.loc.exchangeSupportChatMessageEmptyError
                    : state.errorSendingMessage,
                style: context.font.labelSmall?.copyWith(
                  color: context.appColors.error,
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
                  child: BBButton.big(
                    label: '',
                    iconData: Icons.attach_file,
                    disabled: false,
                    onPressed: () {
                      context.read<ExchangeSupportChatCubit>().addAttachment();
                    },
                    bgColor: context.appColors.surfaceContainer,
                    textColor: context.appColors.onSurface,
                    width: 52,
                    height: 52,
                  ),
                ),
                const Gap(8),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: BBButton.big(
                    label: '',
                    iconData: Icons.description,
                    disabled: false,
                    onPressed: () {
                      context.read<ExchangeSupportChatCubit>().attachLogs();
                    },
                    bgColor: context.appColors.surfaceContainer,
                    textColor: context.appColors.onSurface,
                    width: 52,
                    height: 52,
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: BBInputText(
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
                  child: BBButton.big(
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
                          context.appColors.primary,
                          context.appColors.secondaryFixed,
                          0.2,
                        ) ??
                        context.appColors.primary,
                    textColor: context.appColors.onPrimary,
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
                  ? context.appColors.secondary
                  : context.appColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isUserMessage
                    ? context.appColors.onSecondary
                    : context.appColors.secondary,
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
                      ? context.appColors.onSecondary
                      : context.appColors.secondary,
                ),
                const Gap(8),
                Flexible(
                  child: BBText(
                    attachment.fileName != null
                        ? _shortenFileName(attachment.fileName!)
                        : 'Image',
                    style: context.font.bodySmall?.copyWith(
                      color: isUserMessage
                          ? context.appColors.onSecondary
                          : null,
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
                      color: context.appColors.onPrimary,
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
                ? context.appColors.secondaryFixedDim
                : context.appColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isUserMessage
                  ? context.appColors.outline.withValues(alpha: 0.2)
                  : context.appColors.secondary,
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
                      ? context.appColors.onSecondary
                      : context.appColors.secondary,
                )
              else if (isLog)
                Icon(
                  Icons.description,
                  size: 30,
                  color: isUserMessage
                      ? context.appColors.onSecondary
                      : context.appColors.secondary,
                )
              else
                Icon(
                  Icons.file_present,
                  size: 30,
                  color: isUserMessage
                      ? context.appColors.onSecondary
                      : context.appColors.secondary,
                ),
              const Gap(8),
              Flexible(
                child: BBText(
                  attachment.fileName != null
                      ? _shortenFileName(attachment.fileName!)
                      : 'Unknown file',
                  style: context.font.bodySmall?.copyWith(
                    color: isUserMessage ? context.appColors.onSecondary : null,
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
                    color: context.appColors.onPrimary,
                  ),
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
            color: context.appColors.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.appColors.outline.withValues(alpha: 0.2),
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
            color: context.appColors.primary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}
