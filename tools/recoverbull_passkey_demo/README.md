# RecoverBull passkey demo RP

Disposable, local-only proof of concept. It is **not** a RecoverBull server, authentication service, backup mechanism, or production security boundary. It accepts no user content and returns only a fixed dummy string. Accounts, public keys, counters and short-lived challenges exist only in process memory and disappear on restart. An account ID is returned only once; callers must retain it to request authentication options.

The verifier is Duo Labs' [py_webauthn 3.0.1](https://github.com/duo-labs/py_webauthn/tree/v3.0.1), pinned in `requirements.txt` (verified 2026-11-27). Its transitive dependencies are resolved by pip and are not locked. This prototype has not had a security audit or device validation. No passkey-derived encryption, recovery, persistence, rate limiting, multi-process coordination, revocation, or production deployment is provided. Do not use real backups or secrets.

## Configuration

Provide a **dedicated** DNS RP hostname under your control, a TLS certificate and private key valid for that hostname, the exact debug application ID, and the SHA-256 fingerprint of the exact debug signing certificate. Never use a production app identity or certificate. No defaults are supplied for these identity values. The Android origin is derived from the fingerprint as `android:apk-key-hash:<base64url SHA-256>` and is the only accepted client-data origin; browser origins are intentionally rejected. Both registration and authentication demand user verification. Challenges expire after two minutes and are consumed even on a failed verification.

Install the pinned dependency into an isolated Python 3.10+ environment, then configure and run locally:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
RP_ID=passkey.example.com ANDROID_PACKAGE=com.example.debug ANDROID_CERT_SHA256='AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA' TLS_CERT=/path/to/cert.pem TLS_KEY=/path/to/key.pem .venv/bin/python server.py
```

The example hostname, package and fingerprint are placeholders, not working configuration. The server listens on `127.0.0.1:8443` by default (`PORT` changes the port), using TLS unless the explicit loopback HTTP mode below is selected. For a future device test, the dedicated RP hostname must resolve to an explicitly arranged HTTPS endpoint trusted by Android, and `https://<RP_ID>/.well-known/assetlinks.json` must be served on standard HTTPS port 443 without redirects. Merely starting this local listener does not provide public DNS, trusted TLS, port forwarding, or domain ownership; those require separate authorization and configuration. The endpoint serves only the configured debug package and fingerprint with `delegate_permission/common.get_login_creds`. Do not share a real signing key with this server; only its public certificate fingerprint is needed.

For the disposable Android debug demo only, `DEMO_LOOPBACK_HTTP=true` explicitly selects HTTP on the same loopback-only listener. There is no automatic TLS fallback. Set `RP_ID=passkey-demo.ethicnology.com` and configure the exact debug application ID and signing fingerprint. The app opts in separately with `RECOVERBULL_PASSKEY_DEMO_ENABLED=true` and posts only to `http://127.0.0.1:8443` through an ADB reverse; its RP remains `https://passkey-demo.ethicnology.com`. Digital Asset Links must already be served independently over trusted HTTPS at the RP. Never use real content or secrets with this mode.

JSON endpoints are `POST /register/options` with `{}`, `POST /register/verify` with `{sessionId, credential}`, `POST /authenticate/options` with `{accountId}`, and `POST /authenticate/verify` with `{sessionId, credential}`. Errors return HTTP 400 without details. Registration options return `{sessionId, options}`, verification returns `{accountId}`; authentication options return `{sessionId, options}`, verification returns `{content}`. Credentials use WebAuthn's JSON/base64url representation.

Run the isolated tests from this directory with `.venv/bin/python -m unittest -v`. The tests synthesize ES256 WebAuthn credentials and signatures and exercise the real verifier; they are not a substitute for Android Credential Manager and Digital Asset Links validation on a device.
