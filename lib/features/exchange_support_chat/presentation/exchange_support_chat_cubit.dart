import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/exchange/data/services/exchange_notification_service.dart';
import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_log_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_message_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange_support_chat/domain/attachment_filename_sanitizer.dart';
import 'package:bb_mobile/features/exchange_support_chat/presentation/exchange_support_chat_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class ExchangeSupportChatCubit extends Cubit<ExchangeSupportChatState> {
  ExchangeSupportChatCubit({
    required this._getMessagesUsecase,
    required this._sendMessageUsecase,
    required this._getAttachmentUsecase,
    required this._getUserSummaryUsecase,
    required this._createLogAttachmentUsecase,
    required this._exchangeNotificationService,
  }) : super(const ExchangeSupportChatState()) {
    _notificationSubscription = _exchangeNotificationService.messageStream
        .where((message) => message.type == 'message')
        .listen((_) => loadMessages(page: 1));
  }

  final GetSupportChatMessagesUsecase _getMessagesUsecase;
  final SendSupportChatMessageUsecase _sendMessageUsecase;
  final GetSupportChatMessageAttachmentUsecase _getAttachmentUsecase;
  final GetExchangeUserSummaryUsecase _getUserSummaryUsecase;
  final CreateLogAttachmentUsecase _createLogAttachmentUsecase;
  final ExchangeNotificationService _exchangeNotificationService;
  StreamSubscription<NotificationMessage>? _notificationSubscription;

  bool _limitFetchingOlderMessages = false;

  Future<void> loadMessages({int? page}) async {
    emit(state.copyWith(loadingMessages: true, failure: null));

    if (state.userId == null) {
      // Best-effort: a missing user id must not block loading messages.
      try {
        final userSummary = await _getUserSummaryUsecase.execute();
        final userId = userSummary.userId;
        if (userId != null) {
          emit(state.copyWith(userId: userId));
        }
      } catch (e) {
        log.warning('Failed to resolve support chat user id', error: e);
      }
    }

    final pageToLoad = page ?? 1;
    switch (await _getMessagesUsecase.execute(page: pageToLoad, pageSize: 10)) {
      case Ok(:final value):
        final updatedMessages = pageToLoad == 1
            ? value
            : [...state.messages, ...value];
        emit(
          state.copyWith(
            messages: updatedMessages,
            loadingMessages: false,
            currentPage: pageToLoad,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(loadingMessages: false, failure: failure));
    }
  }

  Future<void> loadOlderMessages() async {
    if (state.loadingOlderMessages || _limitFetchingOlderMessages) {
      return;
    }

    _limitFetchingOlderMessages = true;
    final nextPage = state.currentPage + 1;
    emit(state.copyWith(loadingOlderMessages: true));

    switch (await _getMessagesUsecase.execute(page: nextPage, pageSize: 10)) {
      case Ok(:final value):
        if (value.isEmpty) {
          emit(state.copyWith(loadingOlderMessages: false));
        } else {
          emit(
            state.copyWith(
              messages: [...state.messages, ...value],
              loadingOlderMessages: false,
              currentPage: nextPage,
            ),
          );
        }
      case Err():
        emit(state.copyWith(loadingOlderMessages: false));
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      _limitFetchingOlderMessages = false;
    });
  }

  void updateMessageText(String text) {
    emit(state.copyWith(newMessageText: text));
  }

  Future<bool> _requestPhotoLibraryPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      if (status.isGranted) {
        return true;
      }
      if (status.isPermanentlyDenied) {
        return false;
      }
      final requestedStatus = await Permission.photos.request();
      return requestedStatus.isGranted;
    } else if (Platform.isAndroid) {
      final photosStatus = await Permission.photos.status;
      if (photosStatus.isGranted) {
        return true;
      }
      if (photosStatus.isPermanentlyDenied) {
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) {
          return true;
        }
        if (storageStatus.isPermanentlyDenied) {
          return false;
        }
        final requestedStorageStatus = await Permission.storage.request();
        return requestedStorageStatus.isGranted;
      }
      final requestedStatus = await Permission.photos.request();
      if (requestedStatus.isGranted) {
        return true;
      }
      if (requestedStatus.isPermanentlyDenied) {
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) {
          return true;
        }
        if (storageStatus.isPermanentlyDenied) {
          return false;
        }
        final requestedStorageStatus = await Permission.storage.request();
        return requestedStorageStatus.isGranted;
      }
      return false;
    }
    return true;
  }

  Future<void> addAttachment() async {
    try {
      emit(state.copyWith(failure: null));

      if (Platform.isAndroid) {
        final hasPermission = await _requestPhotoLibraryPermission();
        if (!hasPermission) {
          final photosStatus = await Permission.photos.status;
          final storageStatus = await Permission.storage.status;
          if (photosStatus.isPermanentlyDenied &&
              storageStatus.isPermanentlyDenied) {
            emit(
              state.copyWith(
                failure: const PermissionDeniedNeedsSettingsFailure(),
              ),
            );
            return;
          }
          emit(state.copyWith(failure: const PermissionDeniedFailure()));
          return;
        }
      }

      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();

      if (images.isEmpty) {
        return;
      }

      final newAttachments = <SupportChatMessageAttachment>[];

      for (final image in images) {
        final bytes = await image.readAsBytes();
        final fileName = image.name;
        final extension = fileName.split('.').last.toLowerCase();
        String fileType;

        switch (extension) {
          case 'jpg':
          case 'jpeg':
            fileType = 'image/jpeg';
            break;
          case 'png':
            fileType = 'image/png';
            break;
          case 'gif':
            fileType = 'image/gif';
            break;
          default:
            fileType = 'image/jpeg';
        }

        newAttachments.add(
          SupportChatMessageAttachment(
            attachmentId:
                'temp_attachment_${fileName}_${DateTime.now().millisecondsSinceEpoch}',
            fileName: fileName,
            fileType: fileType,
            fileSize: bytes.length,
            fileData: bytes,
            createdAt: DateTime.now(),
          ),
        );
      }

      if (newAttachments.isEmpty) return;

      emit(
        state.copyWith(
          newMessageAttachments: [
            ...state.newMessageAttachments,
            ...newAttachments,
          ],
        ),
      );
    } on Exception catch (e, st) {
      final message = e.toString().toLowerCase();
      log.warning(
        'Failed to pick support chat attachments',
        error: e,
        trace: st,
      );
      if (message.contains('permission') || message.contains('denied')) {
        emit(
          state.copyWith(failure: PermissionDeniedNeedsSettingsFailure('$e')),
        );
      } else {
        emit(state.copyWith(failure: PickFilesFailure('$e')));
      }
    } catch (e, st) {
      log.warning(
        'Failed to pick support chat attachments',
        error: e,
        trace: st,
      );
      emit(state.copyWith(failure: PickFilesFailure('$e')));
    }
  }

  void removeAttachment(String attachmentId) {
    emit(
      state.copyWith(
        newMessageAttachments: state.newMessageAttachments
            .where((att) => att.attachmentId != attachmentId)
            .toList(),
      ),
    );
  }

  Future<void> attachLogs() async {
    emit(state.copyWith(failure: null));

    switch (await _createLogAttachmentUsecase.execute()) {
      case Ok(:final value):
        emit(
          state.copyWith(
            newMessageText: 'Here are my logs',
            newMessageAttachments: [...state.newMessageAttachments, value],
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure));
    }
  }

  Future<void> downloadAttachment(String attachmentId) async {
    emit(state.copyWith(loadingAttachmentId: attachmentId, failure: null));

    switch (await _getAttachmentUsecase.execute(attachmentId)) {
      case Ok(:final value):
        if (value.fileData == null || value.fileName == null) {
          emit(
            state.copyWith(
              loadingAttachmentId: null,
              failure: const FetchFileDataFailure(),
            ),
          );
          return;
        }
        // Writing the temp file and opening the share sheet is foreign IO
        // (share_plus throws on some devices/iPad popover cases) — guard it so
        // a failure clears the spinner and surfaces a sanitized failure instead
        // of escaping as an unhandled async error and leaving a stuck spinner.
        try {
          final tempDir = await getTemporaryDirectory();
          // fileName is server-controlled input: never let it become path
          // material beyond a bare filename, or a crafted response could
          // write outside the temp directory (path traversal).
          final safeFileName = sanitizeAttachmentFileName(
            value.fileName!,
            attachmentId: attachmentId,
          );
          final tempFile = File('${tempDir.path}/$safeFileName');
          await tempFile.writeAsBytes(value.fileData!);
          final xFile = XFile(tempFile.path);
          await SharePlus.instance.share(
            ShareParams(files: [xFile], subject: value.fileName),
          );
          emit(state.copyWith(loadingAttachmentId: null));
        } catch (e, st) {
          log.warning(
            'Failed to open support chat attachment',
            error: e,
            trace: st,
          );
          emit(
            state.copyWith(
              loadingAttachmentId: null,
              failure: LoadAttachmentFailure('$e'),
            ),
          );
        }
      case Err(:final failure):
        emit(state.copyWith(loadingAttachmentId: null, failure: failure));
    }
  }

  Future<void> sendMessage() async {
    final messageText = state.newMessageText.trim();
    final attachmentsToSend = List<SupportChatMessageAttachment>.from(
      state.newMessageAttachments,
    );
    final hasAttachments = attachmentsToSend.isNotEmpty;

    if (messageText.isEmpty) {
      emit(state.copyWith(sendMessageFailure: const MessageEmptyFailure()));
      return;
    }

    emit(state.copyWith(sendingMessage: true, sendMessageFailure: null));

    final tempMessage = SupportChatMessage(
      messageId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      text: messageText.isEmpty ? null : messageText,
      fromUserId: state.userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isAdmin: false,
      attachments: attachmentsToSend,
    );

    emit(
      state.copyWith(
        messages: [tempMessage, ...state.messages],
        newMessageText: '',
        newMessageAttachments: [],
      ),
    );

    switch (await _sendMessageUsecase.execute(
      text: messageText,
      attachments: hasAttachments ? attachmentsToSend : null,
    )) {
      case Ok():
        // Don't immediately reload - let the message appear naturally.
        // The attachment might not be fully processed on the server yet.
        await Future.delayed(const Duration(seconds: 2));
        await loadMessages(page: 1);
        emit(state.copyWith(sendingMessage: false));
      case Err(:final failure):
        emit(
          state.copyWith(
            sendingMessage: false,
            sendMessageFailure: failure,
            newMessageText: messageText,
            newMessageAttachments: attachmentsToSend,
            messages: state.messages
                .where((msg) => !msg.messageId!.startsWith('temp'))
                .toList(),
          ),
        );
    }
  }

  @override
  Future<void> close() {
    _notificationSubscription?.cancel();
    return super.close();
  }
}
