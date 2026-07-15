import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/joinstr/data/joinstr_store.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_history_entry.dart';

class JoinstrSettings {
  final String relay;
  final List<JoinstrHistoryEntry> history;

  const JoinstrSettings({required this.relay, required this.history});
}

class GetJoinstrSettingsUsecase {
  final JoinstrStore _store;

  GetJoinstrSettingsUsecase({required this._store});

  Future<JoinstrSettings> execute() async {
    final relay = await _store.getRelay();
    final history = await _store.getHistory();
    return JoinstrSettings(
      relay: relay ?? ApiServiceConstants.defaultNostrRelayUrl,
      history: history,
    );
  }
}
