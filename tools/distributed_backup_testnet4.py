#!/usr/bin/env python3
"""Publish one full-descriptor backup on testnet4 with an offline Core signer."""
import argparse
import json
import socket
import ssl
import subprocess
import urllib.request
from pathlib import Path

CONTAINER = 'distributed-backup-testnet4-core'
WALLET = 'distributed-testnet4'
LABEL = 'distributed-backup-testnet4'
IMAGE = 'bitcoin/bitcoin@sha256:68b927b6a2d3b019ce7655f3fd0eb9a4c7011310886ebc7890e5246c16df5ec6'
API = 'https://mempool.space/testnet4/api'
GENESIS = '00000000da84f2bafbbc53dee25a72ae507ff4914b867c565be350b0da8bf043'


def rpc(method, *params):
    args = [json.dumps(p) if isinstance(p, (dict, list, bool)) else str(p) for p in params]
    raw = subprocess.check_output([
        'docker', 'exec', CONTAINER, 'bitcoin-cli', '-testnet4',
        '-rpcuser=backup', '-rpcpassword=prototype', f'-rpcwallet={WALLET}',
        method, *args,
    ], text=True).strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def api(path):
    with urllib.request.urlopen(API + path, timeout=30) as response:
        raw = response.read().decode()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def verify_chain():
    info = json.loads(subprocess.check_output(['docker', 'inspect', CONTAINER], text=True))[0]
    if info['Config']['Labels'].get('bull.distributed-backup-testnet4') != 'true':
        raise ValueError('Refusing an unowned signing container')
    if rpc('getblockhash', 0) != GENESIS or api('/block-height/0') != GENESIS:
        raise ValueError('Testnet4 genesis mismatch')


def funding_address():
    addresses = rpc('getaddressesbylabel', LABEL)
    if len(addresses) != 1:
        raise ValueError('Expected one dedicated testnet4 funding address')
    address = next(iter(addresses))
    if not rpc('getaddressinfo', address)['ismine']:
        raise ValueError('Funding key is not in the dedicated signer')
    return address


def prepare(fixture_file, output):
    if Path(output).exists():
        raise ValueError('Prepared transactions already exist; reuse them')
    verify_chain()
    fixture = json.loads(Path(fixture_file).read_text())
    if fixture['profile'] != 'distributed-backup-public-testnet4-fixture-1':
        raise ValueError('Only the public testnet4 fixture is accepted')
    address = funding_address()
    coins = api(f'/address/{address}/utxo')
    coins = sorted((c for c in coins if c['value'] >= 20000), key=lambda c: c['value'])
    if not coins:
        raise ValueError(f'Fund {address} with at least 20000 testnet4 sats, then retry')
    coin = coins[0]
    raw = api(f"/tx/{coin['txid']}/hex")
    decoded = rpc('decoderawtransaction', raw)
    prev = decoded['vout'][coin['vout']]
    if (decoded['txid'] != coin['txid'] or prev['scriptPubKey'].get('address') != address
            or round(prev['value'] * 100000000) != coin['value']):
        raise ValueError('Funding transaction does not match the advertised coin')
    # Publish only the last fixture policy, in one transaction.
    generation = fixture['generations'][-1]
    if len(generation['addresses']) != 3 or len(set(generation['addresses'])) != 3:
        raise ValueError('Expected three distinct marker addresses')
    for xpub, marker in zip(fixture['xpubs'], generation['addresses'], strict=True):
        descriptor = rpc('getdescriptorinfo', f'wpkh({xpub}/0/0)')['descriptor']
        if rpc('deriveaddresses', descriptor) != [marker]:
            raise ValueError('Core disagrees with marker derivation')
    targets = [{a: 0.00001} for a in generation['addresses']]
    prevout = {'txid': decoded['txid'], 'vout': prev['n'],
               'scriptPubKey': prev['scriptPubKey']['hex'], 'amount': prev['value']}
    available = round(prev['value'] * 100000000)

    def sign(fee):
        change = available - 3000 - fee
        if change < 294:
            raise ValueError('Insufficient test coins after bounded fee and change')
        unsigned = rpc('createrawtransaction', [{'txid': prevout['txid'], 'vout': prevout['vout']}],
                       [{'data': generation['payload']}, *targets, {address: change / 100000000}])
        signed = rpc('signrawtransactionwithwallet', unsigned, [prevout])
        if not signed['complete']:
            raise ValueError('Offline Core could not sign the test transaction')
        return signed['hex'], rpc('decoderawtransaction', signed['hex'])

    _, estimate = sign(4000)
    fee = estimate['vsize'] * 2 + 2
    if fee > 4000:
        raise ValueError('Unexpected publication size; maximum fee is 4000 test sats')
    raw, transaction = sign(fee)
    if not 1 <= fee / transaction['vsize'] <= 3:
        raise ValueError('Unexpected signed transaction fee rate')
    if len(transaction['vin']) != 1 or len(transaction['vout']) != 5:
        raise ValueError('Expected one input and five outputs')
    records = [{**generation, 'txid': transaction['txid'], 'rawTransaction': raw,
                'feeSats': fee, 'vsize': transaction['vsize'], 'vaultPaymentSats': 0}]
    result = {'network': 'testnet4', 'genesis': GENESIS, 'fundingAddress': address,
              'fundingTransaction': coin['txid'], 'coreImage': IMAGE, 'xpubs': fixture['xpubs'],
              'generations': records}
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    Path(output).write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'prepared': [r['txid'] for r in records], 'totalFeeSats': sum(r['feeSats'] for r in records)}))


def broadcast(prepared):
    verify_chain()
    record = json.loads(Path(prepared).read_text())
    if (record['network'] != 'testnet4' or record['genesis'] != GENESIS
            or len(record['generations']) != 1):
        raise ValueError('Only prepared testnet4 transactions can be broadcast')
    for generation in record['generations']:
        txid = generation['txid']
        if rpc('decoderawtransaction', generation['rawTransaction'])['txid'] != txid:
            raise ValueError('Prepared transaction identity mismatch')
        with ssl.create_default_context().wrap_socket(
                socket.create_connection(('blackie.c3-soft.com', 57010), timeout=30),
                server_hostname='blackie.c3-soft.com') as stream:
            stream.sendall((json.dumps({'id': 1, 'method': 'blockchain.transaction.broadcast',
                                       'params': [generation['rawTransaction']]}) + '\n').encode())
            with stream.makefile('rb') as reader:
                response = json.loads(reader.readline(65536))
        if response.get('id') != 1 or response.get('result') != txid:
            # An already-mined transaction cannot be rebroadcast on all servers.
            # Confirm this specific txid through the independent explorer API.
            if not api(f'/tx/{txid}/status').get('confirmed'):
                raise ValueError(f'Electrum rejected {txid}: {response.get("error")}')
        print(f'https://mempool.space/testnet4/tx/{txid}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    p = commands.add_parser('prepare')
    p.add_argument('fixture')
    p.add_argument('output')
    p = commands.add_parser('broadcast')
    p.add_argument('prepared')
    args = parser.parse_args()
    if args.command == 'prepare':
        prepare(args.fixture, args.output)
    else:
        broadcast(args.prepared)


if __name__ == '__main__':
    main()
