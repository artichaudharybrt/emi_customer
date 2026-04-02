package com.rohit.emilockercustomer

import android.app.Application
import android.os.Handler
import android.os.Looper

/**
 * Process start par logged-in user ke liye background guard chalata hai (FCM / EMI commands).
 */
class EmiLockerApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Handler(Looper.getMainLooper()).post {
            BackgroundGuard.ensureRunning(this)
            LauncherAliasHelper.syncLauncherEntryWithSession(this)
        }
    }
}
