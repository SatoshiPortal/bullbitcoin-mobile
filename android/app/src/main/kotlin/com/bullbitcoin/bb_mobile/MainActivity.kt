package com.bullbitcoin.mobile

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Hand the window directly to Flutter's first frame. The platform's
            // default exit animation would otherwise fade the native splash
            // over the camo page, introducing a second crossfade.
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                splashScreenView.remove()
                // Removing the splash view skips the platform exit that would
                // normally let Flutter reapply its system UI style, so the
                // status and navigation bars would keep the launch values.
                // FlutterActivity.updateSystemUiOverlays() is a public no-op
                // until the delegate exists, so this is safe here.
                updateSystemUiOverlays()
            }
        }
        super.onCreate(savedInstanceState)
    }
}
