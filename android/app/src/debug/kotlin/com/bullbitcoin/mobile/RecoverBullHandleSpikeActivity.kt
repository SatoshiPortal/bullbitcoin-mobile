package com.bullbitcoin.mobile

import android.app.Activity
import android.content.Intent
import android.graphics.Typeface
import android.os.Bundle
import android.os.CancellationSignal
import android.text.InputType
import android.util.Base64
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
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
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Debug-only fixture for the RecoverBull passkey `userHandle` spike.
 *
 * Design under test: `userHandle = vaultId (32 bytes) || prfInput (32 bytes)`,
 * exactly 64 bytes, with an independent random `prfInput`.
 *
 * Opening a vault is a two-step flow:
 *  1. one discoverable ceremony (`allowCredentials` empty, so the user picks a
 *     passkey manually); its `userHandle` is compared locally against the
 *     vault's own `vaultId` (here a synthetic 32-byte id, stood in for by its
 *     SHA-256 fingerprint the way the vault file would carry the real id);
 *  2. only on a match, one targeted ceremony (`allowCredentials` = the selected
 *     credential, `prf.eval.first` = bytes 32..63 of the handle) asks for the
 *     PRF output. The passkey itself is the only store of the handle, so the
 *     PRF input survives an activity or process restart without being written
 *     anywhere by this fixture.
 *
 * A mismatching passkey is rejected locally, before any second ceremony or
 * request.
 *
 * This activity is excluded from normal startup: it is not the launcher, has
 * no intent filter and is only reachable through an explicit intent
 * (`adb shell am start -n com.bullbitcoin.mobile.debug/com.bullbitcoin.mobile.RecoverBullHandleSpikeActivity`).
 * It is not wired to the product UI, to the Flutter engine, to the RecoverBull
 * feature or to any vault format, and it makes no network call.
 *
 * Persistence: none. Nothing is written to shared preferences, files, logs or
 * the clipboard; the in-memory vault fingerprints do not survive the process.
 * Only synthetic values are used, and only SHA-256 fingerprints and byte
 * lengths are ever displayed. Credential ids, handles, PRF inputs, PRF outputs
 * and tags are zeroed after use and never shown.
 */
class RecoverBullHandleSpikeActivity : Activity() {
    private val label = "recoverbull-handle-spike-fixture-v1".toByteArray(Charsets.UTF_8)
    private val random = SecureRandom()
    private val vaultFingerprints = HashMap<String, String>()

    private lateinit var manager: CredentialManager
    private lateinit var status: TextView
    private lateinit var expectedField: EditText
    private var busy = false
    private var signal: CancellationSignal? = null

    private class Assertion(
        val credentialId: ByteArray,
        val handle: ByteArray?,
        val prf: ByteArray?,
        val rpVerified: Boolean,
        val clientVerified: Boolean,
    )

    private val rpId: String
        get() = getString(R.string.recoverbull_passkey_regtest_rp_id).trim()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        manager = CredentialManager.create(this)
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 40, 24, 24)
        }
        status = TextView(this).apply {
            text = "fixture=recoverbull-handle-spike-v1\nresult=idle"
        }
        column.addView(status)
        fun button(label: String, action: () -> Unit) {
            column.addView(
                Button(this).apply {
                    text = label
                    setOnClickListener { if (!busy) action() }
                },
            )
        }
        button("Create synthetic vault A") { createVault("A") }
        button("Create synthetic vault B") { createVault("B") }
        expectedField = EditText(this).apply {
            hint = "vault fingerprint (64 hex chars)"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            typeface = Typeface.MONOSPACE
            setSingleLine(true)
        }
        column.addView(expectedField)
        button("Unlock with fingerprint above") {
            unlock(null, expectedField.text.toString())
        }
        button("Probe: non-resident credential handle") { probeNonResident() }
        button("Probe: credential created without PRF") { probeNoPrf() }
        setContentView(ScrollView(this).apply { addView(column) })
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onDestroy() {
        signal?.cancel()
        signal = null
        super.onDestroy()
    }

    /**
     * Test harness entry point. Explicit intents only:
     * `action=create` with `slot=A|B`, `action=unlock` with `expected=<64 hex>`,
     * `action=probe-nonresident`, `action=probe-noprf`, `action=state`.
     */
    private fun handleIntent(intent: Intent?) {
        val action = intent?.getStringExtra("action") ?: return
        if (busy) {
            report("result=busy\nreason=another operation is still running")
            return
        }
        when (action) {
            "create" -> createVault(intent.getStringExtra("slot") ?: "A")
            "unlock" -> unlock(
                intent.getStringExtra("slot"),
                intent.getStringExtra("expected") ?: expectedField.text.toString(),
            )
            "probe-nonresident" -> probeNonResident()
            "probe-noprf" -> probeNoPrf()
            "state" -> report(
                buildString {
                    append("fixture=recoverbull-handle-spike-v1\n")
                    append("result=state\n")
                    append("rp=$rpId\n")
                    append("vault_a=${vaultFingerprints["A"] ?: "none"}\n")
                    append("vault_b=${vaultFingerprints["B"] ?: "none"}")
                },
            )
            else -> report("fixture=recoverbull-handle-spike-v1\nresult=unknown_action\nreason=$action")
        }
    }

    private fun report(message: String) {
        busy = false
        status.text = message
        signal = null
    }

    private fun fail(result: String, reason: String) {
        report("fixture=recoverbull-handle-spike-v1\nresult=$result\nrp=$rpId\nreason=$reason")
    }

    private fun begin(): Boolean {
        busy = true
        signal = null
        return true
    }

    private fun randomBytes(count: Int) = ByteArray(count).also { random.nextBytes(it) }

    private fun enc(bytes: ByteArray) =
        Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)

    private fun dec(value: String) =
        Base64.decode(value.trim(), Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)

    private fun sha256(bytes: ByteArray) = MessageDigest.getInstance("SHA-256").digest(bytes)

    private fun hex(bytes: ByteArray) =
        bytes.joinToString("") { "%02x".format(it.toInt() and 0xff) }

    private fun hexBytes(value: String): ByteArray? {
        if (value.length != 64 || value.any { it !in "0123456789abcdefABCDEF" }) return null
        return ByteArray(32) { index -> value.substring(index * 2, index * 2 + 2).toInt(16).toByte() }
    }

    private fun vaultFingerprint(vaultId: ByteArray) = hex(sha256(vaultId))

    private fun prfFingerprint(prf: ByteArray): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(prf, "HmacSHA256"))
        val tag = mac.doFinal(label)
        val fingerprint = hex(sha256(tag))
        tag.fill(0)
        return fingerprint
    }

    private fun createVault(slot: String) {
        if (slot != "A" && slot != "B") {
            report("fixture=recoverbull-handle-spike-v1\nresult=bad_slot\nreason=slot must be A or B")
            return
        }
        if (!begin()) return
        if (rpId.isEmpty()) {
            fail("unavailable", "the build carries no RP ID")
            return
        }
        val vaultId = randomBytes(32)
        val prfInput = randomBytes(32)
        val handle = vaultId + prfInput
        val fingerprint = vaultFingerprint(vaultId)
        val challenge = enc(randomBytes(32))
        val json = JSONObject()
            .put("challenge", challenge)
            .put("rp", JSONObject().put("id", rpId).put("name", "RecoverBull"))
            .put(
                "user",
                JSONObject()
                    .put("id", enc(handle))
                    .put("name", "RecoverBull vault $slot")
                    .put("displayName", "RecoverBull vault $slot"),
            )
            .put("pubKeyCredParams", JSONArray().put(JSONObject().put("type", "public-key").put("alg", -7)))
            .put("authenticatorSelection", JSONObject().put("residentKey", "required").put("userVerification", "required"))
            .put("attestation", "none")
            .put("extensions", JSONObject().put("prf", JSONObject()))
        handle.fill(0)
        vaultId.fill(0)
        prfInput.fill(0)
        val active = CancellationSignal()
        signal = active
        manager.createCredentialAsync(
            this,
            CreatePublicKeyCredentialRequest(json.toString()),
            active,
            mainExecutor,
            object : CredentialManagerCallback<CreateCredentialResponse, CreateCredentialException> {
                override fun onResult(result: CreateCredentialResponse) {
                    if (result !is CreatePublicKeyCredentialResponse) {
                        fail("invalid_response", "vault $slot creation returned an unexpected response")
                        return
                    }
                    val valid = try {
                        val created = JSONObject(result.registrationResponseJson)
                        val id = dec(created.getString("id"))
                        val rawId = dec(created.getString("rawId"))
                        val client = JSONObject(String(dec(created.getJSONObject("response").getString("clientDataJSON")), Charsets.UTF_8))
                        val ok = MessageDigest.isEqual(id, rawId) &&
                            client.getString("type") == "webauthn.create" &&
                            client.getString("challenge") == challenge
                        id.fill(0)
                        rawId.fill(0)
                        ok
                    } catch (_: Exception) {
                        false
                    }
                    if (!valid) {
                        fail("invalid_response", "vault $slot creation response did not verify; nothing kept")
                        return
                    }
                    vaultFingerprints[slot] = fingerprint
                    report(
                        "fixture=recoverbull-handle-spike-v1\n" +
                            "result=ok\n" +
                            "action=create\n" +
                            "rp=$rpId\n" +
                            "vault=$slot\n" +
                            "vault_fp=$fingerprint\n" +
                            "handle_bytes=64",
                    )
                }

                override fun onError(e: CreateCredentialException) {
                    val why = if (e is CreateCredentialCancellationException) "cancelled" else "failed"
                    fail(why, "vault $slot creation did not complete; nothing kept")
                }
            },
        )
    }

    /**
     * One discoverable, manually selected passkey; local vaultId check; then one
     * targeted PRF ceremony only when the handle belongs to the expected vault.
     * `expectedHex` comes from the intent or the text field (the stand-in for
     * the vault file's own id); `slot` only names the vault in the output.
     */
    private fun unlock(slot: String?, expectedHex: String?) {
        if (!begin()) return
        if (rpId.isEmpty()) {
            fail("unavailable", "the build carries no RP ID")
            return
        }
        val expected = expectedHex?.trim()?.takeIf { it.isNotEmpty() }
            ?: slot?.let { vaultFingerprints[it] }
        if (expected == null) {
            fail("no_expected", "create a vault in this session or pass expected=<64 hex chars>")
            return
        }
        val expectedBytes = hexBytes(expected)
        if (expectedBytes == null) {
            fail("bad_expected", "expected vault fingerprint must be exactly 64 hex chars")
            return
        }
        val name = slot ?: "expected"
        firstCeremony { selection, failure ->
            if (selection == null) {
                expectedBytes.fill(0)
                fail(failure ?: "failed", "first selection did not complete; no second ceremony")
                return@firstCeremony
            }
            val handle = selection.handle
            if (!selection.clientVerified || !selection.rpVerified) {
                selection.credentialId.fill(0)
                handle?.fill(0)
                selection.prf?.fill(0)
                expectedBytes.fill(0)
                fail("invalid_response", "first selection did not verify against this RP; no second ceremony")
                return@firstCeremony
            }
            if (handle == null) {
                selection.credentialId.fill(0)
                selection.prf?.fill(0)
                expectedBytes.fill(0)
                fail("no_handle", "first selection returned no userHandle; no second ceremony")
                return@firstCeremony
            }
            if (handle.size != 64) {
                val size = handle.size
                handle.fill(0)
                selection.credentialId.fill(0)
                selection.prf?.fill(0)
                expectedBytes.fill(0)
                report(
                    "fixture=recoverbull-handle-spike-v1\n" +
                        "result=bad_handle\n" +
                        "rp=$rpId\n" +
                        "handle_bytes=$size\n" +
                        "ceremonies=1\n" +
                        "reason=handle is not 64 bytes; rejected locally, no second ceremony",
                )
                return@firstCeremony
            }
            val selectedVaultIdHash = sha256(handle.copyOfRange(0, 32))
            val matches = MessageDigest.isEqual(selectedVaultIdHash, expectedBytes)
            expectedBytes.fill(0)
            if (!matches) {
                val selected = hex(selectedVaultIdHash)
                selectedVaultIdHash.fill(0)
                handle.fill(0)
                selection.credentialId.fill(0)
                selection.prf?.fill(0)
                report(
                    "fixture=recoverbull-handle-spike-v1\n" +
                        "result=mismatch\n" +
                        "action=unlock\n" +
                        "rp=$rpId\n" +
                        "vault=$name\n" +
                        "selected_fp=$selected\n" +
                        "ceremonies=1\n" +
                        "reason=selected passkey is not this vault; rejected locally before any second ceremony or request",
                )
                return@firstCeremony
            }
            val actualFingerprint = hex(selectedVaultIdHash)
            selectedVaultIdHash.fill(0)
            val handleSize = handle.size
            val prfInput = handle.copyOfRange(32, 64)
            secondCeremony(selection.credentialId, handle, prfInput) { outcome, secondFailure ->
                handle.fill(0)
                prfInput.fill(0)
                if (outcome == null) {
                    fail(secondFailure ?: "failed", "second ceremony did not complete; nothing retained")
                    return@secondCeremony
                }
                val handleText = if (!outcome.handlePresent) "absent" else if (outcome.handleMatches) "yes" else "no"
                val secondSize = outcome.secondHandleSize
                val prfSize = outcome.prfSize
                val valid = outcome.handleMatches && prfSize == 32 && outcome.tagFingerprint != null
                report(
                    "fixture=recoverbull-handle-spike-v1\n" +
                        "result=${if (valid) "ok" else "prf_missing"}\n" +
                        "action=unlock\n" +
                        "rp=$rpId\n" +
                        "vault=$name\n" +
                        "vault_fp=$actualFingerprint\n" +
                        "ceremonies=2\n" +
                        "handle_bytes=$handleSize\n" +
                        "handle_second_bytes=$secondSize\n" +
                        "handle_match=$handleText\n" +
                        "prf_bytes=$prfSize\n" +
                        (outcome.tagFingerprint?.let { "prf_fp=$it" } ?: "prf_fp=none"),
                )
            }
        }
    }

    private fun firstCeremony(done: (Assertion?, String?) -> Unit) {
        request(emptyList(), null) { assertion, failure ->
            if (assertion == null) {
                done(null, failure ?: "failed")
                return@request
            }
            done(assertion, null)
        }
    }

    /**
     * Targeted second ceremony: `allowCredentials` carries the selected
     * credential id; the PRF input is bytes 32..63 of the handle.
     */
    private class PrfOutcome(
        val handlePresent: Boolean,
        val handleMatches: Boolean,
        val secondHandleSize: Int,
        val prfSize: Int,
        val tagFingerprint: String?,
    )

    private fun secondCeremony(
        credentialId: ByteArray,
        firstHandle: ByteArray,
        prfInput: ByteArray,
        done: (PrfOutcome?, String?) -> Unit,
    ) {
        request(listOf(credentialId), prfInput) { assertion, failure ->
            if (assertion == null) {
                credentialId.fill(0)
                done(null, failure ?: "failed")
                return@request
            }
            if (!MessageDigest.isEqual(assertion.credentialId, credentialId)) {
                assertion.credentialId.fill(0)
                assertion.handle?.fill(0)
                assertion.prf?.fill(0)
                credentialId.fill(0)
                done(null, "invalid_response")
                return@request
            }
            assertion.credentialId.fill(0)
            if (!assertion.clientVerified || !assertion.rpVerified) {
                assertion.handle?.fill(0)
                assertion.prf?.fill(0)
                credentialId.fill(0)
                done(null, "invalid_response")
                return@request
            }
            val handle = assertion.handle
            val handlePresent = handle != null
            val handleMatches = handle != null && handle.size == 64 && MessageDigest.isEqual(handle, firstHandle)
            val secondSize = handle?.size ?: 0
            handle?.fill(0)
            val prf = assertion.prf
            val prfSize = prf?.size ?: 0
            val fingerprint = if (prf != null && handleMatches && prf.size == 32) prfFingerprint(prf) else null
            prf?.fill(0)
            credentialId.fill(0)
            done(PrfOutcome(handlePresent, handleMatches, secondSize, prfSize, fingerprint), null)
        }
    }

    private fun request(
        allowCredentials: List<ByteArray>,
        prfInput: ByteArray?,
        done: (Assertion?, String?) -> Unit,
    ) {
        val challenge = enc(randomBytes(32))
        val options = JSONObject()
            .put("challenge", challenge)
            .put("rpId", rpId)
            .put("userVerification", "required")
        val allow = JSONArray()
        for (id in allowCredentials) {
            allow.put(JSONObject().put("type", "public-key").put("id", enc(id)))
        }
        options.put("allowCredentials", allow)
        if (prfInput != null) {
            options.put(
                "extensions",
                JSONObject().put(
                    "prf",
                    JSONObject().put("eval", JSONObject().put("first", enc(prfInput))),
                ),
            )
        }
        val request = GetCredentialRequest(listOf(GetPublicKeyCredentialOption(options.toString())))
        val active = CancellationSignal()
        signal = active
        manager.getCredentialAsync(
            this,
            request,
            active,
            mainExecutor,
            object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                override fun onResult(result: GetCredentialResponse) {
                    val credential = result.credential
                    if (credential !is PublicKeyCredential) {
                        done(null, "invalid_response")
                        return
                    }
                    val assertion = parseAssertion(credential.authenticationResponseJson, challenge)
                    if (assertion == null) {
                        done(null, "invalid_response")
                    } else {
                        done(assertion, null)
                    }
                }

                override fun onError(e: GetCredentialException) {
                    done(null, if (e is GetCredentialCancellationException) "cancelled" else "failed")
                }
            },
        )
    }

    /**
     * Parses an assertion and verifies it belongs to this RP: credential id
     * consistency, `webauthn.get` client data, our challenge, the RP ID hash,
     * and the user-presence + user-verification flags.
     */
    private fun parseAssertion(raw: String, challenge: String): Assertion? = try {
        val json = JSONObject(raw)
        val id = dec(json.getString("id"))
        val rawId = dec(json.getString("rawId"))
        if (!MessageDigest.isEqual(id, rawId)) {
            id.fill(0)
            rawId.fill(0)
            throw IllegalArgumentException("credential id mismatch")
        }
        rawId.fill(0)
        val response = json.getJSONObject("response")
        val client = JSONObject(String(dec(response.getString("clientDataJSON")), Charsets.UTF_8))
        val clientVerified = client.getString("type") == "webauthn.get" &&
            client.getString("challenge") == challenge &&
            !client.optBoolean("crossOrigin", false)
        val authData = dec(response.getString("authenticatorData"))
        val rpVerified = authData.size >= 37 &&
            MessageDigest.isEqual(
                authData.copyOfRange(0, 32),
                sha256(rpId.toByteArray(Charsets.UTF_8)),
            ) &&
            (authData[32].toInt() and 0x05) == 0x05
        authData.fill(0)
        val handle = response.optString("userHandle", "")
            .takeIf { it.isNotEmpty() }
            ?.let { dec(it) }
        val prfRaw = json.optJSONObject("clientExtensionResults")
            ?.optJSONObject("prf")
            ?.optJSONObject("results")
            ?.optString("first", "")
        val prf = prfRaw?.takeIf { it.isNotEmpty() }?.let { dec(it) }
        Assertion(id, handle, prf, rpVerified, clientVerified)
    } catch (_: Exception) {
        null
    }

    /**
     * Probe: a non-resident credential (residentKey discouraged) does not store
     * the user handle, so the second targeted ceremony may return none. Reports
     * presence and lengths only.
     */
    private fun probeNonResident() {
        if (!begin()) return
        if (rpId.isEmpty()) {
            fail("unavailable", "the build carries no RP ID")
            return
        }
        val vaultId = randomBytes(32)
        val prfInput = randomBytes(32)
        val handle = vaultId + prfInput
        val challenge = enc(randomBytes(32))
        val json = JSONObject()
            .put("challenge", challenge)
            .put("rp", JSONObject().put("id", rpId).put("name", "RecoverBull"))
            .put(
                "user",
                JSONObject()
                    .put("id", enc(handle))
                    .put("name", "RecoverBull non-resident probe")
                    .put("displayName", "RecoverBull non-resident probe"),
            )
            .put("pubKeyCredParams", JSONArray().put(JSONObject().put("type", "public-key").put("alg", -7)))
            .put("authenticatorSelection", JSONObject().put("residentKey", "discouraged").put("userVerification", "required"))
            .put("attestation", "none")
        handle.fill(0)
        vaultId.fill(0)
        prfInput.fill(0)
        val active = CancellationSignal()
        signal = active
        manager.createCredentialAsync(
            this,
            CreatePublicKeyCredentialRequest(json.toString()),
            active,
            mainExecutor,
            object : CredentialManagerCallback<CreateCredentialResponse, CreateCredentialException> {
                override fun onResult(result: CreateCredentialResponse) {
                    if (result !is CreatePublicKeyCredentialResponse) {
                        fail("invalid_response", "probe creation returned an unexpected response")
                        return
                    }
                    val id = try {
                        dec(JSONObject(result.registrationResponseJson).getString("id"))
                    } catch (_: Exception) {
                        null
                    }
                    if (id == null) {
                        fail("invalid_response", "probe creation returned no credential id")
                        return
                    }
                    request(listOf(id), null) { first, firstFailure ->
                        if (first == null) {
                            id.fill(0)
                            fail(firstFailure ?: "failed", "probe first targeted ceremony did not complete")
                            return@request
                        }
                        val firstHandle = first.handle
                        first.credentialId.fill(0)
                        if (firstHandle == null) {
                            id.fill(0)
                            report(
                                "fixture=recoverbull-handle-spike-v1\n" +
                                    "result=probe_nonresident\n" +
                                    "rp=$rpId\n" +
                                    "first_handle=absent\n" +
                                    "note=nothing more to request",
                            )
                            return@request
                        }
                        val firstSize = firstHandle.size
                        val firstPrfInput = if (firstSize == 64) firstHandle.copyOfRange(32, 64) else null
                        request(listOf(id), firstPrfInput) { second, secondFailure ->
                            val secondHandle = second?.handle
                            val secondSize = secondHandle?.size ?: 0
                            val same = secondHandle != null && firstHandle.size == secondHandle.size &&
                                MessageDigest.isEqual(secondHandle, firstHandle)
                            val prfSize = second?.prf?.size ?: 0
                            second?.credentialId?.fill(0)
                            secondHandle?.fill(0)
                            second?.prf?.fill(0)
                            firstHandle.fill(0)
                            id.fill(0)
                            report(
                                "fixture=recoverbull-handle-spike-v1\n" +
                                    "result=probe_nonresident\n" +
                                    "rp=$rpId\n" +
                                    "first_handle_bytes=$firstSize\n" +
                                    "second_handle_bytes=$secondSize\n" +
                                    "second_handle_same=${if (same) "yes" else "no"}\n" +
                                    "prf_bytes=$prfSize\n" +
                                    "second=${secondFailure ?: "ok"}",
                            )
                        }
                    }
                }

                override fun onError(e: CreateCredentialException) {
                    fail("failed", "probe non-resident credential creation did not complete")
                }
            },
        )
    }

    /**
     * Probe: a credential created without the PRF extension, then targeted with
     * a PRF eval. Reports whether the provider returns a PRF output.
     */
    private fun probeNoPrf() {
        if (!begin()) return
        if (rpId.isEmpty()) {
            fail("unavailable", "the build carries no RP ID")
            return
        }
        val vaultId = randomBytes(32)
        val prfInput = randomBytes(32)
        val handle = vaultId + prfInput
        val challenge = enc(randomBytes(32))
        val json = JSONObject()
            .put("challenge", challenge)
            .put("rp", JSONObject().put("id", rpId).put("name", "RecoverBull"))
            .put(
                "user",
                JSONObject()
                    .put("id", enc(handle))
                    .put("name", "RecoverBull no-PRF probe")
                    .put("displayName", "RecoverBull no-PRF probe"),
            )
            .put("pubKeyCredParams", JSONArray().put(JSONObject().put("type", "public-key").put("alg", -7)))
            .put("authenticatorSelection", JSONObject().put("residentKey", "required").put("userVerification", "required"))
            .put("attestation", "none")
        handle.fill(0)
        vaultId.fill(0)
        prfInput.fill(0)
        val active = CancellationSignal()
        signal = active
        manager.createCredentialAsync(
            this,
            CreatePublicKeyCredentialRequest(json.toString()),
            active,
            mainExecutor,
            object : CredentialManagerCallback<CreateCredentialResponse, CreateCredentialException> {
                override fun onResult(result: CreateCredentialResponse) {
                    if (result !is CreatePublicKeyCredentialResponse) {
                        fail("invalid_response", "probe creation returned an unexpected response")
                        return
                    }
                    // The creation response's own credential id is not reused
                    // here: the discoverable selection is the proven path in
                    // this fixture and is what the vault flow does. A targeted
                    // request built from a registration id was not honoured by
                    // the provider (empty passkey sheet), so it proves nothing.
                    val input = randomBytes(32)
                    request(emptyList(), null) { first, firstFailure ->
                        if (first == null) {
                            input.fill(0)
                            fail(firstFailure ?: "failed", "probe discoverable selection did not complete")
                            return@request
                        }
                        val id = first.credentialId
                        val firstSize = first.handle?.size ?: 0
                        first.handle?.fill(0)
                        first.prf?.fill(0)
                        request(listOf(id), input) { assertion, failure ->
                            input.fill(0)
                            id.fill(0)
                            if (assertion == null) {
                                report(
                                    "fixture=recoverbull-handle-spike-v1\n" +
                                        "result=probe_noprf\n" +
                                        "rp=$rpId\n" +
                                        "first_handle_bytes=$firstSize\n" +
                                        "second=${failure ?: "failed"}\n" +
                                        "prf=no_usable_credential",
                                )
                                return@request
                            }
                            val size = assertion.prf?.size ?: 0
                            val secondSize = assertion.handle?.size ?: 0
                            assertion.credentialId.fill(0)
                            assertion.handle?.fill(0)
                            assertion.prf?.fill(0)
                            report(
                                "fixture=recoverbull-handle-spike-v1\n" +
                                    "result=probe_noprf\n" +
                                    "rp=$rpId\n" +
                                    "first_handle_bytes=$firstSize\n" +
                                    "second_handle_bytes=$secondSize\n" +
                                    "prf_bytes=$size\n" +
                                    "prf=${if (size == 32) "present" else "absent"}",
                            )
                        }
                    }
                }

                override fun onError(e: CreateCredentialException) {
                    fail("failed", "probe no-PRF credential creation did not complete")
                }
            },
        )
    }
}
