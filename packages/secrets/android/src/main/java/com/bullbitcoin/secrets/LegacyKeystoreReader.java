package com.bullbitcoin.secrets;

import com.google.crypto.tink.Aead;
import com.google.crypto.tink.DeterministicAead;
import com.google.crypto.tink.InsecureSecretKeyAccess;
import com.google.crypto.tink.KeysetHandle;
import com.google.crypto.tink.RegistryConfiguration;
import com.google.crypto.tink.TinkProtoKeysetFormat;
import com.google.crypto.tink.aead.AeadConfig;
import com.google.crypto.tink.daead.DeterministicAeadConfig;
import com.google.crypto.tink.subtle.Hex;
import java.nio.ByteBuffer;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.security.GeneralSecurityException;
import java.security.Key;
import java.util.Arrays;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.GCMParameterSpec;

/** No writer or initializer is reachable from this reader. Returned values stay inside secrets. */
final class LegacyKeystoreReader {
    static final String PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg_";
    static final String KEYSET = "__androidx_security_crypto_encrypted_prefs_key_keyset__";
    static final String VALUESET = "__androidx_security_crypto_encrypted_prefs_value_keyset__";
    static final String CBC_KEY = "VGhpcyBpcyB0aGUga2V5IGZvciBhIHNlY3VyZSBzdG9yYWdlIEFFUyBLZXkK";
    static final String GCM_KEY = "AES" + CBC_KEY;
    static final String KEY_ALGORITHM = "FlutterSecureSAlgorithmKey";
    static final String STORAGE_ALGORITHM = "FlutterSecureSAlgorithmStorage";

    interface ExistingKeys {
        Aead espMaster() throws GeneralSecurityException;
        Key unwrapCbc(byte[] wrapped) throws GeneralSecurityException;
        Key unwrapGcm(byte[] wrapped) throws GeneralSecurityException;
    }

    private final Path directory;
    private final ExistingKeys keys;

    LegacyKeystoreReader(Path directory, ExistingKeys keys) {
        this.directory = directory;
        this.keys = keys;
    }

    Map<String, Object> inspect() throws LegacyReadException {
        LegacyPreferencesSnapshot snapshot = new LegacyPreferencesSnapshot(directory);
        String format = classify(snapshot);
        // Metadata is not proof: develop can have written GCM markers over CBC data.
        // No plaintext leaves this check, and no default plugin instance is opened.
        if ("gcm".equals(format)) {
            try {
                authenticateGcm(snapshot);
            } catch (Exception e) {
                throw failure(e);
            }
        }
        snapshot.verifyUnchanged();
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("format", format);
        result.put("sourcePresent", snapshot.hasFile(LegacyPreferencesSnapshot.DATA));
        result.put("priorStoreHint", snapshot.get(LegacyPreferencesSnapshot.HINT).containsKey("flutter.seed_store_type"));
        return result;
    }

    Map<String, Object> read() throws LegacyReadException {
        LegacyPreferencesSnapshot snapshot = new LegacyPreferencesSnapshot(directory);
        String format = classify(snapshot);
        Map<String, String> entries;
        try {
            switch (format) {
                case "esp": entries = readEsp(snapshot.get(LegacyPreferencesSnapshot.DATA)); break;
                case "cbc": entries = readCbc(snapshot); break;
                default: throw new LegacyReadException("unsupported");
            }
            snapshot.verifyUnchanged();
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("format", format);
            result.put("entries", entries);
            return result;
        } catch (Exception e) {
            throw failure(e);
        }
    }

    private static LegacyReadException failure(Exception error) {
        if (error instanceof LegacyReadException) return (LegacyReadException) error;
        // A temporarily locked existing key is never evidence of absence.
        for (Throwable cause = error; cause != null; cause = cause.getCause()) {
            if (cause.getClass().getName().equals("android.security.keystore.UserNotAuthenticatedException")) {
                return new LegacyReadException("locked");
            }
        }
        return new LegacyReadException("unreadable");
    }

    private static String classify(LegacyPreferencesSnapshot snapshot) throws LegacyReadException {
        Map<String, Object> data = snapshot.get(LegacyPreferencesSnapshot.DATA);
        int raw = 0;
        int encrypted = 0;
        for (Map.Entry<String, Object> entry : data.entrySet()) {
            String name = entry.getKey();
            if (name.equals(KEYSET) || name.equals(VALUESET)
                    || name.equals(KEY_ALGORITHM) || name.equals(STORAGE_ALGORITHM)) continue;
            if (!(entry.getValue() instanceof String)) throw new LegacyReadException("unreadable");
            if (name.startsWith(PREFIX)) raw++; else encrypted++;
        }
        boolean keyset = data.containsKey(KEYSET);
        boolean valueset = data.containsKey(VALUESET);
        if (keyset != valueset) return "unknown";
        if (raw > 0 && encrypted > 0) return "mixed";
        if (encrypted > 0) return keyset ? "esp" : "unknown";
        Object keyAlgorithm = marker(snapshot, KEY_ALGORITHM);
        Object storageAlgorithm = marker(snapshot, STORAGE_ALGORITHM);
        boolean currentMarkers = "RSA_ECB_OAEPwithSHA_256andMGF1Padding".equals(keyAlgorithm)
                && "AES_GCM_NoPadding".equals(storageAlgorithm);
        if (currentMarkers && snapshot.get(LegacyPreferencesSnapshot.KEYS).containsKey(GCM_KEY)) {
            // Only inspect(), after authenticating every entry, may publish this format.
            return "gcm";
        }
        if (raw == 0) {
            // Existing keysets/config/keys are evidence, not proof of a fresh installation.
            return data.isEmpty() && snapshot.get(LegacyPreferencesSnapshot.KEYS).isEmpty()
                    && snapshot.get(LegacyPreferencesSnapshot.CONFIG).isEmpty()
                    && snapshot.get(LegacyPreferencesSnapshot.NAMED_CONFIG).isEmpty() ? "empty" : "unknown";
        }
        boolean legacyMarkers = (keyAlgorithm == null && storageAlgorithm == null)
                || ("RSA_ECB_PKCS1Padding".equals(keyAlgorithm) && "AES_CBC_PKCS7Padding".equals(storageAlgorithm));
        if (legacyMarkers && snapshot.get(LegacyPreferencesSnapshot.KEYS).containsKey(CBC_KEY)) return "cbc";
        // Rewritten markers and mixed historical cipher states require a separate recovery decision.
        return "unknown";
    }

    private static Object marker(LegacyPreferencesSnapshot snapshot, String name) {
        for (String source : new String[] {LegacyPreferencesSnapshot.NAMED_CONFIG,
                LegacyPreferencesSnapshot.CONFIG, LegacyPreferencesSnapshot.DATA}) {
            Map<String, Object> values = snapshot.get(source);
            if (values.containsKey(name)) return values.get(name);
        }
        return null;
    }

    private Map<String, String> readEsp(Map<String, Object> data) throws Exception {
        AeadConfig.register();
        DeterministicAeadConfig.register();
        Aead master = null;
        GeneralSecurityException masterFailure = null;
        try {
            master = keys.espMaster();
        } catch (GeneralSecurityException e) {
            masterFailure = e;
        }
        DeterministicAead names = keyset(stringValue(data, KEYSET), master, masterFailure)
                .getPrimitive(RegistryConfiguration.get(), DeterministicAead.class);
        Aead values = keyset(stringValue(data, VALUESET), master, masterFailure)
                .getPrimitive(RegistryConfiguration.get(), Aead.class);
        Map<String, String> result = new LinkedHashMap<>();
        for (Map.Entry<String, Object> entry : data.entrySet()) {
            String encryptedName = entry.getKey();
            if (encryptedName.equals(KEYSET) || encryptedName.equals(VALUESET)) continue;
            // Raw marker entries make an ESP source mixed, not something to silently omit.
            byte[] nameBytes = names.decryptDeterministically(
                    base64(encryptedName), LegacyPreferencesSnapshot.DATA.getBytes(StandardCharsets.UTF_8));
            String name = utf8(nameBytes);
            byte[] clear = values.decrypt(base64(stringValue(data, encryptedName)),
                    encryptedName.getBytes(StandardCharsets.UTF_8));
            try {
                if (clear.length < 8) throw new LegacyReadException("unreadable");
                ByteBuffer buffer = ByteBuffer.wrap(clear);
                if (buffer.getInt() != 0) throw new LegacyReadException("unsupported");
                int length = buffer.getInt();
                if (length != buffer.remaining()) throw new LegacyReadException("unreadable");
                byte[] text = new byte[length];
                buffer.get(text);
                try {
                    add(result, name, utf8(text));
                } finally {
                    Arrays.fill(text, (byte) 0);
                }
            } finally {
                Arrays.fill(nameBytes, (byte) 0);
                Arrays.fill(clear, (byte) 0);
            }
        }
        return result;
    }

    private static KeysetHandle keyset(String hex, Aead master, GeneralSecurityException masterFailure)
            throws GeneralSecurityException {
        byte[] bytes = Hex.decode(hex);
        try {
            GeneralSecurityException failure = masterFailure;
            if (master != null) {
                try {
                    return TinkProtoKeysetFormat.parseEncryptedKeyset(bytes, master, new byte[0]);
                } catch (GeneralSecurityException e) {
                    failure = e;
                }
            }
            try {
                // AndroidKeysetManager historically supported existing cleartext keysets.
                return TinkProtoKeysetFormat.parseKeyset(bytes, InsecureSecretKeyAccess.get());
            } catch (GeneralSecurityException e) {
                throw failure == null ? e : failure;
            }
        } finally {
            Arrays.fill(bytes, (byte) 0);
        }
    }

    private Map<String, String> readCbc(LegacyPreferencesSnapshot snapshot) throws Exception {
        Key aes = keys.unwrapCbc(base64(stringValue(snapshot.get(LegacyPreferencesSnapshot.KEYS), CBC_KEY)));
        Map<String, String> result = new LinkedHashMap<>();
        for (Map.Entry<String, Object> entry : snapshot.get(LegacyPreferencesSnapshot.DATA).entrySet()) {
            String name = entry.getKey();
            if (name.equals(KEYSET) || name.equals(VALUESET)
                    || name.equals(KEY_ALGORITHM) || name.equals(STORAGE_ALGORITHM)) continue;
            byte[] ciphertext = base64(stringValue(snapshot.get(LegacyPreferencesSnapshot.DATA), name));
            if (ciphertext.length < 32 || ciphertext.length % 16 != 0) throw new LegacyReadException("unreadable");
            // PKCS5Padding is the JCA spelling of PKCS7 padding for AES's 16-byte blocks.
            Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
            cipher.init(Cipher.DECRYPT_MODE, aes, new IvParameterSpec(ciphertext, 0, 16));
            byte[] clear = cipher.doFinal(ciphertext, 16, ciphertext.length - 16);
            try {
                add(result, name, utf8(clear));
            } finally {
                Arrays.fill(clear, (byte) 0);
            }
        }
        return result;
    }

    private void authenticateGcm(LegacyPreferencesSnapshot snapshot) throws Exception {
        Key aes = keys.unwrapGcm(base64(stringValue(snapshot.get(LegacyPreferencesSnapshot.KEYS), GCM_KEY)));
        // Even an empty current store must have a usable existing wrapped key.
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, aes, new GCMParameterSpec(128, new byte[12]));
        for (Map.Entry<String, Object> entry : snapshot.get(LegacyPreferencesSnapshot.DATA).entrySet()) {
            String name = entry.getKey();
            if (name.equals(KEYSET) || name.equals(VALUESET)
                    || name.equals(KEY_ALGORITHM) || name.equals(STORAGE_ALGORITHM)) continue;
            if (!name.startsWith(PREFIX) || name.length() == PREFIX.length()) {
                throw new LegacyReadException("unsupported");
            }
            byte[] ciphertext = base64(stringValue(snapshot.get(LegacyPreferencesSnapshot.DATA), name));
            if (ciphertext.length < 28) throw new LegacyReadException("unreadable");
            cipher.init(Cipher.DECRYPT_MODE, aes, new GCMParameterSpec(128, ciphertext, 0, 12));
            byte[] clear = cipher.doFinal(ciphertext, 12, ciphertext.length - 12);
            try {
                // FSS writes UTF-8 strings. An authenticated non-string is not current FSS data.
                utf8(clear);
            } finally {
                Arrays.fill(clear, (byte) 0);
            }
        }
    }

    private static void add(Map<String, String> entries, String prefixed, String value) throws LegacyReadException {
        if (!prefixed.startsWith(PREFIX) || prefixed.length() == PREFIX.length()
                || "__NULL__".equals(value) || entries.putIfAbsent(prefixed.substring(PREFIX.length()), value) != null) {
            throw new LegacyReadException("unreadable");
        }
    }

    private static String stringValue(Map<String, Object> entries, String name) throws LegacyReadException {
        Object value = entries.get(name);
        if (value instanceof String) return (String) value;
        throw new LegacyReadException("unreadable");
    }

    private static byte[] base64(String value) {
        // Android DEFAULT permits line wrapping, not arbitrary non-alphabet characters.
        return Base64.getDecoder().decode(value.replaceAll("[\\t\\n\\r ]", ""));
    }

    private static String utf8(byte[] value) throws Exception {
        return StandardCharsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(value)).toString();
    }
}
