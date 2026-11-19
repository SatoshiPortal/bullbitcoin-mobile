package com.bitbox.bitbox_flutter

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.StandardMethodCodec

class BitboxFlutterPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var usbManager: UsbManager? = null
    private var currentDevice: UsbDevice? = null
    private var currentConnection: UsbDeviceConnection? = null
    private var claimedInterface: UsbInterface? = null

    companion object {
        private const val ACTION_USB_PERMISSION = "com.bitbox.bitbox_flutter.USB_PERMISSION"
        
        private const val BITBOX02_VENDOR_ID = 0x03eb
        private const val BITBOX02_PRODUCT_ID = 0x2403
    }

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (ACTION_USB_PERMISSION == intent.action) {
                synchronized(this@BitboxFlutterPlugin) {
                    val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }

                    if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                        device?.let {
                            currentDevice = it
                        }
                    } else {
                        
                    }
                }
            }
        }
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = flutterPluginBinding.binaryMessenger
        channel = MethodChannel(
            messenger,
            "bitbox_flutter",
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue()
        )
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        usbManager = context?.getSystemService(Context.USB_SERVICE) as? UsbManager

        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context?.registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context?.registerReceiver(usbReceiver, filter)
        }
    }

    @Synchronized
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        try {
            when (call.method) {
                "scanDevices" -> scanDevices(result)
                "requestPermission" -> requestPermission(call, result)
                "openDevice" -> openDevice(call, result)
                "closeDevice" -> closeDevice(result)
                "sendData" -> sendData(call, result)
                "receiveData" -> receiveData(result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("UNHANDLED_ERROR", "Unhandled exception: ${e.message}", e.stackTraceToString())
        }
    }

    private fun scanDevices(result: Result) {
        try {
            val deviceList = usbManager?.deviceList ?: emptyMap()
            val bitboxDevices = mutableListOf<Map<String, Any>>()

            for ((_, device) in deviceList) {
                
                
                if (device.vendorId == BITBOX02_VENDOR_ID && device.productId == BITBOX02_PRODUCT_ID) {
                    val deviceInfo = mapOf(
                        "product" to (device.productName ?: "BitBox02"),
                        "serialNumber" to (device.serialNumber ?: "unknown"),
                        "deviceName" to device.deviceName
                    )
                    bitboxDevices.add(deviceInfo)
                }
            }

            result.success(bitboxDevices)
        } catch (e: Exception) {
            result.error("SCAN_ERROR", e.message, null)
        }
    }

    private fun requestPermission(call: MethodCall, result: Result) {
        try {
            val deviceName = call.argument<String>("deviceName")
            if (deviceName == null) {
                result.error("INVALID_ARGUMENT", "deviceName is required", null)
                return
            }

            val deviceList = usbManager?.deviceList ?: emptyMap()
            val device = deviceList[deviceName]

            if (device == null) {
                result.error("DEVICE_NOT_FOUND", "Device not found: $deviceName", null)
                return
            }

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
            val permissionIntent = PendingIntent.getBroadcast(context, 0, Intent(ACTION_USB_PERMISSION), flags)
            usbManager?.requestPermission(device, permissionIntent)

            result.success(true)
        } catch (e: Exception) {
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }

    private fun openDevice(call: MethodCall, result: Result) {
        try {
            val deviceName = call.argument<String>("deviceName")
            if (deviceName == null) {
                result.error("INVALID_ARGUMENT", "deviceName is required", null)
                return
            }

            val deviceList = usbManager?.deviceList ?: emptyMap()
            val device = deviceList[deviceName]

            if (device == null) {
                result.error("DEVICE_NOT_FOUND", "Device not found: $deviceName", null)
                return
            }

            if (!usbManager!!.hasPermission(device)) {
                result.error("NO_PERMISSION", "No permission for device", null)
                return
            }

            currentConnection = usbManager?.openDevice(device)
            if (currentConnection == null) {
                result.error("CONNECTION_ERROR", "Failed to open device", null)
                return
            }

            val intf = device.getInterface(0)
            if (!currentConnection!!.claimInterface(intf, true)) {
                currentConnection?.close()
                currentConnection = null
                result.error("CLAIM_INTERFACE_ERROR", "Failed to claim USB interface", null)
                return
            }

            currentDevice = device
            claimedInterface = intf // Store the claimed interface
            
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_ERROR", e.message, null)
        }
    }

    private fun closeDevice(result: Result) {
        try {
            // Release interface before closing
            if (claimedInterface != null && currentConnection != null) {
                currentConnection!!.releaseInterface(claimedInterface!!)
                
            }
            currentConnection?.close()
            currentConnection = null
            currentDevice = null
            claimedInterface = null
            result.success(true)
        } catch (e: Exception) {
            result.error("CLOSE_ERROR", e.message, null)
        }
    }

    private fun sendData(call: MethodCall, result: Result) {
        try {
            val data = call.argument<ByteArray>("data")
            if (data == null) {
                result.error("INVALID_ARGUMENT", "data is required", null)
                return
            }

            val device = currentDevice
            val connection = currentConnection
            
            if (device == null || connection == null) {
                result.error("NO_CONNECTION", "No device connection", null)
                return
            }

            val intf = claimedInterface
            if (intf == null) {
                result.error("INTERFACE_ERROR", "No interface claimed", null)
                return
            }

            var outEndpoint = intf.getEndpoint(0)
            for (i in 0 until intf.endpointCount) {
                val endpoint = intf.getEndpoint(i)
                if (endpoint.direction == android.hardware.usb.UsbConstants.USB_DIR_OUT) {
                    outEndpoint = endpoint
                    break
                }
            }

            if (outEndpoint == null) {
                result.error("ENDPOINT_ERROR", "OUT endpoint not found", null)
                return
            }

            val REPORT_SIZE = 64
            var offset = 0
            var totalWritten = 0
            
            while (offset < data.size) {
                val chunkSize = minOf(REPORT_SIZE, data.size - offset)
                val chunk = data.copyOfRange(offset, offset + chunkSize)
                
                val paddedChunk = if (chunk.size < REPORT_SIZE) {
                    chunk + ByteArray(REPORT_SIZE - chunk.size)
                } else {
                    chunk
                }
                
                val bytesWritten = connection.bulkTransfer(
                    outEndpoint,
                    paddedChunk,
                    paddedChunk.size,
                    60000  // 60 second timeout for user password entry
                )
                
                if (bytesWritten < 0) {
                    result.error("WRITE_ERROR", "USB write failed: $bytesWritten", null)
                    return
                }
                
                totalWritten += bytesWritten
                offset += chunkSize
            }
            result.success(totalWritten)
        } catch (e: Exception) {
            result.error("SEND_ERROR", e.message, null)
        }
    }

    private fun receiveData(call: MethodCall, result: Result) {
        try {
            val device = currentDevice
            val connection = currentConnection
            
            if (device == null || connection == null) {
                result.error("NO_CONNECTION", "No device connection", null)
                return
            }

            val intf = claimedInterface
            if (intf == null) {
                result.error("INTERFACE_ERROR", "No interface claimed", null)
                return
            }

            var inEndpoint = intf.getEndpoint(0)
            for (i in 0 until intf.endpointCount) {
                val endpoint = intf.getEndpoint(i)
                if (endpoint.direction == android.hardware.usb.UsbConstants.USB_DIR_IN) {
                    inEndpoint = endpoint
                    break
                }
            }

            if (inEndpoint == null) {
                result.error("ENDPOINT_ERROR", "IN endpoint not found", null)
                return
            }
            
            val REPORT_SIZE = 64
            val buffer = ByteArray(REPORT_SIZE)
            
            val bytesRead = connection.bulkTransfer(
                inEndpoint,
                buffer,
                buffer.size,
                60000  // 60 second timeout for user password entry
            )
            
            if (bytesRead < 0) {
                result.error("READ_ERROR", "USB read failed: $bytesRead", null)
                return
            }

            result.success(buffer.toList())
        } catch (e: Exception) {
            result.error("RECEIVE_ERROR", e.message, null)
        }
    }

    @Synchronized
    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        try {
            context?.unregisterReceiver(usbReceiver)
        } catch (e: Exception) {
            
        }
        currentConnection?.close()
        currentConnection = null
        currentDevice = null
        context = null
    }
    
    /**
     * Receive data from USB (for coordinator)
     */
    private fun receiveData(result: Result) {
        try {
            if (currentDevice == null || currentConnection == null) {
                result.error("DEVICE_NOT_CONNECTED", "No USB device connected", null)
                return
            }
            
            val device = currentDevice!!
            val connection = currentConnection!!
            
            val intf = claimedInterface ?: device.getInterface(0)
            
            var inEndpoint: android.hardware.usb.UsbEndpoint? = null
            for (i in 0 until intf.endpointCount) {
                val endpoint = intf.getEndpoint(i)
                if (endpoint.direction == android.hardware.usb.UsbConstants.USB_DIR_IN) {
                    inEndpoint = endpoint
                    break
                }
            }
            if (inEndpoint == null) {
                result.error("NO_ENDPOINT", "No USB input endpoint found", null)
                return
            }
            
            val response = ByteArray(64) // HID report size
            // An empty read must not hold up the next protocol keepalive.
            val bytesRead = connection.bulkTransfer(inEndpoint, response, response.size, 20)
            
            if (bytesRead <= 0) {
                result.success(ByteArray(0))
                return
            }
            result.success(response.copyOf(bytesRead))
        } catch (e: Exception) {
            result.error("RECEIVE_ERROR", e.message, null)
        }
    }
}

