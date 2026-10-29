package com.bullbitcoin.mobile

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** One plugin instance belongs to one engine; detach stops only its own service owner. */
class CbfSyncPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: Context? = null
    private var channel: MethodChannel? = null
    private var owner: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.bullbitcoin.mobile/cbf_foreground").also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        owner?.let {
            CbfSyncService.forget(it)
            CbfSyncService.stop(it)
        }
        owner = null
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val requestedOwner = call.argument<String>("owner")
        when (call.method) {
            "start" -> {
                val appContext = context
                val title = call.argument<String>("title")
                val body = call.argument<String>("body")
                val percentage = call.argument<Int>("percentage")
                if (appContext == null || requestedOwner.isNullOrBlank() || title == null || body == null || owner != null ||
                    percentage != null && percentage !in 0..100) {
                    result.success(false)
                    return
                }
                owner = requestedOwner
                CbfSyncService.observe(requestedOwner) { reason ->
                    if (owner == requestedOwner) {
                        owner = null
                        CbfSyncService.forget(requestedOwner)
                        channel?.invokeMethod("lost", mapOf("owner" to requestedOwner, "reason" to reason))
                    }
                }
                CbfSyncService.start(appContext, requestedOwner, title, body, percentage) { started ->
                    if (!started && owner == requestedOwner) {
                        owner = null
                        CbfSyncService.forget(requestedOwner)
                    }
                    result.success(started)
                }
            }
            "renew" -> result.success(requestedOwner != null && owner == requestedOwner && CbfSyncService.renew(requestedOwner))
            "progress" -> {
                val body = call.argument<String>("body")
                val percentage = call.argument<Int>("percentage")
                if (requestedOwner != null && owner == requestedOwner && !body.isNullOrBlank() &&
                    (percentage == null || percentage in 0..100)) {
                    CbfSyncService.updateProgress(requestedOwner, body, percentage)
                }
                result.success(null)
            }
            "stop" -> {
                if (requestedOwner != null && owner == requestedOwner) {
                    owner = null
                    CbfSyncService.forget(requestedOwner)
                    CbfSyncService.stop(requestedOwner)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
