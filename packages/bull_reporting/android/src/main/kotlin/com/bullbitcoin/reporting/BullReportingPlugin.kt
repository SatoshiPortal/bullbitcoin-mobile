package com.bullbitcoin.reporting

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import io.sentry.Sentry
import io.sentry.android.core.SentryAndroid

class BullReportingPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "bullbitcoin/bull_reporting").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val dsn = call.arguments as? String
                        if (dsn.isNullOrEmpty()) {
                            result.error("invalid_dsn", "Expected a nonempty DSN.", null)
                        } else {
                            SentryAndroid.init(binding.applicationContext) { options ->
                                options.dsn = dsn
                                options.logs.isEnabled = false
                                options.metrics.isEnabled = false
                                options.isSendDefaultPii = false
                                options.isAttachThreads = false
                                options.isEnableUserInteractionBreadcrumbs = false
                                options.shutdownTimeoutMillis = 0
                            }
                            result.success(null)
                        }
                    }
                    "close" -> {
                        Sentry.close()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
