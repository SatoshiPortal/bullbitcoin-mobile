package com.bullbitcoin.secrets;

import static org.junit.Assert.*;

import com.google.crypto.tink.Aead;
import com.google.crypto.tink.DeterministicAead;
import com.google.crypto.tink.KeysetHandle;
import com.google.crypto.tink.RegistryConfiguration;
import com.google.crypto.tink.TinkProtoKeysetFormat;
import com.google.crypto.tink.InsecureSecretKeyAccess;
import com.google.crypto.tink.aead.AeadConfig;
import com.google.crypto.tink.aead.AeadKeyTemplates;
import com.google.crypto.tink.daead.DeterministicAeadConfig;
import com.google.crypto.tink.daead.DeterministicAeadKeyTemplates;
import com.google.crypto.tink.subtle.Hex;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.GeneralSecurityException;
import java.security.Key;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.util.Base64;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.spec.IvParameterSpec;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;

/** Real ciphertexts, synthetic values, and no Android provider mocks that bypass decryption. */
public class LegacyKeystoreReaderTest {
    private Path directory;
    private Aead master;
    private KeyPair rsa;
    private LegacyKeystoreReader.ExistingKeys keys;

    @Before
    public void setup() throws Exception {
        directory = Files.createTempDirectory("legacy-keystore-test");
        AeadConfig.register();
        DeterministicAeadConfig.register();
        master = KeysetHandle.generateNew(AeadKeyTemplates.AES256_GCM)
                .getPrimitive(RegistryConfiguration.get(), Aead.class);
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        rsa = generator.generateKeyPair();
        keys = new LegacyKeystoreReader.ExistingKeys() {
            public Aead espMaster() { return master; }
            public Key unwrapCbc(byte[] wrapped) throws GeneralSecurityException {
                Cipher cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding");
                cipher.init(Cipher.UNWRAP_MODE, rsa.getPrivate());
                return cipher.unwrap(wrapped, "AES", Cipher.SECRET_KEY);
            }
        };
    }

    @After
    public void cleanup() throws Exception {
        try (var paths = Files.walk(directory)) {
            for (Path path : paths.sorted(Comparator.reverseOrder()).toList()) Files.delete(path);
        }
    }

    private LegacyKeystoreReader reader() {
        return new LegacyKeystoreReader(directory, keys);
    }

    @Test
    public void espReadsAuthenticatedEntriesAndPreservesEverySourceByte() throws Exception {
        writeEsp(Map.of("seed_synthetic", "{\"test\":\"synthetic\"}", "pin_code", "synthetic"), false);
        byte[] before = Files.readAllBytes(file(LegacyPreferencesSnapshot.DATA));
        assertEquals("esp", reader().inspect().get("format"));
        assertEquals(Map.of("seed_synthetic", "{\"test\":\"synthetic\"}", "pin_code", "synthetic"),
                reader().read().get("entries"));
        assertArrayEquals(before, Files.readAllBytes(file(LegacyPreferencesSnapshot.DATA)));
        try (var paths = Files.list(directory)) { assertEquals(1, paths.count()); }
    }

    @Test
    public void authenticatedSeedlessEspIsReadable() throws Exception {
        writeEsp(Map.of("pin_code", "synthetic"), false);
        assertEquals(Map.of("pin_code", "synthetic"), reader().read().get("entries"));
    }

    @Test
    public void existingCleartextKeysetsNeedNoMasterKey() throws Exception {
        writeEsp(Map.of("pin_code", "synthetic"), true);
        keys = new LegacyKeystoreReader.ExistingKeys() {
            public Aead espMaster() throws GeneralSecurityException { throw new GeneralSecurityException(); }
            public Key unwrapCbc(byte[] wrapped) throws GeneralSecurityException { throw new GeneralSecurityException(); }
        };
        assertEquals(Map.of("pin_code", "synthetic"), reader().read().get("entries"));
    }

    @Test
    public void wrongMasterNeverLooksEmptyOrRewritesKeysets() throws Exception {
        writeEsp(Map.of("pin_code", "synthetic"), false);
        byte[] before = Files.readAllBytes(file(LegacyPreferencesSnapshot.DATA));
        master = KeysetHandle.generateNew(AeadKeyTemplates.AES256_GCM)
                .getPrimitive(RegistryConfiguration.get(), Aead.class);
        fails("unreadable", () -> reader().read());
        assertArrayEquals(before, Files.readAllBytes(file(LegacyPreferencesSnapshot.DATA)));
    }

    @Test
    public void changedEspCiphertextCannotProduceAPartialRead() throws Exception {
        writeEsp(Map.of("first", "synthetic-a", "second", "synthetic-b"), false);
        Map<String, Object> parsed = LegacyPreferencesSnapshot.parse(
                Files.readAllBytes(file(LegacyPreferencesSnapshot.DATA)));
        Map<String, String> raw = new LinkedHashMap<>();
        for (var entry : parsed.entrySet()) raw.put(entry.getKey(), (String) entry.getValue());
        String name = raw.keySet().stream().filter(key -> !key.equals(LegacyKeystoreReader.KEYSET)
                && !key.equals(LegacyKeystoreReader.VALUESET)).findFirst().orElseThrow();
        byte[] ciphertext = Base64.getDecoder().decode(raw.get(name));
        ciphertext[ciphertext.length - 1] ^= 1;
        raw.put(name, Base64.getEncoder().encodeToString(ciphertext));
        write(LegacyPreferencesSnapshot.DATA, raw);
        byte[] before = Files.readAllBytes(file(LegacyPreferencesSnapshot.DATA));
        fails("unreadable", () -> reader().read());
        assertArrayEquals(before, Files.readAllBytes(file(LegacyPreferencesSnapshot.DATA)));
    }

    @Test
    public void sourceSymlinkIsRefusedWithoutFollowingIt() throws Exception {
        Path actual = directory.resolve("synthetic.xml");
        writeText(actual, "<map/>");
        Files.createSymbolicLink(file(LegacyPreferencesSnapshot.DATA), actual);
        fails("inconsistent", () -> reader().inspect());
        assertEquals("<map/>", readText(actual));
        assertTrue(Files.isSymbolicLink(file(LegacyPreferencesSnapshot.DATA)));
    }

    @Test
    public void cbcUsesExistingWrappedKeyAndDoesNotWriteMarkers() throws Exception {
        writeCbc(Map.of("pin_code", "synthetic", "seed_synthetic", "{\"test\":true}"));
        byte[] before = Files.readAllBytes(file(LegacyPreferencesSnapshot.DATA));
        byte[] keyBefore = Files.readAllBytes(file(LegacyPreferencesSnapshot.KEYS));
        assertEquals("cbc", reader().inspect().get("format"));
        assertEquals(Map.of("pin_code", "synthetic", "seed_synthetic", "{\"test\":true}"),
                reader().read().get("entries"));
        assertArrayEquals(before, Files.readAllBytes(file(LegacyPreferencesSnapshot.DATA)));
        assertArrayEquals(keyBefore, Files.readAllBytes(file(LegacyPreferencesSnapshot.KEYS)));
        assertFalse(Files.exists(file(LegacyPreferencesSnapshot.NAMED_CONFIG)));
    }

    @Test
    public void wrongCbcPrivateKeyCannotReplaceWrappedKey() throws Exception {
        writeCbc(Map.of("pin_code", "synthetic"));
        byte[] before = Files.readAllBytes(file(LegacyPreferencesSnapshot.KEYS));
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        rsa = generator.generateKeyPair();
        fails("unreadable", () -> reader().read());
        assertArrayEquals(before, Files.readAllBytes(file(LegacyPreferencesSnapshot.KEYS)));
    }

    @Test
    public void mixedAndRewrittenMarkersAreNotFreshStores() throws Exception {
        writeEsp(Map.of("pin_code", "synthetic"), false);
        String xml = readText(file(LegacyPreferencesSnapshot.DATA));
        writeText(file(LegacyPreferencesSnapshot.DATA), xml.replace("</map>",
                "<string name=\"" + LegacyKeystoreReader.PREFIX + "other\">unreadable</string></map>"));
        assertEquals("mixed", reader().inspect().get("format"));
        fails("unsupported", () -> reader().read());

        writeCbc(Map.of("pin_code", "synthetic"));
        write(LegacyPreferencesSnapshot.NAMED_CONFIG, Map.of(
                LegacyKeystoreReader.KEY_ALGORITHM, "RSA_ECB_OAEPwithSHA_256andMGF1Padding",
                LegacyKeystoreReader.STORAGE_ALGORITHM, "AES_GCM_NoPadding"));
        assertEquals("unknown", reader().inspect().get("format"));
        fails("unsupported", () -> reader().read());
    }

    @Test
    public void backupAndCorruptXmlAreRefusedWithoutRepair() throws Exception {
        Path file = file(LegacyPreferencesSnapshot.DATA);
        writeText(file, "<map/>");
        Path backup = directory.resolve(LegacyPreferencesSnapshot.DATA + ".xml.bak");
        writeText(backup, "<map/>");
        fails("inconsistent", () -> reader().inspect());
        assertTrue(Files.exists(backup));
        Files.delete(backup);
        for (String malformed : new String[] {"", "<map>", "<map/><map/>",
                "<map><string name=\"same\">a</string><string name=\"same\">b</string></map>",
                "<!DOCTYPE map [<!ENTITY x SYSTEM \"file:///unreadable\">]><map><string name=\"x\">&x;</string></map>"}) {
            writeText(file, malformed);
            fails("unreadable", () -> reader().inspect());
            assertEquals(malformed, readText(file));
        }
    }

    @Test
    public void snapshotDetectsChangeAndBackupAppearingLater() throws Exception {
        writeEsp(Map.of("pin_code", "synthetic"), false);
        LegacyPreferencesSnapshot snapshot = new LegacyPreferencesSnapshot(directory);
        writeText(file(LegacyPreferencesSnapshot.DATA), "<map/>");
        fails("changed", snapshot::verifyUnchanged);
        snapshot = new LegacyPreferencesSnapshot(directory);
        writeText(directory.resolve(LegacyPreferencesSnapshot.DATA + ".xml.bak"), "<map/>");
        fails("inconsistent", snapshot::verifyUnchanged);
    }

    @Test
    public void emptyInventoryIsNotAReadableLegacySnapshot() throws Exception {
        assertEquals("empty", reader().inspect().get("format"));
        fails("unsupported", () -> reader().read());
        write(LegacyPreferencesSnapshot.HINT, Map.of("flutter.seed_store_type", "{\"storageLibrary\":\"fss9\"}"));
        assertEquals(true, reader().inspect().get("priorStoreHint"));
        fails("unsupported", () -> reader().read());
    }

    @Test
    public void xmlEntitiesAndTypedConfigurationAreParsedWithoutExternalResolution() throws Exception {
        String xml = "<map><string name=\"a\">x&amp;y&lt;z</string><boolean name=\"b\" value=\"false\"/>"
                + "<long name=\"n\" value=\"123\"/><set name=\"s\"><string>one</string></set></map>";
        Map<String, Object> parsed = LegacyPreferencesSnapshot.parse(xml.getBytes(StandardCharsets.UTF_8));
        assertEquals("x&y<z", parsed.get("a"));
        assertEquals(false, parsed.get("b"));
        assertEquals(123L, parsed.get("n"));
    }

    private void writeEsp(Map<String, String> values, boolean cleartext) throws Exception {
        KeysetHandle namesHandle = KeysetHandle.generateNew(DeterministicAeadKeyTemplates.AES256_SIV);
        KeysetHandle valuesHandle = KeysetHandle.generateNew(AeadKeyTemplates.AES256_GCM);
        DeterministicAead names = namesHandle.getPrimitive(RegistryConfiguration.get(), DeterministicAead.class);
        Aead aead = valuesHandle.getPrimitive(RegistryConfiguration.get(), Aead.class);
        Map<String, String> raw = new LinkedHashMap<>();
        raw.put(LegacyKeystoreReader.KEYSET, Hex.encode(cleartext
                ? TinkProtoKeysetFormat.serializeKeyset(namesHandle, InsecureSecretKeyAccess.get())
                : TinkProtoKeysetFormat.serializeEncryptedKeyset(namesHandle, master, new byte[0])));
        raw.put(LegacyKeystoreReader.VALUESET, Hex.encode(cleartext
                ? TinkProtoKeysetFormat.serializeKeyset(valuesHandle, InsecureSecretKeyAccess.get())
                : TinkProtoKeysetFormat.serializeEncryptedKeyset(valuesHandle, master, new byte[0])));
        for (var entry : values.entrySet()) {
            String encryptedName = Base64.getEncoder().encodeToString(names.encryptDeterministically(
                    (LegacyKeystoreReader.PREFIX + entry.getKey()).getBytes(StandardCharsets.UTF_8),
                    LegacyPreferencesSnapshot.DATA.getBytes(StandardCharsets.UTF_8)));
            byte[] text = entry.getValue().getBytes(StandardCharsets.UTF_8);
            byte[] envelope = ByteBuffer.allocate(8 + text.length).putInt(0).putInt(text.length).put(text).array();
            raw.put(encryptedName, Base64.getEncoder().encodeToString(aead.encrypt(envelope,
                    encryptedName.getBytes(StandardCharsets.UTF_8))));
        }
        write(LegacyPreferencesSnapshot.DATA, raw);
    }

    private void writeCbc(Map<String, String> values) throws Exception {
        KeyGenerator generator = KeyGenerator.getInstance("AES");
        generator.init(128);
        Key aes = generator.generateKey();
        Cipher wrapper = Cipher.getInstance("RSA/ECB/PKCS1Padding");
        wrapper.init(Cipher.WRAP_MODE, rsa.getPublic());
        write(LegacyPreferencesSnapshot.KEYS,
                Map.of(LegacyKeystoreReader.CBC_KEY, Base64.getEncoder().encodeToString(wrapper.wrap(aes))));
        Map<String, String> raw = new LinkedHashMap<>();
        for (var entry : values.entrySet()) {
            Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
            cipher.init(Cipher.ENCRYPT_MODE, aes);
            byte[] encrypted = cipher.doFinal(entry.getValue().getBytes(StandardCharsets.UTF_8));
            raw.put(LegacyKeystoreReader.PREFIX + entry.getKey(), Base64.getEncoder().encodeToString(
                    ByteBuffer.allocate(16 + encrypted.length).put(cipher.getIV()).put(encrypted).array()));
        }
        write(LegacyPreferencesSnapshot.DATA, raw);
    }

    private static String readText(Path path) throws Exception {
        return new String(Files.readAllBytes(path), StandardCharsets.UTF_8);
    }

    private static void writeText(Path path, String text) throws Exception {
        Files.write(path, text.getBytes(StandardCharsets.UTF_8));
    }

    private Path file(String name) { return directory.resolve(name + ".xml"); }

    private void write(String name, Map<String, String> entries) throws Exception {
        StringBuilder xml = new StringBuilder("<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\"?><map>");
        for (var entry : entries.entrySet()) {
            xml.append("<string name=\"").append(escape(entry.getKey())).append("\">")
                    .append(escape(entry.getValue())).append("</string>");
        }
        writeText(file(name), xml.append("</map>").toString());
    }

    private static String escape(String value) {
        return value.replace("&", "&amp;").replace("<", "&lt;").replace("\"", "&quot;");
    }

    private interface Checked { void run() throws Exception; }

    private static void fails(String code, Checked action) throws Exception {
        try {
            action.run();
            fail("Expected fixed failure code");
        } catch (LegacyReadException e) {
            assertEquals(code, e.code);
            assertEquals(code, e.getMessage());
        }
    }
}
