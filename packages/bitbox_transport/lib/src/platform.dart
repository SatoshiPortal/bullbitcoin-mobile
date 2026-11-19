import 'package:flutter/services.dart';

class BitBox02Device {
  final String product;
  final String serialNumber;
  final String deviceName;

  const BitBox02Device({
    required this.product,
    required this.serialNumber,
    required this.deviceName,
  });
}

class BitBoxFlutterPlatform {
  static final _channel = const MethodChannel('bitbox_flutter');

  static Future<List<BitBox02Device>> scanDevices() async {
    final List<dynamic> devices = await _channel.invokeMethod('scanDevices');

    return devices.map((device) {
      return BitBox02Device(
        product: device['product'] as String,
        serialNumber: device['serialNumber'] as String,
        deviceName: device['deviceName'] as String,
      );
    }).toList();
  }

  static Future<bool> requestPermission(String deviceName) async {
    final bool result = await _channel.invokeMethod('requestPermission', {
      'deviceName': deviceName,
    });
    return result;
  }

  static Future<bool> openDevice(String deviceName) async {
    final bool result = await _channel.invokeMethod('openDevice', {
      'deviceName': deviceName,
    });
    return result;
  }

  static Future<bool> closeDevice() async {
    final bool result = await _channel.invokeMethod('closeDevice');
    return result;
  }

  static Future<void> sendData(Uint8List data) async {
    await _channel.invokeMethod('sendData', {'data': data});
  }

  static Future<Uint8List> receiveData() async {
    final result = await _channel.invokeMethod('receiveData');
    return result as Uint8List;
  }
}
