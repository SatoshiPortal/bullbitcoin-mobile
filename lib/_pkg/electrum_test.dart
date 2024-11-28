import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Works for both Bitcoin and Liquid electrum
/// electrum should be of the format:
/// ssl://[host]:[port]
/// Eg:
/// ssl://electrum.blockstream.info:50002
/// ssl://blockstream.info:465
Future<bool> isElectrumLive(String electrumUrl) async {
  try {
    final split = electrumUrl.split(':');
    final port = int.tryParse(split.last) ?? 0;
    split.removeAt(0); // removes 'ssl'
    split.removeLast(); // removes the port number
    final url = split.join(':').split('//').last; // to remove the slashes

    final Completer<bool> completer = Completer();

    final SecureSocket socket = await SecureSocket.connect(
      url,
      port,
      timeout: const Duration(seconds: 15),
    );
    final Map<String, dynamic> request = {
      'jsonrpc': '2.0',
      'id': '1',
      'method': 'server.version',
      'params': [],
    };
    socket.write('${jsonEncode(request)}\n');

    socket.listen((data) {
      final String response = String.fromCharCodes(data);
      final Map<String, dynamic> json =
          jsonDecode(response) as Map<String, dynamic>;
      if (json['id'] == '1' &&
          json['jsonrpc'] == '2.0' &&
          json['result'] is List) {
        completer.complete(true);
      } else {
        completer.complete(false);
      }
    });

    final result = await completer.future;
    socket.close();

    return result;
  } catch (e) {
    print('Error: $e');
    return false;
  }
}
