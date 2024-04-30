// import 'dart:async';
// import 'dart:convert';

// import 'package:boltz_dart/src/types/supported_pair.dart';
// import 'package:boltz_dart/src/types/swap.dart';
// import 'package:boltz_dart/src/types/swap_status_response.dart';
// import 'package:dio/dio.dart';
// import 'package:web_socket_channel/io.dart';

// final String mainnetBaseUrl = 'api.boltz.exchange';
// final String testnetBaseUrl = 'api.testnet.boltz.exchange';

// class BoltzAppi {
//   final Dio _dio;

//   IOWebSocketChannel? channel;
//   StreamController<SwapStreamStatus>? _broadcastController;
//   StreamSubscription? _channelSubscription;

//   BoltzAppi._(this._dio);

//   void initialize(String baseUrl) {
//     // print('initialize');
//     channel = IOWebSocketChannel.connect(wssProtocolCheck('$baseUrl/v2/ws'));
//     // Initialize the broadcast controller
//     _broadcastController = StreamController<SwapStreamStatus>.broadcast();

//     // Listen to the channel's stream once and distribute the data
//     _channelSubscription = channel!.stream.listen((msg) {
//       // Parse the message and add it to the broadcast controller
//       final resp = jsonDecode(msg);
//       if (resp['error'] != null) {
//         _broadcastController!.add(
//           SwapStreamStatus(
//             id: '',
//             status: SwapStatus.swapError,
//             error: resp['error'],
//           ),
//         );
//       } else if (resp['event'] == 'update') {
//         final swapList = resp['args'];
//         for (final swap in swapList) {
//           if (swap['error'] == null) {
//             // print(swap);
//             _broadcastController!.add(SwapStreamStatus.fromJson(swap));
//           } else {
//             _broadcastController!.add(SwapStreamStatus(
//                 id: swap['id'],
//                 status: SwapStatus.swapError,
//                 error: swap['error']));
//           }
//         }
//       }
//     }, onError: (error) {
//       _broadcastController!.addError(error);
//     });
//   }

//   Stream<SwapStreamStatus> subscribeSwapStatus(List<String> swapIds) {
//     // Ensure payload is sent whenever this function is called, to subscribe to new swap IDs
//     Map<String, dynamic> payload = {
//       'op': 'subscribe',
//       'channel': 'swap.update',
//       'args': swapIds
//     };
//     channel!.sink.add(jsonEncode(payload));

//     // Return the broadcast stream
//     return _broadcastController!.stream;
//   }

//   void dispose() {
//     _channelSubscription?.cancel();
//     _broadcastController?.close();
//   }

//   static Future<BoltzAppi> newBoltzApi(String boltzUrl) async {
//     try {
//       final dio = Dio(
//         BaseOptions(
//           baseUrl: httpProtocolCheck(boltzUrl),
//         ),
//       );
//       BoltzAppi api = BoltzAppi._(dio);
//       api.initialize(boltzUrl);
//       return api;
//     } catch (e) {
//       rethrow;
//     }
//   }

//   Future<String> getBackendVersion() async {
//     try {
//       final res = await _dio.get('/version');
//       return res.data['version'];
//     } catch (e) {
//       rethrow;
//     }
//   }

//   Future<List<SupportedPair>> getSupportedPairs() async {
//     try {
//       final res = await _dio.get('/getpairs');
//       final List<SupportedPair> list = [];

//       final Map<String, dynamic> pairs = res.data['pairs'];
//       for (String key in pairs.keys) {
//         pairs[key]['name'] = key;
//         SupportedPair pair = SupportedPair.fromJson(pairs[key]);
//         list.add(pair);
//       }

//       return list;
//     } catch (e) {
//       rethrow;
//     }
//   }

//   Future<SwapStatusResponse> getSwapStatus(String swapId) async {
//     try {
//       final res = await _dio.post('/swapstatus', data: {'id': swapId});
//       return res.data as SwapStatusResponse;
//     } catch (e) {
//       rethrow;
//     }
//   }

//   bool isSwapStatusChannelOpen() {
//     return channel != null;
//   }

//   // void createSwapStatusChannel() {
//   //   channel = IOWebSocketChannel.connect('wss://api.testnet.boltz.exchange/v2/ws');
//   // }

//   // /// Update can be called multiple times to update the swapIds list
//   // Stream<SwapStatusResponse> updateSwapStatusChannel(List<String> swapIds) async* {
//   //   try {
//   //     if (channel == null) {
//   //       throw Exception('Channel not created');
//   //     }
//   //     Map<String, dynamic> payload = {'op': 'subscribe', 'channel': 'swap.update', 'args': swapIds};

//   //     channel!.sink.add(jsonEncode(payload));

//   //     await for (final msg in channel!.stream) {
//   //       // print(msg);
//   //       final resp = jsonDecode(msg);
//   //       if (resp['error'] != null) {
//   //         yield SwapStatusResponse(id: '', status: SwapStatus.swapError, error: resp['error']);
//   //       } else if (resp['event'] == 'update') {
//   //         final swapList = resp['args'];
//   //         for (final swap in swapList) {
//   //           if (swap['error'] == null) {
//   //             yield SwapStatusResponse.fromJson(swap);
//   //             // channel!.sink.close();
//   //           } else {
//   //             yield SwapStatusResponse(id: swap['id'], status: SwapStatus.swapError, error: swap['error']);
//   //             channel!.sink.close();
//   //           }
//   //         }
//   //       }
//   //     }
//   //   } catch (e) {
//   //     rethrow;
//   //   }
//   // }

//   // void closeSwapStatusChannel() {
//   //   if (channel == null) {
//   //     throw Exception('Channel not created');
//   //   }
//   //   channel?.sink.close();
//   //   channel = null;
//   // }

//   // Stream<SwapStatusResponse> getSwapStatusStreamMultiple(List<String> swapIds) async* {
//   //   try {
//   //     final channel = IOWebSocketChannel.connect('wss://api.testnet.boltz.exchange/v2/ws');
//   //     // Map<String, dynamic> payload = {'channel': 'swap.update', 'args': swapIds};
//   //     // Map<String, dynamic> payload = {'op': 'subscribe', 'args': swapIds};
//   //     // Map<String, dynamic> payload = {'op': 'subscribe', 'channel': 'swap.update'};
//   //     // Map<String, dynamic> payload = {'op': 'subscribe', 'channel': 'swap.update', 'args': swapIds[0]};
//   //     // Map<String, dynamic> payload = {'op': 'subscribe', 'channel': 'swap.update', 'args': swapIds, 'extra': 'param'};
//   //     Map<String, dynamic> payload = {'op': 'subscribe', 'channel': 'swap.update', 'args': swapIds};

//   //     channel.sink.add(jsonEncode(payload));

//   //     await for (final msg in channel.stream) {
//   //       final resp = jsonDecode(msg);
//   //       if (resp['error'] != null) {
//   //         yield SwapStatusResponse(id: '', status: SwapStatus.swapError, error: resp['error']);
//   //       } else if (resp['event'] == 'update') {
//   //         final swapList = resp['args'];
//   //         for (final swap in swapList) {
//   //           if (swap['error'] == null) {
//   //             yield SwapStatusResponse.fromJson(swap);
//   //             channel.sink.close();
//   //           } else {
//   //             yield SwapStatusResponse(id: swap['id'], status: SwapStatus.swapError, error: swap['error']);
//   //             channel.sink.close();
//   //           }
//   //         }
//   //       }
//   //     }
//   //   } catch (e) {
//   //     rethrow;
//   //   }
//   // }

//   // Stream<SwapStatusResponse> getSwapStatusStream(String swapId,
//   //     {Duration timeoutDuration = const Duration(minutes: 30)}) async* {
//   //   try {
//   //     Response<dynamic> rs = await _dio
//   //         .get('/streamswapstatus?id=$swapId',
//   //             options: Options(headers: {
//   //               "Accept": "text/event-stream",
//   //               "Cache-Control": "no-cache",
//   //             }, responseType: ResponseType.stream))
//   //         .timeout(timeoutDuration);

//   //     StreamTransformer<Uint8List, List<int>> unit8Transformer = StreamTransformer.fromHandlers(
//   //       handleData: (data, sink) {
//   //         sink.add(List<int>.from(data));
//   //       },
//   //     );

//   //     await for (var line in (rs.data!.stream as Stream)
//   //         .timeout(timeoutDuration, onTimeout: (EventSink<dynamic> sink) {
//   //           sink.close();
//   //         })
//   //         .transform(unit8Transformer)
//   //         .transform(const Utf8Decoder())
//   //         .transform(const LineSplitter())) {
//   //       // print('event: $line');

//   //       if (line.startsWith('data: ')) {
//   //         var jsonString = line.substring(6);
//   //         var jsonMap = json.decode(jsonString) as Map<String, dynamic>;
//   //         jsonMap['id'] = swapId;
//   //         SwapStatusResponse resp = SwapStatusResponse.fromJson(jsonMap);
//   //         print(DateTime.now());
//   //         print(resp);
//   //         yield resp;
//   //       }
//   //     }
//   //   } catch (e) {
//   //     rethrow;
//   //   }
//   // }
// }

// String httpProtocolCheck(String url) {
//   const List<String> protocols = ['http://', 'https://'];
//   for (var protocol in protocols) {
//     if (url.startsWith(protocol)) {
//       return url;
//     }
//   }
//   return 'https://$url';
// }

// String wssProtocolCheck(String url) {
//   // Define the WebSocket protocols and HTTP protocols
//   const List<String> wsProtocols = ['wss://', 'ws://'];
//   const List<String> httpProtocols = ['http://', 'https://'];

//   // First, remove any http or https protocol if present
//   for (var protocol in httpProtocols) {
//     if (url.startsWith(protocol)) {
//       url = url.substring(protocol.length);
//       break;
//     }
//   }

//   // Now check if the url starts with any WebSocket protocol
//   for (var protocol in wsProtocols) {
//     if (url.startsWith(protocol)) {
//       return url;
//     }
//   }

//   // If no WebSocket protocol is present, prepend 'wss://'
//   return 'wss://$url';
// }
