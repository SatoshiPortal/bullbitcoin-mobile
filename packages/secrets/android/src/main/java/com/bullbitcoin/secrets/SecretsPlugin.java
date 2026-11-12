package com.bullbitcoin.secrets;

import android.content.Context;
import com.google.crypto.tink.Aead;
import com.google.crypto.tink.integration.android.AndroidKeystoreKmsClient;
import java.security.GeneralSecurityException;
import java.security.Key;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import javax.crypto.Cipher;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import android.os.Handler;
import android.os.Looper;

/** Private read-only recovery channel. No call selects or activates a writable store. */
public final class SecretsPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private static final ExecutorService READER = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    private MethodChannel channel;
    private LegacyKeystoreReader reader;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        Context context = binding.getApplicationContext();
        reader = new LegacyKeystoreReader(
                context.getDataDir().toPath().resolve("shared_prefs"), new AndroidExistingKeys(context.getPackageName()));
        channel = new MethodChannel(binding.getBinaryMessenger(), "com.bullbitcoin.secrets/legacy_reader");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
        reader = null;
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (!call.method.equals("inspect") && !call.method.equals("readLegacy")) {
            result.notImplemented();
            return;
        }
        if (call.arguments != null || reader == null) {
            result.error("unavailable", "Legacy keystore unavailable", null);
            return;
        }
        LegacyKeystoreReader current = reader;
        READER.execute(() -> {
            try {
                Object value = call.method.equals("inspect") ? current.inspect() : current.read();
                main.post(() -> result.success(value));
            } catch (LegacyReadException e) {
                main.post(() -> result.error(e.code, "Legacy keystore unavailable", null));
            } catch (Exception e) {
                main.post(() -> result.error("unreadable", "Legacy keystore unavailable", null));
            }
        });
    }

    private static final class AndroidExistingKeys implements LegacyKeystoreReader.ExistingKeys {
        private final String packageName;

        AndroidExistingKeys(String packageName) {
            this.packageName = packageName;
        }

        @Override
        public Aead espMaster() throws GeneralSecurityException {
            return new AndroidKeystoreKmsClient().getAead("android-keystore://_androidx_security_master_key_");
        }

        @Override
        public Key unwrapCbc(byte[] wrapped) throws GeneralSecurityException {
            try {
                KeyStore store = KeyStore.getInstance("AndroidKeyStore");
                store.load(null);
                Key key = store.getKey(packageName + ".FlutterSecureStoragePluginKey", null);
                if (!(key instanceof PrivateKey)) throw new GeneralSecurityException("Existing key unavailable");
                Cipher cipher = Cipher.getInstance("RSA/ECB/PKCS1Padding", "AndroidKeyStoreBCWorkaround");
                cipher.init(Cipher.UNWRAP_MODE, (PrivateKey) key);
                return cipher.unwrap(wrapped, "AES", Cipher.SECRET_KEY);
            } catch (GeneralSecurityException e) {
                throw e;
            } catch (Exception e) {
                throw new GeneralSecurityException("Existing key unavailable");
            }
        }
    }
}
