import 'package:bb_mobile/core/nostr/nostr_relay_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_event.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Descriptor profile over the shared finite Nostr relay transport.
final class DescriptorBackupRelayDatasource {
  static const maxFrameBytes = NostrRelayDatasource.maxFrameBytes;
  static const maxEvents = NostrRelayDatasource.maxEvents;
  final WebSocketChannel Function(Uri) _connect;
  final Duration timeout;

  const DescriptorBackupRelayDatasource({
    this._connect = WebSocketChannel.connect,
    this.timeout = const Duration(seconds: 15),
  });

  NostrRelayDatasource get _relay =>
      NostrRelayDatasource(connect: _connect, timeout: timeout);

  static void validateRelay(Uri uri) => NostrRelayDatasource.validateRelay(uri);

  Future<void> publish(
    DescriptorBackupEvent event,
    Uri relay,
    DescriptorBackupSession session,
  ) => _relay.publish(event.toNostrEvent(), relay, session);

  Future<({List<Map<String, dynamic>> events, bool incomplete})> fetch(
    String lookup,
    Uri relay,
    DescriptorBackupSession session,
  ) => _relay.fetch(
    {
      'kinds': [DescriptorBackupEvent.kind],
      '#d': [lookup],
    },
    relay,
    session,
  );
}
