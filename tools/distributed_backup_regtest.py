#!/usr/bin/env python3
"""Isolated real Core/electrs test chain. No production RPC or funds are used."""
import argparse
import json
import socket
import subprocess
import time
from pathlib import Path

CORE = 'distributed-backup-core'
INDEX = 'distributed-backup-electrs'
NETWORK = 'distributed-backup-prototype'
ACCESS = 'distributed-backup-access'
CORE_IMAGE = 'bitcoin/bitcoin@sha256:68b927b6a2d3b019ce7655f3fd0eb9a4c7011310886ebc7890e5246c16df5ec6'
INDEX_IMAGE = 'boltz/electrs@sha256:b2949b48e92001ebd204aacdf47cc9c96fb9d22a1cbcd6e9e3e43f5fdd1327f2'
LABEL = 'bull.distributed-backup-prototype=true'
PORT = 51401


def docker(*args):
    return subprocess.check_output(['docker', *args], text=True).strip()


def owned(name):
    result = subprocess.run(['docker', 'inspect', name], capture_output=True, text=True)
    if result.returncode:
        return False
    config = json.loads(result.stdout)[0]
    if config['Config']['Labels'].get('bull.distributed-backup-prototype') != 'true':
        raise RuntimeError(f'Refusing to use unowned container {name}')
    return True


def rpc(method, *args, wallet=True):
    command = ['exec', CORE, 'bitcoin-cli', '-regtest', '-rpcuser=backup', '-rpcpassword=prototype']
    if wallet:
        command.append('-rpcwallet=fixture')
    encoded = [json.dumps(a, separators=(',', ':')) if isinstance(a, (dict, list, bool)) else str(a) for a in args]
    result = docker(*command, method, *encoded)
    try:
        return json.loads(result)
    except json.JSONDecodeError:
        return result


def electrum(method, *params):
    with socket.create_connection(('127.0.0.1', PORT), timeout=10) as stream:
        stream.sendall((json.dumps({'id': 1, 'method': method, 'params': params}) + '\n').encode())
        with stream.makefile('rb') as reader:
            response = json.loads(reader.readline(2100000))
    if response.get('error'):
        raise RuntimeError(response['error'])
    return response['result']


def start():
    if not subprocess.run(['docker', 'network', 'inspect', NETWORK], capture_output=True).returncode == 0:
        docker('network', 'create', '--internal', '--label', LABEL, NETWORK)
    if not owned(CORE):
        docker('run', '-d', '--name', CORE, '--label', LABEL, '--network', NETWORK,
               CORE_IMAGE, 'bitcoind', '-regtest', '-server=1', '-txindex=1',
               '-rpcbind=0.0.0.0', '-rpcallowip=172.16.0.0/12', '-rpcuser=backup',
               '-rpcpassword=prototype', '-fallbackfee=0.0002', '-datacarriersize=100000')
    else:
        docker('start', CORE)
    for _ in range(60):
        try:
            if rpc('getblockchaininfo', wallet=False)['chain'] == 'regtest':
                break
        except subprocess.CalledProcessError:
            time.sleep(0.5)
    else:
        raise RuntimeError('Core did not become ready')
    if 'fixture' not in rpc('listwallets', wallet=False):
        wallets = rpc('listwalletdir', wallet=False)['wallets']
        rpc('loadwallet' if any(w['name'] == 'fixture' for w in wallets) else 'createwallet', 'fixture', wallet=False)
    if rpc('getblockcount', wallet=False) < 101:
        rpc('generatetoaddress', 101, rpc('getnewaddress'))
    if not owned(INDEX):
        ip = json.loads(docker('inspect', CORE))[0]['NetworkSettings']['Networks'][NETWORK]['IPAddress']
        docker('run', '-d', '--name', INDEX, '--label', LABEL, '--network', NETWORK,
               '-p', f'127.0.0.1:{PORT}:60401', '--entrypoint', 'electrs-bitcoin', INDEX_IMAGE,
               '--network', 'regtest', '--daemon-rpc-addr', f'{ip}:18443', '--cookie', 'backup:prototype',
               '--jsonrpc-import', '--db-dir', '/tmp/index', '--electrum-rpc-addr', '0.0.0.0:60401')
    else:
        docker('start', INDEX)
    # Docker does not publish loopback ports for an internal-only container.
    if subprocess.run(['docker', 'network', 'inspect', ACCESS], capture_output=True).returncode:
        docker('network', 'create', '--label', LABEL, ACCESS)
    if ACCESS not in json.loads(docker('inspect', INDEX))[0]['NetworkSettings']['Networks']:
        docker('network', 'connect', ACCESS, INDEX)
    for _ in range(90):
        try:
            electrum('server.version', 'distributed-backup-test', '1.4')
            return
        except (OSError, ValueError, RuntimeError):
            time.sleep(0.5)
    raise RuntimeError('Electrs did not become ready')


def send(outputs):
    raw = rpc('createrawtransaction', [], outputs)
    funded = rpc('fundrawtransaction', raw)['hex']
    signed = rpc('signrawtransactionwithwallet', funded)
    if not signed['complete']:
        raise RuntimeError('Fixture signing failed')
    return rpc('sendrawtransaction', signed['hex'])


def publish(fixture_path, evidence_path):
    if Path(evidence_path).exists():
        raise RuntimeError('Evidence already exists; reuse this chain for recovery tests instead of funding the same policies again')
    start()
    fixture = json.loads(Path(fixture_path).read_text())
    if fixture['profile'] != 'distributed-backup-public-regtest-fixture-1':
        raise ValueError('Only public regtest fixtures are accepted')
    records = []
    for generation in fixture['generations']:
        # Independently verify every marker address with Bitcoin Core.
        for xpub, address in zip(fixture['xpubs'], generation['addresses']):
            descriptor = rpc('getdescriptorinfo', f'wpkh({xpub}/0/0)')['descriptor']
            if rpc('deriveaddresses', descriptor) != [address]:
                raise ValueError('Discovery address derivation mismatch')
        txid = send([{'data': generation['payload']}, *[{a: 0.00001} for a in generation['addresses']]])
        funding = send([{generation['receive']: 0.001}, {generation['change']: 0.002}])
        records.append({**generation, 'txid': txid, 'fundingTxid': funding, 'expectedBalanceSats': 300000,
                        'rawTransaction': rpc('getrawtransaction', txid, False, wallet=False)})
    rpc('generatetoaddress', 1, rpc('getnewaddress'))
    # Spend the first generation's three marker outputs with the public fixture
    # private keys, proving recovery depends on history, not current UTXOs.
    decoded = rpc('getrawtransaction', records[0]['txid'], True, wallet=False)
    markers = [v for v in decoded['vout'] if v['scriptPubKey'].get('address') in records[0]['addresses']]
    inputs = [{'txid': records[0]['txid'], 'vout': v['n']} for v in markers]
    prevouts = [{'txid': records[0]['txid'], 'vout': v['n'], 'scriptPubKey': v['scriptPubKey']['hex'], 'amount': v['value']} for v in markers]
    raw = rpc('createrawtransaction', inputs, [{rpc('getnewaddress'): 0.000025}])
    signed = rpc('signrawtransactionwithkey', raw, fixture['markerTestWifs'], prevouts)
    if not signed['complete']:
        raise RuntimeError('Marker spend signing failed')
    spend = rpc('sendrawtransaction', signed['hex'])
    rpc('generatetoaddress', 1, rpc('getnewaddress'))
    import hashlib
    for marker in markers:
        script_hash = hashlib.sha256(bytes.fromhex(marker['scriptPubKey']['hex'])).digest()[::-1].hex()
        for _ in range(60):
            history = electrum('blockchain.scripthash.get_history', script_hash)
            utxos = electrum('blockchain.scripthash.listunspent', script_hash)
            if any(t['tx_hash'] == spend for t in history):
                break
            time.sleep(0.5)
        if any(u['tx_hash'] == records[0]['txid'] for u in utxos):
            raise RuntimeError('Marker spend not indexed')
        if not all(any(t['tx_hash'] == r['txid'] for t in history) for r in records):
            raise RuntimeError('Backup history missing')
    evidence = {'profile': fixture['profile'], 'coreImage': CORE_IMAGE, 'electrsImage': INDEX_IMAGE,
                'electrumVersion': electrum('server.version', 'distributed-backup-test', '1.4'),
                'xpubs': fixture['xpubs'], 'generations': records, 'spentMarkerTransaction': spend}
    Path(evidence_path).parent.mkdir(parents=True, exist_ok=True)
    Path(evidence_path).write_text(json.dumps(evidence, indent=2) + '\n')
    print(json.dumps({'backups': [r['txid'] for r in records], 'spentMarkers': spend, 'electrumPort': PORT}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('start')
    publish_parser = sub.add_parser('publish')
    publish_parser.add_argument('fixture')
    publish_parser.add_argument('evidence')
    sub.add_parser('stop')
    args = parser.parse_args()
    if args.command == 'start':
        start()
    elif args.command == 'publish':
        publish(args.fixture, args.evidence)
    else:
        for name in (INDEX, CORE):
            if owned(name):
                docker('stop', name)


if __name__ == '__main__':
    main()
