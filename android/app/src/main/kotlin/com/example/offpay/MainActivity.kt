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
                "getBluetoothAddress" -> {
                    val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
                    var address = bluetoothAdapter?.address
                    if (address == null || address == "02:00:00:00:00:00") {
                        try {
                            val mServiceField = bluetoothAdapter?.javaClass?.getDeclaredField("mService")
                            mServiceField?.isAccessible = true
                            val btManagerService = mServiceField?.get(bluetoothAdapter)
                            if (btManagerService != null) {
                                val getAddressMethod = btManagerService.javaClass.getMethod("getAddress")
                                val realAddr = getAddressMethod.invoke(btManagerService) as? String
                                if (!realAddr.isNullOrEmpty() && realAddr != "02:00:00:00:00:00") {
                                    address = realAddr
                                }
                            }
                        } catch (e: Exception) {
                            Log.d("OFFPAY_BLE", "Could not reflect Bluetooth address: ${e.message}")
                        }
                    }
                    if (address == null || address == "02:00:00:00:00:00") {
                        val prefs = getSharedPreferences("OffpayPrefs", Context.MODE_PRIVATE)
                        var savedMac = prefs.getString("real_ble_mac", null)
                        if (savedMac == null) {
                            val bytes = ByteArray(6)
                            java.util.Random().nextBytes(bytes)
                            bytes[0] = (bytes[0].toInt() and 0xFE or 0x02).toByte()
                            savedMac = String.format("%02X:%02X:%02X:%02X:%02X:%02X", bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5])
                            prefs.edit().putString("real_ble_mac", savedMac).apply()
                        }
                        address = savedMac
                    }
                    result.success(address)
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

        // Truncate name to max 8 bytes for service data (BLE ad packet = 31 bytes max)
        // Service UUID (16 bytes) + Service Data header (4 bytes) + name (8 bytes) = 28 bytes, safe
        val shortName = if (safeName.length > 8) safeName.substring(0, 8) else safeName

        val pUuid = ParcelUuid(UUID.fromString(serviceUuidStr))

        // Primary advertisement data: Service UUID + short name in service data
        // This ensures Android 8-14 scanners detect OFFPAY immediately
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(false)
            .addServiceUuid(pUuid)
            .addServiceData(pUuid, shortName.toByteArray(Charsets.UTF_8))
            .build()

        // Scan response: Full device name + TX power for Android 8-11 RSSI calibration
        val scanResponse = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .setIncludeTxPowerLevel(true)
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
                if (errorCode == ADVERTISE_FAILED_DATA_TOO_LARGE) {
                    Log.w("OFFPAY_BLE", "Retrying BLE advertising without scanResponse to avoid DATA_TOO_LARGE...")
                    try {
                        bluetoothAdvertiser?.startAdvertising(settings, data, null, object : AdvertiseCallback() {
                            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                                Log.d("OFFPAY_BLE", "✅ BLE Advertising retry SUCCESS as: $safeName")
                                result.success(true)
                            }
                            override fun onStartFailure(err: Int) {
                                result.error("ADVERTISE_FAILED", "Retry failed: $err", null)
                            }
                        })
                        return
                    } catch (e: Exception) {}
                }
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

    private val writeBuffers = HashMap<String, java.io.ByteArrayOutputStream>()

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
                    if (newState == android.bluetooth.BluetoothProfile.STATE_DISCONNECTED) {
                        writeBuffers.remove(device.address)
                    }
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
                    Log.d("OFFPAY_BLE", "GATT Write received: preparedWrite=$preparedWrite, offset=$offset, size=${value?.size ?: 0}")
                    
                    if (value != null) {
                        val deviceAddress = device.address
                        if (preparedWrite) {
                            val buffer = writeBuffers.getOrPut(deviceAddress) { java.io.ByteArrayOutputStream() }
                            buffer.write(value)
                        } else {
                            val payload = String(value, Charsets.UTF_8)
                            Handler(Looper.getMainLooper()).post {
                                methodChannel?.invokeMethod("onPaymentReceived", payload)
                            }
                        }
                    }

                    if (responseNeeded) {
                        gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                    }
                }

                override fun onExecuteWrite(
                    device: BluetoothDevice,
                    requestId: Int,
                    execute: Boolean
                ) {
                    super.onExecuteWrite(device, requestId, execute)
                    Log.d("OFFPAY_BLE", "GATT Execute write request: execute=$execute")
                    val deviceAddress = device.address
                    val buffer = writeBuffers.remove(deviceAddress)

                    if (execute && buffer != null) {
                        val fullData = buffer.toByteArray()
                        val payload = String(fullData, Charsets.UTF_8)
                        Log.d("OFFPAY_BLE", "GATT Execute write payload size: ${fullData.size}")
                        Handler(Looper.getMainLooper()).post {
                            methodChannel?.invokeMethod("onPaymentReceived", payload)
                        }
                    }

                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
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