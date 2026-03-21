package com.rohit.emilockercustomer

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

/**
 * Listens for SIM state change. When user changes SIM, posts new SIM details + number
 * to backend in background (same API as first-time permission grant, with simChange: true).
 */
class SimChangeReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SimChangeReceiver"
        private const val PREFS_NAME = "sim_change_prefs"
        private const val KEY_LAST_SIM_ID = "last_sim_id"
        private const val API_URL = "https://dev.api.fasstpay.co/api/device-sim-details"

        /** Called from Flutter after posting SIM details so we don't double-post on next SIM_LOADED. */
        @JvmStatic
        fun saveCurrentSimId(context: Context) {
            val id = getCurrentSimIdStatic(context)
            if (id != null) {
                context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .edit()
                    .putString(KEY_LAST_SIM_ID, id)
                    .commit()
                Log.d(TAG, "Saved current SIM id: $id")
            }
        }

        internal fun getCurrentSimIdStatic(context: Context): String? {
            return try {
                val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                val parts = mutableListOf<String>()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                    val subMgr = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                    val subs = subMgr?.activeSubscriptionInfoList
                    if (!subs.isNullOrEmpty()) {
                        subs.mapNotNull { it.subscriptionId }.sorted().forEach { parts.add("s$it") }
                    }
                }
                if (parts.isEmpty()) {
                    @Suppress("DEPRECATION")
                    tm.subscriberId?.takeIf { it.isNotBlank() }?.let { parts.add(it) }
                }
                parts.joinToString("|").takeIf { it.isNotBlank() }
            } catch (e: Exception) {
                Log.e(TAG, "getCurrentSimId: ${e.message}")
                null
            }
        }

        /** Called from FCM when backend sends get_sim_details_command – collect SIM details and POST to API. */
        @JvmStatic
        fun postSimDetailsForFcm(context: Context) {
            Thread {
                try {
                    Log.e(TAG, "[SIM] postSimDetailsForFcm started (background thread)")
                    if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
                        Log.e(TAG, "[SIM] ❌ READ_PHONE_STATE not granted – skipping POST")
                        return@Thread
                    }
                    Log.e(TAG, "[SIM] ✅ READ_PHONE_STATE granted, collecting SIM details...")
                    val body = collectSimDetailsStatic(context, simChange = false)
                    if (body == null) {
                        Log.e(TAG, "[SIM] ❌ Failed to collect SIM details (body=null)")
                        return@Thread
                    }
                    Log.e(TAG, "[SIM] Collected: phoneNumber=${body.optString("phoneNumber", "")}, operator=${body.optString("simOperatorName", "")}, simCount=${body.opt("simCount")}")
                    val token = getFlutterAuthTokenStatic(context)
                    if (token.isNullOrEmpty()) {
                        Log.e(TAG, "[SIM] ⚠️ No auth token – will POST without Authorization header")
                    } else {
                        Log.e(TAG, "[SIM] ✅ Auth token present (length=${token.length})")
                    }
                    Log.e(TAG, "[SIM] POSTing to $API_URL ...")
                    postToApiStatic(body, token)
                    Log.e(TAG, "[SIM] get_sim_details_command flow finished")
                } catch (e: Exception) {
                    Log.e(TAG, "[SIM] ❌ get_sim_details_command error: ${e.message}", e)
                }
            }.start()
        }

        private fun getFlutterAuthTokenStatic(context: Context): String? {
            return try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.getString("flutter.auth_token", null)?.takeIf { it.isNotEmpty() }
            } catch (e: Exception) {
                Log.e(TAG, "getFlutterAuthToken: ${e.message}")
                null
            }
        }

        private fun collectSimDetailsStatic(context: Context, simChange: Boolean): JSONObject? {
            return try {
                val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                val json = JSONObject()
                var phoneNumber: String? = null
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_NUMBERS) == PackageManager.PERMISSION_GRANTED) {
                        phoneNumber = tm.line1Number?.takeIf { it.isNotBlank() }
                    }
                }
                if (phoneNumber.isNullOrBlank()) {
                    @Suppress("DEPRECATION")
                    phoneNumber = tm.line1Number?.takeIf { it.isNotBlank() }
                }
                json.put("phoneNumber", phoneNumber ?: "")
                json.put("simOperatorName", tm.simOperatorName?.takeIf { it.isNotBlank() } ?: "")
                json.put("simCountryIso", tm.simCountryIso?.takeIf { it.isNotBlank() } ?: "")
                json.put("networkOperatorName", tm.networkOperatorName?.takeIf { it.isNotBlank() } ?: "")
                json.put("simCount", tm.phoneCount)
                json.put("simChange", simChange)
                json.put("recordedAt", java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }.format(java.util.Date()))
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        @Suppress("DEPRECATION")
                        json.put("deviceId", tm.deviceId ?: "")
                    } catch (e: SecurityException) {
                        json.put("deviceId", "")
                    }
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                    val subMgr = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                    val subs = subMgr?.activeSubscriptionInfoList
                    val carrierNames = JSONArray()
                    val simNumbers = JSONArray()
                    if (subs != null) {
                        for (info in subs) {
                            info.carrierName?.toString()?.takeIf { it.isNotBlank() }?.let { carrierNames.put(it) }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                info.number?.takeIf { it.isNotBlank() }?.let { simNumbers.put(it) }
                            }
                        }
                    }
                    json.put("carrierNames", carrierNames)
                    json.put("simNumbers", simNumbers)
                }
                json
            } catch (e: Exception) {
                Log.e(TAG, "[SIM] ❌ collectSimDetails: ${e.message}", e)
                null
            }
        }

        private fun postToApiStatic(body: JSONObject, authToken: String?) {
            var conn: HttpURLConnection? = null
            try {
                Log.e(TAG, "[SIM] POST request body (summary): $body")
                val url = URL(API_URL)
                conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                if (!authToken.isNullOrEmpty()) {
                    conn.setRequestProperty("Authorization", "Bearer $authToken")
                }
                conn.doOutput = true
                conn.connectTimeout = 15000
                conn.readTimeout = 15000
                conn.outputStream.use { os: OutputStream ->
                    os.write(body.toString().toByteArray(Charsets.UTF_8))
                }
                val code = conn.responseCode
                val responseMessage = conn.responseMessage ?: ""
                if (code in 200..299) {
                    Log.e(TAG, "[SIM] ✅ device-sim-details POST success: $code $responseMessage")
                } else {
                    Log.e(TAG, "[SIM] ❌ device-sim-details POST failed: $code $responseMessage")
                }
            } catch (e: Exception) {
                Log.e(TAG, "[SIM] ❌ postSimDetailsToApi error: ${e.message}", e)
            } finally {
                conn?.disconnect()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != "android.intent.action.SIM_STATE_CHANGED") return
        val state = intent.getStringExtra("ss") ?: return
        Log.e(TAG, "[SIM] SIM_STATE_CHANGED received, state=$state")
        if (state != "LOADED" && state != "READY") return

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
            Log.e(TAG, "[SIM] ❌ READ_PHONE_STATE not granted, skipping SIM change post")
            return
        }

        Thread {
            try {
                val currentSimId = SimChangeReceiver.getCurrentSimIdStatic(context) ?: return@Thread
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val lastSimId = prefs.getString(KEY_LAST_SIM_ID, null)
                if (currentSimId == lastSimId) {
                    Log.e(TAG, "[SIM] Same SIM as before (id=$currentSimId), no post")
                    return@Thread
                }
                Log.e(TAG, "[SIM] SIM change detected: last=$lastSimId current=$currentSimId → posting to API")
                val details = collectSimDetails(context) ?: return@Thread
                val authToken = getFlutterAuthToken(context)
                postSimDetailsToApi(details, authToken)
                prefs.edit().putString(KEY_LAST_SIM_ID, currentSimId).commit()
                Log.e(TAG, "[SIM] ✅ SIM change details posted successfully, saved simId=$currentSimId")
            } catch (e: Exception) {
                Log.e(TAG, "[SIM] ❌ SIM change handle error: ${e.message}", e)
            }
        }.start()
    }

    private fun collectSimDetails(context: Context): JSONObject? {
        return try {
            val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            val json = JSONObject()
            var phoneNumber: String? = null
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_NUMBERS) == PackageManager.PERMISSION_GRANTED) {
                    phoneNumber = tm.line1Number?.takeIf { it.isNotBlank() }
                }
            }
            if (phoneNumber.isNullOrBlank()) {
                @Suppress("DEPRECATION")
                phoneNumber = tm.line1Number?.takeIf { it.isNotBlank() }
            }
            json.put("phoneNumber", phoneNumber ?: "")
            json.put("simOperatorName", tm.simOperatorName?.takeIf { it.isNotBlank() } ?: "")
            json.put("simCountryIso", tm.simCountryIso?.takeIf { it.isNotBlank() } ?: "")
            json.put("networkOperatorName", tm.networkOperatorName?.takeIf { it.isNotBlank() } ?: "")
            json.put("simCount", tm.phoneCount)
            json.put("simChange", true)
            json.put("recordedAt", java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }.format(java.util.Date()))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    @Suppress("DEPRECATION")
                    json.put("deviceId", tm.deviceId ?: "")
                } catch (e: SecurityException) {
                    json.put("deviceId", "")
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                val subMgr = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                val subs = subMgr?.activeSubscriptionInfoList
                val carrierNames = JSONArray()
                val simNumbers = JSONArray()
                if (subs != null) {
                    for (info in subs) {
                        info.carrierName?.toString()?.takeIf { it.isNotBlank() }?.let { carrierNames.put(it) }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            info.number?.takeIf { it.isNotBlank() }?.let { simNumbers.put(it) }
                        }
                    }
                }
                json.put("carrierNames", carrierNames)
                json.put("simNumbers", simNumbers)
            }
            json
        } catch (e: Exception) {
            Log.e(TAG, "collectSimDetails: ${e.message}", e)
            null
        }
    }

    private fun getFlutterAuthToken(context: Context): String? {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getString("flutter.auth_token", null)?.takeIf { it.isNotEmpty() }
        } catch (e: Exception) {
            Log.e(TAG, "getFlutterAuthToken: ${e.message}")
            null
        }
    }

    private fun postSimDetailsToApi(body: JSONObject, authToken: String?) {
        var conn: HttpURLConnection? = null
        try {
            val url = URL(API_URL)
            conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            if (!authToken.isNullOrEmpty()) {
                conn.setRequestProperty("Authorization", "Bearer $authToken")
            }
            conn.doOutput = true
            conn.connectTimeout = 15000
            conn.readTimeout = 15000
            conn.outputStream.use { os: OutputStream ->
                os.write(body.toString().toByteArray(Charsets.UTF_8))
            }
            val code = conn.responseCode
            if (code in 200..299) {
                Log.d(TAG, "device-sim-details POST success: $code (simChange=true)")
            } else {
                Log.w(TAG, "device-sim-details POST failed: $code ${conn.responseMessage}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "postSimDetailsToApi error: ${e.message}", e)
        } finally {
            conn?.disconnect()
        }
    }
}
