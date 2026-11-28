package com.bullbitcoin.mobile

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Passkeys are enabled only for explicitly configured debug builds. */
class RecoverBullPasskeyActivity : MainActivity() {
    private var bridge: RecoverBullPasskeyBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val instance = RecoverBullPasskeyBridge(
            this, getString(R.string.recoverbull_passkey_regtest_rp_id),
        )
        bridge = instance
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.bullbitcoin.mobile/recoverbull_passkey",
        ).setMethodCallHandler(instance::handle)
    }

    override fun onDestroy() {
        bridge?.dispose()
        bridge = null
        super.onDestroy()
    }
}
