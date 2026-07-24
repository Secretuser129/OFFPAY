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
                    val name = call.argument<String>("name") ?: "OFFPAY-RECV"
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
            result.error("BLUETOOTH_DISABLED", "Bluetooth is disabled.", null)
            return
        }

        try {
            bluetoothAdapter.name = name
        } catch (e: Exception) {
            Log.w("OFFPAY_BLE", "Could not set adapter name: ${e.message}")
        }

        bluetoothAdvertiser = bluetoothAdapter.bluetoothLeAdvertiser
        if (bluetoothAdvertiser == null) {
            result.error("UNSUPPORTED", "BLE Advertising is not supported on this device hardware.", null)
            return
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .build()

        val pUuid = ParcelUuid(UUID.fromString(serviceUuidStr))

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .addServiceUuid(pUuid)
            .build()

        stopAdvertisingInternal()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                super.onStartSuccess(settingsInEffect)
                Log.d("OFFPAY_BLE", "Native BLE Advertising started successfully for: $name")
                result.success(true)
            }

            override fun onStartFailure(errorCode: Int) {
                super.onStartFailure(errorCode)
                Log.e("OFFPAY_BLE", "Native BLE Advertising failed with error code: $errorCode")
                result.error("ADVERTISE_FAILED", "Failed with error code $errorCode", null)
            }
        }

        try {
            bluetoothAdvertiser?.startAdvertising(settings, data, advertiseCallback)
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