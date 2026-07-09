import 'dart:typed_data';

import 'package:bip322/bip322.dart' as bip322;
import 'package:hex/hex.dart';
import 'package:proof_of_funds/proof_of_funds.dart';
import 'package:test/test.dart';

/// A [PrivateKeyResolver] backed by a fixed script->key map, so tests need no
/// wallet or BDK. Keys are raw 32-byte secp256k1 private keys.
class _FakeKeyResolver implements PrivateKeyResolver {
  final Map<String, Uint8List> _byScript;
  _FakeKeyResolver(this._byScript);

  @override
  Future<Uint8List> keyForScript(Uint8List scriptPubKey) async {
    final key = _byScript[HEX.encode(scriptPubKey)];
    if (key == null) {
      throw StateError('no key for script ${HEX.encode(scriptPubKey)}');
    }
    return key;
  }
}

/// A [ChainLookup] backed by a fixed outpoint->utxo map.
class _FakeChain implements ChainLookup {
  final Map<String, ChainUtxo> _byOutpoint;
  _FakeChain(this._byOutpoint);

  @override
  Future<ChainUtxo?> lookup(ProofOutpoint outpoint) async =>
      _byOutpoint['${outpoint.txId}:${outpoint.vout}'];
}

Uint8List _secret(int fill) => Uint8List.fromList(List.filled(32, fill));

final txid = '11' * 32;

/// The P2WPKH address + scriptPubKey that [key] actually controls on mainnet,
/// derived through the same library the code under test uses — so the
/// (key, address, script) triple is always internally consistent.
({String address, Uint8List script}) _p2wpkh(Uint8List key) {
  final address = bip322.Bip322.p2wpkhAddress(key);
  final parsed = bip322.parseAddress(address, bip322.Network.mainnet);
  return (
    address: address,
    script: Uint8List.fromList(parsed.scriptPubKey.bytes),
  );
}

void main() {
  const pof = ProofOfFunds();

  final key = _secret(0x01);
  late final triple = _p2wpkh(key);

  group('prove + verify round trip (offline)', () {
    test('a single P2WPKH UTXO proof verifies as valid', () async {
      final resolver = _FakeKeyResolver({HEX.encode(triple.script): key});
      final signature = await pof.prove(
        message: 'I control these funds',
        challengeAddress: triple.address,
        utxos: [
          ProofInput(
            outpoint: ProofOutpoint(txId: txid, vout: 0),
            amountSat: BigInt.from(25000),
            scriptPubKey: triple.script,
          ),
        ],
        keys: resolver,
        network: ProofNetwork.mainnet,
      );
      expect(signature.startsWith('pof'), isTrue);

      final result = await pof.verify(
        signature: signature,
        network: ProofNetwork.mainnet,
      );
      expect(result.status, ProofStatus.valid);
      expect(result.proven, hasLength(1));
      expect(result.proven.single.onChain, OnChainStatus.notChecked);
      expect(result.proven.single.outpoint.txId, txid);
      // Self-contained: message + challenge address recovered from the proof.
      expect(result.message, 'I control these funds');
      expect(result.challengeAddress, triple.address);
    });

    test('verify recovers the embedded message from the proof', () async {
      final resolver = _FakeKeyResolver({HEX.encode(triple.script): key});
      final signature = await pof.prove(
        message: 'a specific message',
        challengeAddress: triple.address,
        utxos: [
          ProofInput(
            outpoint: ProofOutpoint(txId: txid, vout: 0),
            amountSat: BigInt.from(25000),
            scriptPubKey: triple.script,
          ),
        ],
        keys: resolver,
        network: ProofNetwork.mainnet,
      );

      // Self-contained: the message is read from the proof, not supplied.
      final result = await pof.verify(
        signature: signature,
        network: ProofNetwork.mainnet,
      );
      expect(result.status, ProofStatus.valid);
      expect(result.message, 'a specific message');
    });
  });

  group('on-chain comparison', () {
    Future<String> proofFor(Map<String, Uint8List> keys) => pof.prove(
      message: 'm',
      challengeAddress: triple.address,
      utxos: [
        ProofInput(
          outpoint: ProofOutpoint(txId: txid, vout: 0),
          amountSat: BigInt.from(25000),
          scriptPubKey: triple.script,
        ),
      ],
      keys: _FakeKeyResolver(keys),
      network: ProofNetwork.mainnet,
    );

    test(
      'a valid proof whose UTXO matches on-chain and is unspent is valid',
      () async {
        final signature = await proofFor({HEX.encode(triple.script): key});
        final chain = _FakeChain({
          '$txid:0': ChainUtxo(
            scriptPubKey: triple.script,
            amountSat: BigInt.from(25000),
            unspent: true,
          ),
        });
        final result = await pof.verify(
          signature: signature,
          network: ProofNetwork.mainnet,
          chain: chain,
        );
        expect(result.status, ProofStatus.valid);
        expect(result.proven.single.onChain, OnChainStatus.confirmedUnspent);
      },
    );

    test('a spent UTXO downgrades the result to invalid', () async {
      final signature = await proofFor({HEX.encode(triple.script): key});
      final chain = _FakeChain({
        '$txid:0': ChainUtxo(
          scriptPubKey: triple.script,
          amountSat: BigInt.from(25000),
          unspent: false,
        ),
      });
      final result = await pof.verify(
        signature: signature,
        network: ProofNetwork.mainnet,
        chain: chain,
      );
      expect(result.status, ProofStatus.invalid);
      expect(result.proven.single.onChain, OnChainStatus.spent);
    });

    test('a claimed scriptPubKey/amount mismatch downgrades to invalid '
        '(forged-claim guard)', () async {
      final signature = await proofFor({HEX.encode(triple.script): key});
      // The real on-chain output pays a DIFFERENT script — the claim must
      // not be trusted.
      final chain = _FakeChain({
        '$txid:0': ChainUtxo(
          scriptPubKey: Uint8List.fromList(
            HEX.decode('0014ffffffffffffffffffffffffffffffffffffffff'),
          ),
          amountSat: BigInt.from(25000),
          unspent: true,
        ),
      });
      final result = await pof.verify(
        signature: signature,
        network: ProofNetwork.mainnet,
        chain: chain,
      );
      expect(result.status, ProofStatus.invalid);
      expect(result.proven.single.onChain, OnChainStatus.mismatchOrMissing);
    });
  });

  group('malformed and unsupported input', () {
    test('a garbled signature verifies as invalid, never throws', () async {
      final result = await pof.verify(
        signature: 'pof!!!not-base64!!!',
        network: ProofNetwork.mainnet,
      );
      expect(result.status, ProofStatus.invalid);
    });

    test('a legacy P2PKH challenge address is rejected', () async {
      expect(
        () => pof.prove(
          message: 'm',
          challengeAddress: '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2',
          utxos: const [],
          keys: _FakeKeyResolver(const {}),
          network: ProofNetwork.mainnet,
        ),
        throwsA(isA<UnsupportedScriptError>()),
      );
    });
  });
}
