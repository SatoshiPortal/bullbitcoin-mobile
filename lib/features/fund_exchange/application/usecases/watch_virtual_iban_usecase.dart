import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';

class WatchVirtualIbanUsecase {
  final RecipientsFacade _recipientsFacade;

  WatchVirtualIbanUsecase({required this._recipientsFacade});

  Stream<Result<VirtualIban, RecipientsFailure>> execute({
    required bool createIfAbsent,
  }) => _recipientsFacade.watchVirtualIbanActivation(
    createIfAbsent: createIfAbsent,
  );
}
