package com.bullbitcoin.mobile

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Adds validated/metered capabilities to the app's existing connectivity_plus observations. */
class CbfNetworkPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var manager: ConnectivityManager? = null
    private var channel: MethodChannel? = null
    private var registered = false
    private val main = Handler(Looper.getMainLooper())
    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
            publish(capabilities)
        }
        override fun onLost(network: Network) {
            channel?.invokeMethod("changed", read())
        }
        override fun onUnavailable() {
            channel?.invokeMethod("changed", mapOf("available" to false, "metered" to null))
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        manager = binding.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        channel = MethodChannel(binding.binaryMessenger, "com.bullbitcoin.mobile/cbf_network").also {
            it.setMethodCallHandler(this)
        }
        try {
            manager?.registerDefaultNetworkCallback(callback, main)
            registered = true
        } catch (_: RuntimeException) {
            registered = false
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (registered) manager?.unregisterNetworkCallback(callback)
        registered = false
        channel?.setMethodCallHandler(null)
        channel = null
        manager = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "read") result.success(read()) else result.notImplemented()
    }

    private fun read(): Map<String, Any?> {
        val connectivity = manager ?: return mapOf("available" to false, "metered" to null)
        return try {
            describe(connectivity.getNetworkCapabilities(connectivity.activeNetwork))
        } catch (_: RuntimeException) {
            mapOf("available" to false, "metered" to null)
        }
    }

    private fun publish(capabilities: NetworkCapabilities) {
        channel?.invokeMethod("changed", describe(capabilities))
    }

    private fun describe(capabilities: NetworkCapabilities?): Map<String, Any?> = mapOf(
        "available" to (capabilities?.let {
            it.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                it.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        } == true),
        "metered" to capabilities?.let { !it.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) },
    )
}
