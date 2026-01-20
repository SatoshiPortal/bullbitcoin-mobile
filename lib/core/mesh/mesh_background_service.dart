import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:bb_mobile/core/mesh/mesh_service.dart';
import 'package:bb_mobile/locator.dart';

/// Manages the long-running "Sentinel" service for Android.
/// On iOS, this mostly relies on native background modes, but we can use this 
/// to register Background Fetch if needed.
class MeshBackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Android Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'bull_mesh_sentinel', // id
      'Bull Mesh Sentinel', // title
      description: 'Keeps Bull Mesh Relay active in background',
      importance: Importance.low, // No sound
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isAndroid) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // This will be executed in the separate isolate
        onStart: onStart,

        // Auto start service
        autoStart: false, 
        isForegroundMode: true,
        
        notificationChannelId: 'bull_mesh_sentinel',
        initialNotificationTitle: 'Bull Mesh Relay Active',
        initialNotificationContent: 'Scanning for offline transactions...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        // Auto start service
        autoStart: false,
        // this will be executed when app is in foreground in separated isolate
        onForeground: onStart,
        // you have to enable background fetch capability on xcode project
        onBackground: onIosBackground,
      ),
    );
    
    // Bridge: Listen for events from Background Isolate
    service.on('incomingTx').listen((event) {
      if (event != null && event['hex'] != null) {
        final String txHex = event['hex'] as String;
        // Inject into Main Isolate's MeshService to trigger UI
        locator<MeshService>().injectIncomingTx(txHex);
      }
    });

    service.on('updateProgress').listen((event) {
       if (event != null && event['progress'] != null) {
          final double progress = event['progress'] as double;
          locator<MeshService>().injectDownloadProgress(progress);
       }
    });
  }
  
  static Future<void> start() async {
     final service = FlutterBackgroundService();
     if (!await service.isRunning()) {
        service.startService();
     }
  }
  
  static Future<void> stop() async {
     final service = FlutterBackgroundService();
     service.invoke("stopService");
  }

  // PRAGMA VM: ENTRY POINT
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Only available for flutter 3.0.0 and later
    DartPluginRegistrant.ensureInitialized();
    
    // NOTE: This runs in a SEPARATE ISOLATE. 
    // Usage of 'locator' here requires re-initialization or avoiding it.
    // We will instantiate a fresh MeshService.
    
    final meshService = MeshService(); 
    
    // Listen to events from Main Isolate
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
    
    // Start Mesh Scanning Logic
    try {
       print("MeshSentinel: Starting Scan in Background Isolate...");
       
       // Setup Bridge: Background Mesh -> Main Isolate
       meshService.incomingTransactions.listen((txHex) {
          service.invoke('incomingTx', {'hex': txHex});
       });

       meshService.downloadProgressNotifier.addListener(() {
          service.invoke('updateProgress', {'progress': meshService.downloadProgressNotifier.value});
       });

       // We only want to SCAN (Relay) in background, not Advertise (usually)
       await meshService.startScanningForRelay();
       
    } catch (e) {
       print("MeshSentinel: Error starting scan: $e");
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    // WidgetsFlutterBinding.ensureInitialized();
    // DartPluginRegistrant.ensureInitialized();
    return true;
  }
}

import 'dart:io';

// ... class Platform removed code replacement ...
