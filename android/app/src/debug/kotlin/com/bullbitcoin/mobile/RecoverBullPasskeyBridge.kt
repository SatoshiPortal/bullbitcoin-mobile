package com.bullbitcoin.mobile

import android.app.Activity
import android.content.pm.PackageManager
import android.os.CancellationSignal
import android.os.Build
import android.util.Base64
import androidx.credentials.CreateCredentialResponse
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.security.SecureRandom

/** Debug-only bridge. Native WebAuthn JSON never crosses the channel. */
internal class RecoverBullPasskeyBridge(
    private val activity: Activity,
    private val rpId: String,
) {
    private val manager = CredentialManager.create(activity)
    private var active: Pair<CancellationSignal, MethodChannel.Result>? = null

    fun dispose() {
        active?.let { (signal, pending) ->
            active = null
            signal.cancel()
            pending.error("cancelled", "Passkey operation cancelled.", null)
        }
    }

    private fun encode(value: ByteArray): String =
        Base64.encodeToString(value, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

    private fun decode(value: String): ByteArray {
        require(value.matches(Regex("^[A-Za-z0-9_-]+$")))
        val decoded = Base64.decode(value, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
        require(encode(decoded) == value)
        return decoded
    }

    private fun random(): ByteArray = ByteArray(32).also { SecureRandom().nextBytes(it) }

    private fun validateClient(response: JSONObject, challenge: String, kind: String) {
        val client = JSONObject(String(decode(response.getString("clientDataJSON")), Charsets.UTF_8))
        require(client.getString("type") == kind)
        require(client.getString("challenge") == challenge)
        require(!client.optBoolean("crossOrigin", false))
        @Suppress("DEPRECATION")
        val info = activity.packageManager.getPackageInfo(
            activity.packageName, PackageManager.GET_SIGNING_CERTIFICATES,
        )
        val signatures = requireNotNull(info.signingInfo).apkContentsSigners
        require(signatures.size == 1)
        val fingerprint = MessageDigest.getInstance("SHA-256").digest(signatures[0].toByteArray())
        require(client.getString("origin") == "android:apk-key-hash:${encode(fingerprint)}")
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "cancel") {
            dispose()
            result.success(null)
            return
        }
        if (call.method != "create" && call.method != "get") {
            result.notImplemented()
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P || rpId.isEmpty() || active != null) {
            result.error("unavailable", "Passkey operation unavailable.", null)
            return
        }
        try {
            val challenge = encode(random())
            val signal = CancellationSignal()
            if (call.method == "create") {
                val options = JSONObject()
                    .put("challenge", challenge)
                    .put("rp", JSONObject().put("id", rpId).put("name", "Bull Bitcoin"))
                    .put("user", JSONObject().put("id", encode(random()))
                        .put("name", "RecoverBull").put("displayName", "RecoverBull"))
                    .put("pubKeyCredParams", JSONArray()
                        .put(JSONObject().put("type", "public-key").put("alg", -7))
                        .put(JSONObject().put("type", "public-key").put("alg", -257)))
                    .put("authenticatorSelection", JSONObject()
                        .put("residentKey", "required").put("userVerification", "required"))
                    .put("attestation", "none")
                    .put("extensions", JSONObject().put("prf", JSONObject()))
                active = signal to result
                manager.createCredentialAsync(
                    activity, CreatePublicKeyCredentialRequest(options.toString()), signal,
                    activity.mainExecutor,
                    object : CredentialManagerCallback<CreateCredentialResponse, CreateCredentialException> {
                        override fun onResult(value: CreateCredentialResponse) {
                            if (active?.second !== result) return
                            active = null
                            try {
                                require(value is CreatePublicKeyCredentialResponse)
                                val response = JSONObject(value.registrationResponseJson)
                                validateClient(response.getJSONObject("response"), challenge, "webauthn.create")
                                val id = decode(response.getString("rawId"))
                                require(id.isNotEmpty() && id.size <= 1024)
                                require(MessageDigest.isEqual(decode(response.getString("id")), id))
                                result.success(id)
                            } catch (_: Exception) {
                                result.error("invalid_response", "Invalid passkey response.", null)
                            }
                        }
                        override fun onError(e: CreateCredentialException) {
                            if (active?.second !== result) return
                            active = null
                            val code = if (e is CreateCredentialCancellationException) "cancelled" else "unavailable"
                            result.error(code, "Passkey creation did not complete.", null)
                        }
                    },
                )
            } else {
                val credentialId = requireNotNull(call.argument<ByteArray>("credentialId"))
                val salt = requireNotNull(call.argument<ByteArray>("salt"))
                require(credentialId.isNotEmpty() && credentialId.size <= 1024 && salt.size == 32)
                val options = JSONObject()
                    .put("challenge", challenge)
                    .put("rpId", rpId)
                    .put("userVerification", "required")
                    .put("allowCredentials", JSONArray().put(JSONObject()
                        .put("type", "public-key").put("id", encode(credentialId))))
                    .put("extensions", JSONObject().put("prf", JSONObject().put("eval",
                        JSONObject().put("first", encode(salt)))))
                val request = GetCredentialRequest(listOf(GetPublicKeyCredentialOption(options.toString())))
                active = signal to result
                manager.getCredentialAsync(
                    activity, request, signal, activity.mainExecutor,
                    object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                        override fun onResult(value: GetCredentialResponse) {
                            if (active?.second !== result) return
                            active = null
                            try {
                                val credential = value.credential
                                require(credential is PublicKeyCredential)
                                val json = JSONObject(credential.authenticationResponseJson)
                                require(MessageDigest.isEqual(decode(json.getString("rawId")), credentialId))
                                require(MessageDigest.isEqual(decode(json.getString("id")), credentialId))
                                val response = json.getJSONObject("response")
                                validateClient(response, challenge, "webauthn.get")
                                val authData = decode(response.getString("authenticatorData"))
                                require(authData.size >= 37)
                                val rpHash = MessageDigest.getInstance("SHA-256")
                                    .digest(rpId.toByteArray(Charsets.UTF_8))
                                require(MessageDigest.isEqual(authData.copyOfRange(0, 32), rpHash))
                                require((authData[32].toInt() and 0x04) != 0)
                                require((authData[32].toInt() and 0x01) != 0)
                                val prf = decode(json.getJSONObject("clientExtensionResults")
                                    .getJSONObject("prf").getJSONObject("results").getString("first"))
                                try {
                                    require(prf.size == 32)
                                    result.success(prf)
                                } finally {
                                    prf.fill(0)
                                }
                            } catch (_: Exception) {
                                result.error("invalid_response", "Passkey PRF unavailable or invalid.", null)
                            }
                        }
                        override fun onError(e: GetCredentialException) {
                            if (active?.second !== result) return
                            active = null
                            val code = if (e is GetCredentialCancellationException) "cancelled" else "unavailable"
                            result.error(code, "Passkey retrieval did not complete.", null)
                        }
                    },
                )
            }
        } catch (_: Exception) {
            active = null
            result.error("invalid_request", "Invalid passkey request.", null)
        }
    }
}
