package com.example.offpay

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Intent
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableBluetooth" -> {
                    pendingResult = result
                    enableBluetooth()
                }
                "startAdvertising" -> {
                    val name = call.argument<String>("name") ?: "OFFPAY"
                    val serviceUuidStr = call.argument<String>("serviceUuid") ?: "0000180a-0000-1000-8000-00805f9b34fb"
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

        // Truncate name to max 8 bytes to guarantee it fits in 31-byte scan response
        // Scan response structure: [length byte][type byte][name bytes] = 2 + name.length
        // Max safe name length = 29 bytes, but shorter is better for Android 10/11
        val safeName = if (name.length > 8) name.substring(0, 8) else name

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
        result.success(true)
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