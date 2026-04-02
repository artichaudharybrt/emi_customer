package com.rohit.emilockercustomer

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log

/**
 * Launcher icon is provided by [LauncherAlias] (MAIN+LAUNCHER). After login we disable the alias
 * so the app disappears from the drawer; [MainActivity] stays reachable via explicit intent.
 */
object LauncherAliasHelper {
    private const val TAG = "LauncherAliasHelper"
    private const val ALIAS_CLASS = "com.rohit.emilockercustomer.LauncherAlias"

    fun explicitMainActivityIntent(context: Context): Intent {
        return Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
    }

    fun setLauncherVisible(context: Context, visible: Boolean) {
        val app = context.applicationContext
        val cn = ComponentName(app.packageName, ALIAS_CLASS)
        val newState = if (visible) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } else {
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }
        try {
            app.packageManager.setComponentEnabledSetting(
                cn,
                newState,
                PackageManager.DONT_KILL_APP,
            )
            Log.d(TAG, "Launcher alias enabled=$visible")
        } catch (e: Exception) {
            Log.e(TAG, "setLauncherVisible: ${e.message}", e)
        }
    }

    /** Matches Flutter SharedPreferences keys used for session. */
    fun hasFlutterSession(context: Context): Boolean {
        val p = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = p.getString("flutter.auth_token", null)
        if (!token.isNullOrEmpty()) return true
        val google = p.getString("flutter.google_account", null)
        return !google.isNullOrEmpty()
    }

    fun syncLauncherEntryWithSession(context: Context) {
        setLauncherVisible(context, visible = !hasFlutterSession(context))
    }
}
