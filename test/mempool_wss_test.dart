// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'dart:io';

// @Timeout(Duration(seconds: 1200))
import 'package:test/test.dart';

void main() {
  test('Open WSS And Track Address', () async {
    final webSocket = await WebSocket.connect('wss://mempool.space/api/v1/ws');
    final defaultMsg = json.encode(
      {
        'action': 'want',
        'data': ['watch-mempool', 'stats'],
      },
    );
    const trackMsg = '{"track-address":"bc1qu7pa56fy0uasly9uqlfeuvdq56wdcq85eregt3"}';
    webSocket.add(defaultMsg);
    // webSocket.add(trackMsg);
    print(defaultMsg);
    await webSocket.listen((message) {
      // webSocket.add(defaultMsg);

      print(message);
    }).asFuture();
  });
}
