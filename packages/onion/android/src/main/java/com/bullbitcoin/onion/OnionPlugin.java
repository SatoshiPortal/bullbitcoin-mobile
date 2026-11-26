package com.bullbitcoin.onion;

import android.content.Context;

import androidx.annotation.NonNull;

import java.io.File;

import IPtProxy.Controller;
import IPtProxy.IPtProxy;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Starts the process-wide IPtProxy Snowflake client used by Arti. */
public final class OnionPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private static final String CHANNEL = "com.bullbitcoin.onion/snowflake";
    private static final Object LOCK = new Object();

    private static Controller controller;
    private static int leases;

    private MethodChannel channel;
    private Context context;
    private boolean acquired;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "start":
                start(result);
                break;
            case "stop":
                release();
                result.success(null);
                break;
            case "version":
                result.success(IPtProxy.snowflakeVersion());
                break;
            default:
                result.notImplemented();
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        release();
        channel = null;
        context = null;
    }

    private void start(MethodChannel.Result result) {
        synchronized (LOCK) {
            if (acquired) {
                final long port = controller == null ? 0 : controller.port(IPtProxy.Snowflake);
                if (isValidPort(port)) {
                    result.success(port);
                } else {
                    result.error("snowflake_not_running", "Snowflake is not running", null);
                }
                return;
            }

            try {
                if (controller == null) {
                    final File stateDir = new File(context.getNoBackupFilesDir(), "onion_pt");
                    if (!stateDir.exists() && !stateDir.mkdirs()) {
                        result.error("snowflake_storage", "Snowflake storage is unavailable", null);
                        return;
                    }

                    // Built once per process: IPtProxy registers its transports
                    // globally, so a second Controller cannot be constructed.
                    controller = new Controller(
                            stateDir.getAbsolutePath(),
                            false,
                            false,
                            "ERROR",
                            null
                    );
                }

                long port = controller.port(IPtProxy.Snowflake);
                if (!isValidPort(port)) {
                    controller.start(IPtProxy.Snowflake, "");
                    port = controller.port(IPtProxy.Snowflake);
                    if (!isValidPort(port)) {
                        stopQuietly(controller);
                        result.error("snowflake_start_failed", "Snowflake did not bind a local port", null);
                        return;
                    }
                }
                leases++;
                acquired = true;
                result.success(port);
            } catch (Exception ignored) {
                // Nobody holds a lease, so the transport is ours to stop. Left
                // running, the Snowflake proxy would outlive every user of it.
                if (leases == 0) {
                    stopQuietly(controller);
                }
                result.error("snowflake_start_failed", "Snowflake could not be started", null);
            }
        }
    }

    private void release() {
        synchronized (LOCK) {
            if (!acquired) {
                return;
            }
            acquired = false;
            leases--;
            if (leases == 0) {
                stopQuietly(controller);
            }
        }
    }

    /** Stops the transport but keeps the controller; best-effort, since it runs during engine detachment and on the failed-start path. */
    private static void stopQuietly(Controller candidate) {
        if (candidate == null) {
            return;
        }
        try {
            candidate.stop(IPtProxy.Snowflake);
        } catch (Exception ignored) {
            // Nothing left to do; the next start begins from a fresh listener.
        }
    }

    private static boolean isValidPort(long port) {
        return port > 0 && port <= 65535;
    }
}
