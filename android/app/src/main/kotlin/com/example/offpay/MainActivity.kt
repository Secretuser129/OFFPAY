package com.example.offpay   // Make sure this matches your AndroidManifest package

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.offpay/bluetooth"
    private val REQUEST_ENABLE_BT = 101

    // Hold the result until we get a response from the system dialog
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "enableBluetooth") {
                pendingResult = result
                enableBluetooth()
            } else {
                result.notImplemented()
            }
        }
    }

    private fun enableBluetooth() {
        val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()

        when {
            bluetoothAdapter == null -> {
                // Device does not support Bluetooth
                pendingResult?.error(
                    "UNSUPPORTED",
                    "Device does not support Bluetooth.",
                    null
                )
                pendingResult = null
            }

            !bluetoothAdapter.isEnabled -> {
                // Ask user to enable Bluetooth
                val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT)
                Log.d("Bluetooth", "Requesting Bluetooth enable from user.")
                // Do NOT resolve pendingResult here; wait for onActivityResult
            }

            else -> {
                // Already enabled
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