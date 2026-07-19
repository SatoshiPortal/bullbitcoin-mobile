import 'package:bb_mobile/features/joinstr/data/joinstr_store.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';

class SaveJoinstrRelayUsecase {
  final JoinstrStore _store;

  SaveJoinstrRelayUsecase({required this._store});

  Future<void> execute(String relay) async {
    if (!Joinstr.isValidRelayUrl(relay)) {
      throw JoinstrException(JoinstrIssue.invalidRelayUrl, detail: relay);
    }
    await _store.saveRelay(relay);
  }
}
