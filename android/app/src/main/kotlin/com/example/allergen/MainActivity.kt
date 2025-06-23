// android/app/src/main/kotlin/com/yourapp/MainActivity.kt
package com.example.allergen

import android.Manifest
import android.content.pm.PackageManager
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "emergency_sms"
    private val SMS_PERMISSION_REQUEST = 101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSMS" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")
                    
                    if (phoneNumber != null && message != null) {
                        sendSMS(phoneNumber, message, result)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Phone number and message are required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun sendSMS(phoneNumber: String, message: String, result: MethodChannel.Result) {
        try {
            // Check if SMS permission is granted
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) 
                != PackageManager.PERMISSION_GRANTED) {
                result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                return
            }

            val smsManager = SmsManager.getDefault()
            
            // For long messages, divide into multiple parts
            val parts = smsManager.divideMessage(message)
            
            if (parts.size == 1) {
                // Single SMS
                smsManager.sendTextMessage(phoneNumber, null, message, null, null)
            } else {
                // Multiple SMS parts
                smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
            }
            
            result.success(true)
            
        } catch (e: Exception) {
            result.error("SMS_FAILED", "Failed to send SMS: ${e.message}", null)
        }
    }
}