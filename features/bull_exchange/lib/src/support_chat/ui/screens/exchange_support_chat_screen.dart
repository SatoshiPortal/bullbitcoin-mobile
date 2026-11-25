import 'package:exchange/exchange.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullText,
        BullInlineIconButton,
        BullInputText,
        BullShapesX,
        Gap,
        BullSnackBar,
        bullDateLocale,
        BullTypographyX;
import 'package:intl/intl.dart';

import '../../../exchange_l10n.dart';
import '../../data/attachment_picker_repository_impl.dart';
import '../../domain/usecases/create_log_attachment_usecase.dart';
import '../../domain/usecases/get_support_chat_message_attachment_usecase.dart';
import '../../domain/usecases/get_support_chat_messages_usecase.dart';
import '../../domain/usecases/open_support_chat_attachment_usecase.dart';
import '../../domain/usecases/pick_image_attachments_usecase.dart';
import '../../domain/usecases/send_support_chat_message_usecase.dart';
import '../../presentation/exchange_support_chat_failure_l10n.dart';
import '../../presentation/support_chat_bloc.dart';
import '../../presentation/support_chat_machine.dart';

class ExchangeSupportChatScreen extends StatelessWidget {
  const ExchangeSupportChatScreen({
    super.key,
    required this.exchange,
    required this.onExit,
    required this.onMessagesRead,
    this.initialMessage,
  });

  final Exchange exchange;
  final VoidCallback onExit;

  /// Called each time the newest messages have been shown to the user.
  final VoidCallback onMessagesRead;
  final String? initialMessage;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final messages = GetSupportChatMessagesUsecase(exchange: exchange);
        final send = SendSupportChatMessageUsecase(exchange: exchange);
        final pick = PickImageAttachmentsUsecase(
          repository: AttachmentPickerRepositoryImpl(),
        );
        final logs = CreateLogAttachmentUsecase();
        final open = OpenSupportChatAttachmentUsecase(
          getAttachment: GetSupportChatMessageAttachmentUsecase(
            exchange: exchange,
          ),
        );
        return SupportChatBloc(
          effects: (
            fetchPage: (page) =>
                messages.execute(page: page, pageSize: supportChatPageSize),
            send: (text, attachments) => send.execute(
              text: text,
              attachments: attachments.isEmpty ? null : attachments,
            ),
            pickImages: pick.execute,
            buildLogs: logs.execute,
            openAttachment: open.execute,
            newestShown: onMessagesRead,
          ),
          notifications: exchange.notifications,
          draft: initialMessage,
        );
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            color: context.appColors.onSurface,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                onExit();
              }
            },
          ),
          title: BullText(
            context.loc.exchangeSupportChatTitle,
            style: context.bullType.subtitle.copyWith(
              fontWeight: FontWeight.w500,
            ),
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
      context.read<SupportChatBloc>().add(const ChatOlderRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BlocConsumer<SupportChatBloc, SupportChatState>(
            listenWhen: (previous, current) =>
                previous.notice != current.notice && current.notice != null,
            listener: (context, state) {
              if (state.notice case final notice?) {
                BullSnackBar.show(
                  context,
                  message: notice.failure.toTranslated(context),
                );
              }
            },
            builder: (context, state) => switch (state.thread) {
              ChatThreadLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              ChatThreadLoadFailed(:final failure) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BullText(
                        failure.toTranslated(context),
                        style: context.bullType.body.copyWith(
                          color: context.appColors.error,
                        ),
                      ),
                      const Gap(16),
                      BullButton.secondary(
                        label: context.loc.retry,
                        onPressed: () => context.read<SupportChatBloc>().add(
                          const ChatRetryPressed(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              final ChatThreadLoaded thread => _thread(context, state, thread),
            },
          ),
        ),
        const _MessageInput(),
      ],
    );
  }

  Widget _thread(
    BuildContext context,
    SupportChatState state,
    ChatThreadLoaded thread,
  ) {
    final outgoing = state.outgoing.reversed.toList();
    if (thread.messages.isEmpty && outgoing.isEmpty) {
      return Center(
        child: BullText(
          context.loc.exchangeSupportChatEmptyState,
          style: context.bullType.body
              .copyWith(fontWeight: FontWeight.w500)
              .copyWith(color: context.appColors.textMuted),
        ),
      );
    }
    final count = outgoing.length + thread.messages.length;
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: count + (thread.startReached ? 0 : 1),
      itemBuilder: (context, index) {
        if (index < outgoing.length) {
          final message = outgoing[index];
          return _MessageBubble(
            message: SupportChatMessage(
              text: message.text,
              isAdmin: false,
              attachments: message.attachments,
            ),
            sending: message is ChatOutgoingSending,
          );
        }
        if (index < count) {
          return _MessageBubble(
            message: thread.messages[index - outgoing.length],
          );
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: switch (thread.older) {
              ChatOlderLoading() => const CircularProgressIndicator(),
              ChatOlderIdle() => BullButton.secondary(
                label: context.loc.exchangeSupportChatLoadOlder,
                onPressed: () => context.read<SupportChatBloc>().add(
                  const ChatOlderRequested(),
                ),
              ),
            },
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.sending});

  final SupportChatMessage message;

  /// Set for a message sent from this screen that the thread doesn't show
  /// yet: true while it is sent, false once the exchange accepted it.
  final bool? sending;

  @override
  Widget build(BuildContext context) {
    // The side comes from the server's sender, never from a second lookup
    // (CHAT-11).
    final isUserMessage = message.isAdmin == false;
    final sending = this.sending;

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
              borderRadius: BorderRadius.circular(context.bullShapes.card),
            ),
            child: Column(
              crossAxisAlignment: isUserMessage
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (message.text case final text? when text.isNotEmpty)
                  BullText(
                    text,
                    style: context.bullType.body.copyWith(
                      color: isUserMessage
                          ? context.appColors.onSecondary
                          : context.appColors.onPrimary,
                    ),
                  ),
                if (message.attachments case final attachments?
                    when attachments.isNotEmpty) ...[
                  if (message.text case final text? when text.isNotEmpty)
                    const Gap(8),
                  ...attachments.map(
                    (attachment) => _AttachmentWidget(
                      attachment: attachment,
                      isUserMessage: isUserMessage,
                      openable: sending == null,
                    ),
                  ),
                ],
                if (sending != null) ...[
                  const Gap(4),
                  Icon(
                    sending ? Icons.schedule : Icons.done,
                    size: 14,
                    color: context.appColors.textMuted,
                  ),
                ] else if (message.createdAt case final createdAt?) ...[
                  const Gap(4),
                  BullText(
                    _formatTime(createdAt, context),
                    style: context.bullType.caption.copyWith(
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
    final locale = bullDateLocale(context);

    if (difference.inDays == 0) {
      return DateFormat.jm(locale).format(dateTime);
    } else if (difference.inDays == 1) {
      return '${context.loc.exchangeSupportChatYesterday} ${DateFormat.jm(locale).format(dateTime)}';
    } else if (difference.inDays < 7) {
      return DateFormat.E(locale).add_jm().format(dateTime);
    } else {
      return DateFormat.MMMd(locale).add_jm().format(dateTime);
    }
  }
}

class _MessageInput extends StatelessWidget {
  const _MessageInput();

  @override
  Widget build(BuildContext context) {
    final composer = context.select(
      (SupportChatBloc bloc) => bloc.state.composer,
    );
    final bloc = context.read<SupportChatBloc>();

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
            if (composer.problem case final problem?) ...[
              BullText(
                problem.toTranslated(context),
                style: context.bullType.caption.copyWith(
                  color: context.appColors.error,
                ),
              ),
              const Gap(8),
            ],
            if (composer.attachments.isNotEmpty) ...[
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: composer.attachments.length,
                  itemBuilder: (context, index) {
                    final attachment = composer.attachments[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _AttachmentPreviewWidget(
                        attachment: attachment,
                        onRemove: () =>
                            bloc.add(ChatAttachmentRemoved(attachment)),
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
                  child: BullInlineIconButton(
                    icon: Icon(Icons.attach_file),
                    tooltip: context.loc.exchangeSupportChatAttachFileTooltip,
                    onPressed: composer.attaching is ChatAttachIdle
                        ? () => bloc.add(const ChatAttachPressed())
                        : null,
                  ),
                ),
                const Gap(8),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: BullInlineIconButton(
                    icon: Icon(Icons.description),
                    tooltip: context.loc.exchangeSupportChatAttachLogsTooltip,
                    onPressed: composer.attaching is ChatAttachIdle
                        ? () => bloc.add(
                            ChatLogsPressed(
                              context.loc.exchangeSupportChatLogDraft,
                            ),
                          )
                        : null,
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: BullInputText(
                    value: composer.text,
                    hint:
                        composer.attachments.isNotEmpty &&
                            composer.text.trim().isEmpty
                        ? context.loc.exchangeSupportChatMessageRequired
                        : context.loc.exchangeSupportChatInputHint,
                    maxLines: 4,
                    onChanged: (text) => bloc.add(ChatDraftChanged(text)),
                  ),
                ),
                const Gap(8),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: BullInlineIconButton(
                    icon: Icon(Icons.send),
                    tooltip: context.loc.exchangeSupportChatSendTooltip,
                    onPressed: composer.text.trim().isEmpty
                        ? null
                        : () => bloc.add(const ChatSendPressed()),
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
    required this.openable,
  });

  final SupportChatMessageAttachment attachment;
  final bool isUserMessage;
  final bool openable;

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
    final attachmentId = openable ? attachment.attachmentId : null;
    final isLoading = context.select(
      (SupportChatBloc bloc) =>
          attachmentId != null && bloc.state.opening.contains(attachmentId),
    );

    if (isImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: attachmentId == null
              ? null
              : () => context.read<SupportChatBloc>().add(
                  ChatOpenPressed(attachmentId),
                ),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isUserMessage
                  ? context.appColors.secondary
                  : context.appColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(context.bullShapes.card),
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
                  child: BullText(
                    attachment.fileName != null
                        ? _shortenFileName(attachment.fileName!)
                        : context.loc.exchangeSupportChatAttachmentImage,
                    style: context.bullType.label
                        .copyWith(fontWeight: FontWeight.w400)
                        .copyWith(
                          color: isUserMessage
                              ? context.appColors.onSecondary
                              : null,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isUserMessage && attachmentId != null) ...[
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
        onTap: attachmentId == null
            ? null
            : () => context.read<SupportChatBloc>().add(
                ChatOpenPressed(attachmentId),
              ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isUserMessage
                ? context.appColors.secondaryFixedDim
                : context.appColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(context.bullShapes.card),
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
                child: BullText(
                  attachment.fileName != null
                      ? _shortenFileName(attachment.fileName!)
                      : context.loc.exchangeSupportChatAttachmentUnknownFile,
                  style: context.bullType.label
                      .copyWith(fontWeight: FontWeight.w400)
                      .copyWith(
                        color: isUserMessage
                            ? context.appColors.onSecondary
                            : null,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isUserMessage && attachmentId != null) ...[
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
            borderRadius: BorderRadius.circular(context.bullShapes.card),
            border: Border.all(
              color: context.appColors.outline.withValues(alpha: 0.2),
            ),
          ),
          child: isImage && attachment.fileData != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(context.bullShapes.card),
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
