import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Wallet transaction scenarios served by [ElectrumFixture]. Each has a first
/// chain state, synced as a new wallet would, and a second one to sync next.
const electrumFixtureScenarios = [
  'S1-reorg-reconfirmed',
  'S2-seen-before-tip',
  'S3-reorg-evicts-to-mempool',
  'S4-deep-reorg',
  'S5-incoming-older-revealed',
  'S6-incoming-last-revealed',
  'S7-incoming-unrevealed-in-gap',
  'S8-outgoing-spend',
  'S9-mempool-then-confirmed',
  'S10-no-change',
];

/// What one scenario phase serves: txids by name and, for transactions that
/// touch a wallet script, the expected `confirmed@height:hash8` or `mempool`.
typedef FixturePhase = ({Map<String, String> ids, Map<String, String> truth});

/// Requests the client made since the previous [ElectrumFixture.requests].
typedef FixtureRequests = ({
  Map<String, int> counts,
  Set<String> scriptHashes,
  Set<String> fetchedTxids,
});

/// Loopback Electrum server on a synthetic testnet chain: linked headers with
/// real merkle roots (no proof of work) and real transactions. It runs in its
/// own isolate because the BDK client blocks its caller until it gets a reply.
final class ElectrumFixture {
  final Isolate _isolate;
  final SendPort _commands;
  final int port;

  ElectrumFixture._(this._isolate, this._commands, this.port);

  /// [scripts] maps `ext0`..`ext5`, `int0`..`int2` to the wallet's script
  /// pubkeys in hex. `ext3` and above must stay unrevealed for S7.
  static Future<ElectrumFixture> start(Map<String, String> scripts) async {
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(_serve, [ready.sendPort, scripts]);
    final [commands as SendPort, port as int] = await ready.first as List;
    return ElectrumFixture._(isolate, commands, port);
  }

  String get url => 'tcp://127.0.0.1:$port';

  Future<FixturePhase> load(String scenario, int phase) async {
    final reply = await _call(['load', scenario, phase]) as List;
    return (
      ids: (reply[0] as Map).cast<String, String>(),
      truth: (reply[1] as Map).cast<String, String>(),
    );
  }

  Future<FixtureRequests> requests() async {
    final reply = await _call(['requests']) as List;
    return (
      counts: (reply[0] as Map).cast<String, int>(),
      scriptHashes: (reply[1] as Set).cast<String>(),
      fetchedTxids: (reply[2] as Set).cast<String>(),
    );
  }

  void close() => _isolate.kill(priority: Isolate.immediate);

  Future<Object?> _call(List<Object?> command) async {
    final reply = ReceivePort();
    _commands.send([...command, reply.sendPort]);
    final result = await reply.first;
    if (result is StateError) throw result;
    return result;
  }

  static Future<void> _serve(List<Object?> args) async {
    final ready = args[0] as SendPort;
    final chain = _Chain((args[1] as Map).cast<String, String>());
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((socket) {
      utf8.decoder.bind(socket).transform(const LineSplitter()).listen((line) {
        final request = jsonDecode(line);
        final response = request is List
            ? request.map((r) => chain.answer(r as Map)).toList()
            : chain.answer(request as Map);
        socket.write('${jsonEncode(response)}\n');
      }, onError: (_) => socket.destroy());
    });
    final commands = ReceivePort();
    commands.listen((message) {
      final command = message as List;
      final reply = command.last as SendPort;
      try {
        reply.send(switch (command[0]) {
          'load' => chain.load(command[1] as String, command[2] as int),
          'requests' => chain.takeRequests(),
          _ => StateError('unknown command ${command[0]}'),
        });
      } catch (error) {
        reply.send(StateError('fixture: $error'));
      }
    });
    ready.send([commands.sendPort, server.port]);
  }
}

final class _Chain {
  final Map<String, String> scripts;
  Map<String, Uint8List> txs = {};
  List<List<String>> blocks = [[]];
  List<Uint8List> headers = [_genesis];
  List<String> mempool = [];
  int? snapshot;
  Map<String, int> counts = {};
  Set<String> scriptHashes = {};
  Set<String> fetchedTxids = {};

  _Chain(Map<String, String> walletScripts)
    : scripts = {...walletScripts, 'foreign': '0014${'ab' * 20}'};

  List<Object> takeRequests() {
    final taken = [counts, scriptHashes, fetchedTxids];
    counts = {};
    scriptHashes = {};
    fetchedTxids = {};
    return taken;
  }

  Map<String, Object?> answer(Map request) {
    final method = request['method'] as String;
    final params = (request['params'] as List?) ?? const [];
    final id = request['id'];
    counts[method] = (counts[method] ?? 0) + 1;
    Map<String, Object?> error(int code, String message) => {
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message},
    };
    final tip = headers.length - 1;
    final Object? result;
    switch (method) {
      case 'server.version':
        result = ['wallet-sync-fixture', '1.4'];
      case 'server.ping':
        result = null;
      case 'blockchain.headers.subscribe':
        final height = snapshot ?? tip;
        snapshot = null;
        result = {'height': height, 'hex': _hex(headers[height])};
      case 'blockchain.block.header':
        result = _hex(headers[params[0] as int]);
      case 'blockchain.block.headers':
        final start = params[0] as int;
        final selected = headers.skip(start).take(params[1] as int).toList();
        result = {
          'count': selected.length,
          'hex': selected.map(_hex).join(),
          'max': 2016,
        };
      case 'blockchain.scripthash.get_history':
        final hash = params[0] as String;
        scriptHashes.add(hash);
        final script = scripts.values
            .where((s) => _rhex(_sha256(_bytes(s))) == hash)
            .firstOrNull;
        result = script == null ? [] : _history(script);
      case 'blockchain.transaction.get':
        final txid = params[0] as String;
        fetchedTxids.add(txid);
        final raw = txs[txid];
        if (raw == null) return error(-5, 'No such transaction');
        result = _hex(raw);
      case 'blockchain.transaction.get_merkle':
        final txid = params[0] as String;
        final height = params[1] as int;
        final ids = height < blocks.length ? blocks[height] : const <String>[];
        final index = ids.indexOf(txid);
        if (index < 0) return error(1, 'tx not in block');
        result = {
          'block_height': height,
          'merkle': _merkle(ids, index).branch,
          'pos': index,
        };
      default:
        return error(-32601, 'unsupported $method');
    }
    return {'jsonrpc': '2.0', 'id': id, 'result': result};
  }

  List<Object> load(String scenario, int phase) {
    final s = scripts;
    final foreign = s['foreign'] as String;
    String spk(String name) => s[name] ?? (throw StateError('no $name'));
    final p = _tx([('11' * 32, 0)], [(500000, foreign)], 'P');
    final t1 = _tx(
      [(_txid(p), 0)],
      [(100000, spk('ext0')), (390000, foreign)],
      'T1',
    );
    final p2 = _tx([('22' * 32, 0)], [(60000, foreign)], 'P2');
    final p3 = _tx([('33' * 32, 0)], [(40000, foreign)], 'P3');
    final p4 = _tx([('44' * 32, 0)], [(30000, foreign)], 'P4');
    // T2 pays an older revealed address, T3 the last revealed one, T4 an
    // unrevealed address inside the gap; T5 spends the wallet's T1:0.
    final t2 = _tx([(_txid(p2), 0)], [(50000, spk('ext1'))], 'T2');
    final t3 = _tx([(_txid(p3), 0)], [(30000, spk('ext2'))], 'T3');
    final t4 = _tx([(_txid(p4), 0)], [(20000, spk('ext5'))], 'T4');
    final t5 = _tx([(_txid(t1), 0)], [(90000, foreign)], 'T5');
    final named = {
      'P': p,
      'P2': p2,
      'P3': p3,
      'P4': p4,
      'T1': t1,
      'T2': t2,
      'T3': t3,
      'T4': t4,
      'T5': t5,
    };
    final ids = {for (final e in named.entries) e.key: _txid(e.value)};
    txs = {for (final raw in named.values) _txid(raw): raw};
    String id(String name) => ids[name] ?? (throw StateError('no $name'));

    // Several transactions in block 1 exercise real merkle branches.
    final b1 = [id('P'), id('P2'), id('P3'), id('P4')];
    var base = [
      b1,
      [id('T1')],
      <String>[],
      <String>[],
    ];
    List<List<String>> empty(int n) => List.generate(n, (_) => <String>[]);
    mempool = [];
    snapshot = null;
    if (phase == 0) {
      if (scenario == 'S2-seen-before-tip') snapshot = 1;
      if (scenario == 'S4-deep-reorg') {
        base = [
          b1,
          [],
          [id('T1')],
          [],
        ];
      }
      if (scenario == 'S9-mempool-then-confirmed') mempool = [id('T2')];
      _build(base, '0${'A' * 10}');
    } else {
      switch (scenario) {
        case 'S1-reorg-reconfirmed' || 'S2-seen-before-tip':
          _build([
            b1,
            [id('T1')],
            ...empty(20),
          ], '0A${'B' * 30}');
        case 'S3-reorg-evicts-to-mempool':
          _build([b1, ...empty(4)], '0A${'B' * 30}');
          mempool = [id('T1')];
        case 'S4-deep-reorg':
          _build([
            b1,
            [],
            [],
            [id('T1')],
            [],
            [],
          ], '0AA${'B' * 30}');
        case 'S5-incoming-older-revealed' || 'S9-mempool-then-confirmed':
          _build([
            ...base,
            [id('T2')],
          ], '0${'A' * 10}');
        case 'S6-incoming-last-revealed':
          _build([
            ...base,
            [id('T3')],
          ], '0${'A' * 10}');
        case 'S7-incoming-unrevealed-in-gap':
          _build([
            ...base,
            [id('T4')],
          ], '0${'A' * 10}');
        case 'S8-outgoing-spend':
          _build([
            ...base,
            [id('T5')],
          ], '0${'A' * 10}');
        case 'S10-no-change':
          _build(base, '0${'A' * 10}');
        default:
          throw StateError('unknown scenario $scenario');
      }
    }

    final walletScripts = [
      for (final e in s.entries)
        if (e.key != 'foreign') e.value,
    ];
    final truth = <String, String>{};
    for (final MapEntry(key: name, value: txid) in ids.entries) {
      final raw = txs[txid];
      if (raw == null || !walletScripts.any((w) => _touches(raw, w))) continue;
      final height = _heightOf(txid);
      if (height != null) {
        final hash = _rhex(_sha256d(headers[height]));
        truth[name] = 'confirmed@$height:${hash.substring(0, 8)}';
      } else if (mempool.contains(txid)) {
        truth[name] = 'mempool';
      }
    }
    return [ids, truth];
  }

  void _build(List<List<String>> confirmed, String branch) {
    blocks = [[], ...confirmed];
    headers = [_genesis];
    for (var h = 1; h <= confirmed.length; h++) {
      final tag = h < branch.length ? branch[h] : branch[branch.length - 1];
      final ids = confirmed[h - 1].isNotEmpty
          ? confirmed[h - 1]
          : [sha256.convert(utf8.encode('empty-$h-$tag')).toString()];
      headers.add(
        _header(
          _sha256d(headers.last),
          _merkle(ids, 0).root,
          1296688602 + h * 600,
          h * 100 + tag.codeUnitAt(0),
        ),
      );
    }
  }

  int? _heightOf(String txid) {
    for (var h = 0; h < blocks.length; h++) {
      if (blocks[h].contains(txid)) return h;
    }
    return null;
  }

  List<Map<String, Object>> _history(String script) {
    final entries = <({String txid, int height})>[];
    for (final MapEntry(key: txid, value: raw) in txs.entries) {
      final height = _heightOf(txid);
      if (height == null && !mempool.contains(txid)) continue;
      if (_touches(raw, script)) entries.add((txid: txid, height: height ?? 0));
    }
    entries.sort((a, b) {
      final byPool = (a.height == 0 ? 1 : 0) - (b.height == 0 ? 1 : 0);
      if (byPool != 0) return byPool;
      final byHeight = a.height - b.height;
      return byHeight != 0 ? byHeight : a.txid.compareTo(b.txid);
    });
    return [
      for (final e in entries) {'tx_hash': e.txid, 'height': e.height},
    ];
  }

  bool _touches(Uint8List raw, String script) {
    final (inputs, outputs) = _parse(raw);
    if (outputs.any((o) => o.$2 == script)) return true;
    for (final (txid, vout) in inputs) {
      final parent = txs[txid];
      if (parent != null && _parse(parent).$2[vout].$2 == script) return true;
    }
    return false;
  }
}

final _genesis = _header(
  Uint8List(32),
  _reversed(
    _bytes('4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b'),
  ),
  1296688602,
  414098458,
);

Uint8List _header(Uint8List prev, Uint8List merkle, int time, int nonce) {
  final b = BytesBuilder()
    ..add(_u32(1))
    ..add(prev)
    ..add(merkle)
    ..add(_u32(time))
    ..add(_u32(0x1d00ffff))
    ..add(_u32(nonce));
  return b.toBytes();
}

/// Legacy serialization; [tag] fills the script sig so every tx is unique.
Uint8List _tx(
  List<(String, int)> inputs,
  List<(int, String)> outputs,
  String tag,
) {
  final b = BytesBuilder()
    ..add(_u32(2))
    ..addByte(inputs.length);
  for (final (txid, vout) in inputs) {
    final sig = utf8.encode(tag);
    b
      ..add(_reversed(_bytes(txid)))
      ..add(_u32(vout))
      ..addByte(sig.length)
      ..add(sig)
      ..add(_u32(0xffffffff));
  }
  b.addByte(outputs.length);
  for (final (sats, script) in outputs) {
    final spk = _bytes(script);
    b
      ..add(_u64(sats))
      ..addByte(spk.length)
      ..add(spk);
  }
  b.add(_u32(0));
  return b.toBytes();
}

(List<(String, int)>, List<(int, String)>) _parse(Uint8List raw) {
  final data = ByteData.sublistView(raw);
  var i = 4;
  final inputs = <(String, int)>[];
  final inputCount = raw[i++];
  for (var n = 0; n < inputCount; n++) {
    final txid = _rhex(raw.sublist(i, i + 32));
    final vout = data.getUint32(i + 32, Endian.little);
    i += 36;
    i += raw[i] + 1 + 4;
    inputs.add((txid, vout));
  }
  final outputs = <(int, String)>[];
  final outputCount = raw[i++];
  for (var n = 0; n < outputCount; n++) {
    final sats = data.getInt64(i, Endian.little);
    i += 8;
    final length = raw[i++];
    outputs.add((sats, _hex(raw.sublist(i, i + length))));
    i += length;
  }
  return (inputs, outputs);
}

({Uint8List root, List<String> branch}) _merkle(List<String> txids, int index) {
  var layer = [for (final t in txids) _reversed(_bytes(t))];
  final branch = <String>[];
  var position = index;
  while (layer.length > 1) {
    if (layer.length.isOdd) layer.add(layer.last);
    branch.add(_rhex(layer[position ^ 1]));
    layer = [
      for (var i = 0; i < layer.length; i += 2)
        _sha256d(Uint8List.fromList([...layer[i], ...layer[i + 1]])),
    ];
    position ~/= 2;
  }
  return (root: layer.first, branch: branch);
}

String _txid(Uint8List raw) => _rhex(_sha256d(raw));

Uint8List _sha256(List<int> b) => Uint8List.fromList(sha256.convert(b).bytes);

Uint8List _sha256d(List<int> b) => _sha256(_sha256(b));

Uint8List _u32(int v) =>
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();

Uint8List _u64(int v) =>
    (ByteData(8)..setInt64(0, v, Endian.little)).buffer.asUint8List();

Uint8List _bytes(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

Uint8List _reversed(Uint8List b) => Uint8List.fromList(b.reversed.toList());

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

String _rhex(List<int> b) => _hex(b.reversed.toList());
