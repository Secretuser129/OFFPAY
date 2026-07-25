package com.example.offpay

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.offpay/bluetooth"
    private val REQUEST_ENABLE_BT = 101

    private var pendingResult: MethodChannel.Result? = null
    private var bluetoothAdvertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null
    private var methodChannel: MethodChannel? = null
    private var gattServer: BluetoothGattServer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enableBluetooth" -> {
                    pendingResult = result
                    enableBluetooth()
                }
                "startAdvertising" -> {
                    val name = call.argument<String>("name") ?: "OFFPAY"
                    val serviceUuidStr = call.argument<String>("serviceUuid") ?: "0000180a-0000-1000-8000-00805f9b34fb"
                    val charUuidStr = call.argument<String>("charUuid") ?: "00002a29-0000-1000-8000-00805f9b34fb"
                    startGattServer(serviceUuidStr, charUuidStr)
                    startAdvertising(name, serviceUuidStr, result)
                }
                "stopAdvertising" -> {
                    stopAdvertising(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startAdvertising(name: String, serviceUuidStr: String, result: MethodChannel.Result) {
        val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            Log.e("OFFPAY_BLE", "Bluetooth adapter is null or disabled")
            result.error("BLUETOOTH_DISABLED", "Bluetooth is disabled.", null)
            return
        }

        // Truncate name to max 20 bytes to fit in 31-byte scan response
        // Scan response structure: [length byte][type byte][name bytes] = 2 + name.length
        // 20 chars + 2 overhead = 22 bytes, well under the 31-byte limit
        val safeName = if (name.length > 20) name.substring(0, 20) else name

        try {
            bluetoothAdapter.name = safeName
            Log.d("OFFPAY_BLE", "Set adapter name to: $safeName")
        } catch (e: SecurityException) {
            Log.w("OFFPAY_BLE", "SecurityException setting adapter name (missing BLUETOOTH_CONNECT?): ${e.message}")
        } catch (e: Exception) {
            Log.w("OFFPAY_BLE", "Could not set adapter name: ${e.message}")
        }

        bluetoothAdvertiser = bluetoothAdapter.bluetoothLeAdvertiser
        if (bluetoothAdvertiser == null) {
            Log.e("OFFPAY_BLE", "BluetoothLeAdvertiser is null - hardware does not support BLE peripheral mode")
            result.error("UNSUPPORTED", "BLE Advertising is not supported on this device hardware.", null)
            return
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .setTimeout(0) // Advertise indefinitely until stopped
            .build()

        val pUuid = ParcelUuid(UUID.fromString(serviceUuidStr))

        // Primary advertisement data: Service UUID only (no name, no TX power)
        // This keeps primary payload well under 31 bytes
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addServiceUuid(pUuid)
            .build()

        // Scan response: Device name only
        // This is a SEPARATE 31-byte packet sent when a scanner requests more info
        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .setIncludeTxPowerLevel(false)
            .build()

        stopAdvertisingInternal()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                super.onStartSuccess(settingsInEffect)
                Log.d("OFFPAY_BLE", "✅ BLE Advertising STARTED successfully as: $safeName")
                result.success(true)
            }

            override fun onStartFailure(errorCode: Int) {
                super.onStartFailure(errorCode)
                val reason = when (errorCode) {
                    ADVERTISE_FAILED_DATA_TOO_LARGE -> "DATA_TOO_LARGE (payload > 31 bytes)"
                    ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "TOO_MANY_ADVERTISERS"
                    ADVERTISE_FAILED_ALREADY_STARTED -> "ALREADY_STARTED"
                    ADVERTISE_FAILED_INTERNAL_ERROR -> "INTERNAL_ERROR"
                    ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "FEATURE_UNSUPPORTED"
                    else -> "UNKNOWN ($errorCode)"
                }
                Log.e("OFFPAY_BLE", "❌ BLE Advertising FAILED: $reason")
                result.error("ADVERTISE_FAILED", "Failed: $reason", null)
            }
        }

        try {
            Log.d("OFFPAY_BLE", "Starting BLE advertising with name='$safeName', uuid='$serviceUuidStr'")
            bluetoothAdvertiser?.startAdvertising(settings, data, scanResponse, advertiseCallback)
        } catch (e: SecurityException) {
            Log.e("OFFPAY_BLE", "SecurityException starting advertising (missing BLUETOOTH_ADVERTISE?): ${e.message}")
            result.error("SECURITY_EXCEPTION", e.message, null)
        } catch (e: Exception) {
            Log.e("OFFPAY_BLE", "Exception starting advertising: ${e.message}")
            result.error("EXCEPTION", e.message, null)
        }
    }

    private fun stopAdvertising(result: MethodChannel.Result) {
        stopAdvertisingInternal()
        stopGattServer()
        result.success(true)
    }

    private fun stopGattServer() {
        if (gattServer != null) {
            try {
                gattServer?.close()
                gattServer = null
                Log.d("OFFPAY_BLE", "GATT Server closed")
            } catch (e: Exception) {
                Log.e("OFFPAY_BLE", "Error closing GATT server: ${e.message}")
            }
        }
    }

    private fun startGattServer(serviceUuidStr: String, charUuidStr: String) {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        if (gattServer != null) {
            return // already running
        }
        
        try {
            gattServer = bluetoothManager.openGattServer(this, object : BluetoothGattServerCallback() {
                override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                    super.onConnectionStateChange(device, status, newState)
                    Log.d("OFFPAY_BLE", "GATT Connection state change: $newState")
                }

                override fun onCharacteristicWriteRequest(
                    device: BluetoothDevice,
                    requestId: Int,
                    characteristic: BluetoothGattCharacteristic,
                    preparedWrite: Boolean,
                    responseNeeded: Boolean,
                    offset: Int,
                    value: ByteArray?
                ) {
                    super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value)
                    Log.d("OFFPAY_BLE", "GATT Write received")
                    
                    if (responseNeeded) {
                        gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                    }
                    
                    if (value != null) {
                        val payload = String(value)
                        Handler(Looper.getMainLooper()).post {
                            methodChannel?.invokeMethod("onPaymentReceived", payload)
                        }
                    }
                }
            })

            val service = BluetoothGattService(
                UUID.fromString(serviceUuidStr),
                BluetoothGattService.SERVICE_TYPE_PRIMARY
            )
            
            val characteristic = BluetoothGattCharacteristic(
                UUID.fromString(charUuidStr),
                BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
                BluetoothGattCharacteristic.PERMISSION_WRITE
            )
            
            service.addCharacteristic(characteristic)
            gattServer?.addService(service)
            Log.d("OFFPAY_BLE", "GATT Server started")
            
        } catch (e: SecurityException) {
            Log.e("OFFPAY_BLE", "SecurityException starting GATT: ${e.message}")
        } catch (e: Exception) {
            Log.e("OFFPAY_BLE", "Exception starting GATT: ${e.message}")
        }
    }

    private fun stopAdvertisingInternal() {
        if (bluetoothAdvertiser != null && advertiseCallback != null) {
            try {
                bluetoothAdvertiser?.stopAdvertising(advertiseCallback)
                Log.d("OFFPAY_BLE", "BLE Advertising stopped")
            } catch (e: Exception) {
                Log.e("OFFPAY_BLE", "Error stopping advertising: ${e.message}")
            }
            advertiseCallback = null
        }
    }

    private fun enableBluetooth() {
        val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()

        when {
            bluetoothAdapter == null -> {
                pendingResult?.error("UNSUPPORTED", "Device does not support Bluetooth.", null)
                pendingResult = null
            }
            !bluetoothAdapter.isEnabled -> {
                val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT)
                Log.d("Bluetooth", "Requesting Bluetooth enable from user.")
            }
            else -> {
                pendingResult?.success(true)
                pendingResult = null
            }
        }
    }

    @Deprecated("startActivityForResult/onActivityResult are deprecated but still used by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_ENABLE_BT) {
            val resultToSend = resultCode == Activity.RESULT_OK
            pendingResult?.success(resultToSend)
            pendingResult = null

            Log.d("Bluetooth", "Received result for enable: $resultToSend")
        }
    }
}