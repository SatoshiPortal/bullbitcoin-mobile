import base64
import hashlib
import json
import unittest
from unittest.mock import patch

import cbor2
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec

from server import Demo, CONTENT, main


def b64(value):
    return base64.urlsafe_b64encode(value).rstrip(b'=').decode()


class Authenticator:
    def __init__(self, demo):
        self.demo = demo
        self.key = ec.generate_private_key(ec.SECP256R1())
        self.id = b'demo-credential'
        self.counter = 0

    def client(self, options, kind, origin=None, challenge=None):
        return json.dumps({'type': 'webauthn.' + kind, 'challenge': challenge or options['challenge'],
                           'origin': origin or self.demo.origin, 'crossOrigin': False}, separators=(',', ':')).encode()

    def registration(self, options, uv=True, origin=None, challenge=None):
        client = self.client(options, 'create', origin, challenge)
        pub = self.key.public_key().public_numbers()
        cose = cbor2.dumps({1: 2, 3: -7, -1: 1, -2: pub.x.to_bytes(32, 'big'), -3: pub.y.to_bytes(32, 'big')})
        flags = 0x41 | (0x04 if uv else 0)
        data = hashlib.sha256(self.demo.rp_id.encode()).digest() + bytes([flags]) + b'\0'*4
        data += b'\0'*16 + len(self.id).to_bytes(2, 'big') + self.id + cose
        return {'id': b64(self.id), 'rawId': b64(self.id), 'type': 'public-key', 'response': {
            'clientDataJSON': b64(client), 'attestationObject': b64(cbor2.dumps({'fmt': 'none', 'attStmt': {}, 'authData': data}))}}

    def authentication(self, options, uv=True, origin=None, challenge=None):
        self.counter += 1
        client = self.client(options, 'get', origin, challenge)
        flags = 0x01 | (0x04 if uv else 0)
        data = hashlib.sha256(self.demo.rp_id.encode()).digest() + bytes([flags]) + self.counter.to_bytes(4, 'big')
        signature = self.key.sign(data + hashlib.sha256(client).digest(), ec.ECDSA(hashes.SHA256()))
        return {'id': b64(self.id), 'rawId': b64(self.id), 'type': 'public-key', 'response': {
            'clientDataJSON': b64(client), 'authenticatorData': b64(data), 'signature': b64(signature)}}


class DemoTests(unittest.TestCase):
    def setUp(self):
        self.demo = Demo('passkey.example.com', 'com.example.debug', ':'.join(['AA']*32))
        self.auth = Authenticator(self.demo)

    def register(self):
        o = self.demo.post('/register/options', {})
        self.assertEqual(o['options']['authenticatorSelection']['userVerification'], 'required')
        return self.demo.post('/register/verify', {'sessionId': o['sessionId'], 'credential': self.auth.registration(o['options'])})['accountId']

    def test_real_crypto_roundtrip_and_replay(self):
        account = self.register()
        o = self.demo.post('/authenticate/options', {'accountId': account})
        self.assertEqual(o['options']['userVerification'], 'required')
        body = {'sessionId': o['sessionId'], 'credential': self.auth.authentication(o['options'])}
        self.assertEqual(self.demo.post('/authenticate/verify', body), {'content': CONTENT})
        with self.assertRaises(ValueError): self.demo.post('/authenticate/verify', body)

    def test_registration_rejects_uv_origin_challenge_and_consumes_session(self):
        for kwargs in ({'uv': False}, {'origin': 'https://passkey.example.com'}, {'challenge': b64(b'wrong')}):
            o = self.demo.post('/register/options', {})
            body = {'sessionId': o['sessionId'], 'credential': self.auth.registration(o['options'], **kwargs)}
            with self.assertRaises(Exception): self.demo.post('/register/verify', body)
            with self.assertRaises(ValueError): self.demo.post('/register/verify', body)

    def test_authentication_rejects_uv_origin_challenge_and_signature(self):
        account = self.register()
        for kwargs in ({'uv': False}, {'origin': 'https://passkey.example.com'}, {'challenge': b64(b'wrong')}):
            o = self.demo.post('/authenticate/options', {'accountId': account})
            body = {'sessionId': o['sessionId'], 'credential': self.auth.authentication(o['options'], **kwargs)}
            with self.assertRaises(Exception): self.demo.post('/authenticate/verify', body)
        o = self.demo.post('/authenticate/options', {'accountId': account})
        cred = self.auth.authentication(o['options'])
        cred['response']['signature'] = b64(b'bad signature')
        with self.assertRaises(Exception): self.demo.post('/authenticate/verify', {'sessionId': o['sessionId'], 'credential': cred})

    def test_expiry_and_wrong_kind(self):
        o = self.demo.post('/register/options', {})
        entry = self.demo.sessions[o['sessionId']]
        self.demo.sessions[o['sessionId']] = (0, *entry[1:])
        with self.assertRaises(ValueError): self.demo.consume(o['sessionId'], 'register')
        o = self.demo.post('/register/options', {})
        with self.assertRaises(ValueError): self.demo.consume(o['sessionId'], 'authenticate')
        with self.assertRaises(ValueError): self.demo.consume(o['sessionId'], 'register')

    def test_assetlinks_and_configuration(self):
        self.assertEqual(self.demo.assetlinks()[0]['target']['sha256_cert_fingerprints'], [':'.join(['AA']*32)])
        with self.assertRaises(ValueError): Demo('http://example.com', 'com.example', ':'.join(['AA']*32))
        with self.assertRaises(ValueError): Demo('example.com', 'com.example', 'bad')

    @patch('server.ssl.SSLContext')
    @patch('server.HTTPServer')
    def test_http_is_explicit_and_tls_has_no_fallback(self, server, context):
        env = {'RP_ID': 'passkey.example.com', 'ANDROID_PACKAGE': 'com.example.debug',
               'ANDROID_CERT_SHA256': ':'.join(['AA'] * 32)}
        with patch.dict('os.environ', {**env, 'DEMO_LOOPBACK_HTTP': 'true'}, clear=True):
            main()
        server.assert_called_with(('127.0.0.1', 8443), unittest.mock.ANY)
        context.assert_not_called()
        with patch.dict('os.environ', env, clear=True):
            with self.assertRaises(KeyError):
                main()
        context.assert_called_once_with(unittest.mock.ANY)


if __name__ == '__main__': unittest.main()
