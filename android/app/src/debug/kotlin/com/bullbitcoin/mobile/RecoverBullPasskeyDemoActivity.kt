package com.bullbitcoin.mobile

import android.os.Build
import android.os.CancellationSignal
import androidx.credentials.CreateCredentialResponse
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.net.URI

/** Debug-only bridge for the fictional RecoverBull vault. */
class RecoverBullPasskeyDemoActivity : MainActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val manager = CredentialManager.create(this)
        val pending = mutableMapOf<String, Pair<CancellationSignal, MethodChannel.Result>>()
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.bullbitcoin.mobile/recoverbull_passkey_demo",
        ).setMethodCallHandler { call, result ->
            if (call.method == "cancel") {
                val pendingCall = pending.remove(call.arguments as? String)
                pendingCall?.first?.cancel()
                pendingCall?.second?.error("cancelled", "Passkey request cancelled.", null)
                result.success(null)
                return@setMethodCallHandler
            }
            if (call.method != "create" && call.method != "get") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val id = call.argument<String>("id")
            val json = call.argument<String>("options")
            val origin = getString(R.string.recoverbull_passkey_demo_origin)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                result.error("unavailable", "Passkeys require Android 9 or later.", null)
                return@setMethodCallHandler
            }
            if (id.isNullOrEmpty() || json == null || origin.isEmpty() || pending.containsKey(id)) {
                result.error("invalid_request", "A JSON string and demo HTTPS origin are required.", null)
                return@setMethodCallHandler
            }
            try {
                val options = JSONObject(json)
                val rpId = if (call.method == "create") {
                    options.getJSONObject("rp").getString("id")
                } else {
                    options.getString("rpId")
                }
                if (rpId != URI(origin).host) {
                    result.error("invalid_request", "The relying party does not match the demo origin.", null)
                    return@setMethodCallHandler
                }
                val signal = CancellationSignal()
                val channelResult = result
                pending[id] = signal to result
                if (call.method == "create") {
                    manager.createCredentialAsync(
                        this, CreatePublicKeyCredentialRequest(json), signal, mainExecutor,
                        object : CredentialManagerCallback<CreateCredentialResponse, CreateCredentialException> {
                            override fun onResult(result: CreateCredentialResponse) {
                                if (pending.remove(id) == null) return
                                if (result is CreatePublicKeyCredentialResponse) {
                                    channelResult.success(result.registrationResponseJson)
                                } else {
                                    channelResult.error("credential_error", "Unexpected credential response.", null)
                                }
                            }

                            override fun onError(e: CreateCredentialException) {
                                if (pending.remove(id) == null) return
                                val code = if (e is CreateCredentialCancellationException) "cancelled" else "credential_error"
                                result.error(code, "Passkey creation did not complete.", null)
                            }
                        },
                    )
                } else {
                    val request = GetCredentialRequest(listOf(GetPublicKeyCredentialOption(json)))
                    manager.getCredentialAsync(
                        this, request, signal, mainExecutor,
                        object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                            override fun onResult(result: GetCredentialResponse) {
                                if (pending.remove(id) == null) return
                                val credential = result.credential
                                if (credential is PublicKeyCredential) {
                                    channelResult.success(credential.authenticationResponseJson)
                                } else {
                                    channelResult.error("credential_error", "Unexpected credential response.", null)
                                }
                            }

                            override fun onError(e: GetCredentialException) {
                                if (pending.remove(id) == null) return
                                val code = if (e is GetCredentialCancellationException) "cancelled" else "credential_error"
                                result.error(code, "Passkey retrieval did not complete.", null)
                            }
                        },
                    )
                }
            } catch (e: IllegalArgumentException) {
                pending.remove(id)
                result.error("invalid_request", "Invalid passkey request.", null)
            } catch (e: org.json.JSONException) {
                pending.remove(id)
                result.error("invalid_request", "Invalid passkey request.", null)
            }
        }
    }
}
