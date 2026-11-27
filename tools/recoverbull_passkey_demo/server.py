"""Local-only, disposable WebAuthn RP. Not a RecoverBull backend."""
import base64
import json
import os
import re
import secrets
import ssl
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

from webauthn import (generate_registration_options, generate_authentication_options,
                      verify_registration_response, verify_authentication_response, options_to_json)
from webauthn.helpers.structs import (AuthenticatorSelectionCriteria, PublicKeyCredentialDescriptor,
                                     ResidentKeyRequirement, UserVerificationRequirement)

CONTENT = "Dummy RecoverBull content: no wallet, secret, or backup."
TTL_SECONDS = 120


class Demo:
    def __init__(self, rp_id, package, fingerprint):
        if not re.fullmatch(r"(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}", rp_id):
            raise ValueError("RP_ID must be a dedicated DNS hostname, not a URL")
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+", package):
            raise ValueError("ANDROID_PACKAGE must be an Android application ID")
        if not re.fullmatch(r"(?:[0-9A-F]{2}:){31}[0-9A-F]{2}", fingerprint):
            raise ValueError("ANDROID_CERT_SHA256 must be a colon-separated uppercase SHA-256 fingerprint")
        self.rp_id, self.package, self.fingerprint = rp_id, package, fingerprint
        digest = bytes.fromhex(fingerprint.replace(':', ''))
        self.origin = 'android:apk-key-hash:' + base64.urlsafe_b64encode(digest).rstrip(b'=').decode()
        self.sessions = {}
        self.accounts = {}

    def assetlinks(self):
        return [{"relation": ["delegate_permission/common.get_login_creds"], "target": {
            "namespace": "android_app", "package_name": self.package,
            "sha256_cert_fingerprints": [self.fingerprint]}}]

    def session(self, kind, options, account):
        now = time.monotonic()
        self.sessions = {k: v for k, v in self.sessions.items() if v[0] > now}
        sid = secrets.token_urlsafe(32)
        self.sessions[sid] = (now + TTL_SECONDS, kind, options.challenge, account)
        return {"sessionId": sid, "options": json.loads(options_to_json(options))}

    def consume(self, sid, kind):
        if not isinstance(sid, str):
            raise ValueError("Invalid session")
        entry = self.sessions.pop(sid, None)
        if entry is None or entry[0] <= time.monotonic() or entry[1] != kind:
            raise ValueError("Invalid or expired session")
        return entry[2], entry[3]

    def post(self, path, body):
        if not isinstance(body, dict):
            raise ValueError("Expected an object")
        if path == '/register/options':
            if body:
                raise ValueError("Expected empty object")
            account = secrets.token_urlsafe(32)
            options = generate_registration_options(
                rp_id=self.rp_id, rp_name="RecoverBull demo", user_id=secrets.token_bytes(32),
                user_name=account, authenticator_selection=AuthenticatorSelectionCriteria(
                    resident_key=ResidentKeyRequirement.REQUIRED,
                    user_verification=UserVerificationRequirement.REQUIRED))
            return self.session('register', options, account)
        if path == '/authenticate/options':
            account = body.get('accountId')
            if not isinstance(account, str) or account not in self.accounts:
                raise ValueError("Unknown account")
            cred = self.accounts[account]
            options = generate_authentication_options(
                rp_id=self.rp_id, allow_credentials=[PublicKeyCredentialDescriptor(id=cred['id'])],
                user_verification=UserVerificationRequirement.REQUIRED)
            return self.session('authenticate', options, account)
        if path in ('/register/verify', '/authenticate/verify'):
            kind = 'register' if path.startswith('/register/') else 'authenticate'
            challenge, account = self.consume(body.get('sessionId'), kind)
            credential = body.get('credential')
            if not isinstance(credential, dict):
                raise ValueError("Invalid credential")
            if kind == 'register':
                verified = verify_registration_response(credential=credential, expected_challenge=challenge,
                    expected_rp_id=self.rp_id, expected_origin=self.origin, require_user_verification=True)
                if any(c['id'] == verified.credential_id for c in self.accounts.values()):
                    raise ValueError("Credential already registered")
                self.accounts[account] = {'id': verified.credential_id, 'key': verified.credential_public_key,
                                          'count': verified.sign_count}
                return {'accountId': account}
            stored = self.accounts[account]
            # The verifier validates rawId consistency; explicitly bind it to this account.
            from webauthn import base64url_to_bytes
            if base64url_to_bytes(credential.get('rawId', '')) != stored['id']:
                raise ValueError("Credential does not belong to account")
            verified = verify_authentication_response(credential=credential, expected_challenge=challenge,
                expected_rp_id=self.rp_id, expected_origin=self.origin, require_user_verification=True,
                credential_public_key=stored['key'], credential_current_sign_count=stored['count'])
            stored['count'] = verified.new_sign_count
            return {'content': CONTENT}
        raise ValueError("Unknown endpoint")


def handler_for(demo):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            pass

        def reply(self, code, payload):
            encoded = json.dumps(payload).encode()
            self.send_response(code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(encoded)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(encoded)

        def do_GET(self):
            if self.path == '/.well-known/assetlinks.json':
                self.reply(200, demo.assetlinks())
            else:
                self.reply(404, {'error': 'not found'})

        def do_POST(self):
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= 65536 or self.headers.get_content_type() != 'application/json':
                    raise ValueError('Invalid request')
                body = json.loads(self.rfile.read(length))
                self.reply(200, demo.post(self.path, body))
            except Exception:
                self.reply(400, {'error': 'request rejected'})
    return Handler


def main():
    demo = Demo(os.environ['RP_ID'], os.environ['ANDROID_PACKAGE'], os.environ['ANDROID_CERT_SHA256'])
    server = HTTPServer(('127.0.0.1', int(os.environ.get('PORT', '8443'))), handler_for(demo))
    if os.environ.get('DEMO_LOOPBACK_HTTP') != 'true':
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(os.environ['TLS_CERT'], os.environ['TLS_KEY'])
        server.socket = context.wrap_socket(server.socket, server_side=True)
    server.serve_forever()


if __name__ == '__main__':
    main()
