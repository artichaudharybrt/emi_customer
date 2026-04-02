package com.rohit.emilockercustomer

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Build
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.LinearLayout
import android.widget.TextView
import android.content.BroadcastReceiver
import android.content.IntentFilter

/**
 * App Usage Monitor Service
 * 
 * This accessibility service monitors when user tries to access app info
 * or pause the Fasst Pay app, and shows overlay to prevent it.
 * 
 * Features:
 * - Detects "App info" clicks
 * - Detects "Pause app" clicks  
 * - Shows overlay when user tries to access these options
 * - Prevents app from being paused or modified
 */
class AppUsageMonitorService : AccessibilityService() {
    
    companion object {
        private const val TAG = "AppUsageMonitorService"
        const val ACTION_SHOW_TEST_OVERLAY = "com.rohit.emilockercustomer.SHOW_TEST_PROTECTION_OVERLAY"
        private var isServiceEnabled = false
        
        fun isEnabled(): Boolean = isServiceEnabled
    }
    
    private var testOverlayReceiver: BroadcastReceiver? = null
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var overlayParams: WindowManager.LayoutParams? = null
    private var dismissTimer: android.os.Handler? = null
    private var lastOverlayTime: Long = 0
    private val OVERLAY_COOLDOWN_MS = 1500L    // Cooldown only for content-changed triggers (not for direct clicks)
    private var lastOverlayTimeForClick: Long = 0
    private var lastSeenFasstPayTime: Long = 0
    private val FASST_PAY_RECENT_MS = 15000L
    private val LAUNCHER_UNINSTALL_GUARD_MS = 12000L
    /** After tapping Fasst Pay in Settings apps list, block Uninstall taps even if app info paints late. */
    private val SETTINGS_APP_FLOW_GUARD_MS = 45000L
    private var lastInstallerUninstallBlockTime: Long = 0
    private val INSTALLER_UNINSTALL_DEBOUNCE_MS = 280L
    private var lastImmediateLauncherBlockTime: Long = 0
    private val IMMEDIATE_LAUNCHER_BLOCK_DEBOUNCE_MS = 200L
    private var lastLauncherDialogBlockTime: Long = 0
    private val LAUNCHER_DIALOG_BLOCK_DEBOUNCE_MS = 1800L
    private var lastUserInteractionEventMs: Long = 0
    private val USER_INTERACTION_GATE_MS = 2200L
    private var uninstallGuardUntilMs: Long = 0
    /** Global BACK right after connect can close Flutter — skip handling briefly. */
    private var protectionGraceUntilMs: Long = 0
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.e(TAG, "========== ✅ APP USAGE MONITOR SERVICE CONNECTED ==========")
        Log.e(TAG, "✅ Service is now active and monitoring events")
        isServiceEnabled = true
        // Short grace: only soft paths (e.g. test overlay) skip; Settings/App blocks must never be blind for seconds.
        protectionGraceUntilMs = System.currentTimeMillis() + 1200L
        
        // Initialize WindowManager for direct overlay
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        Log.e(TAG, "✅ WindowManager initialized for overlay")
        
        // Configure accessibility service
        val info = AccessibilityServiceInfo().apply {
            // Monitor all events - ADDED TYPE_WINDOW_CONTENT_CHANGED for better detection
            eventTypes = AccessibilityEvent.TYPE_VIEW_CLICKED or 
                        AccessibilityEvent.TYPE_VIEW_SELECTED or
                        AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                        AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED or
                        AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            
            // Monitor all packages
            packageNames = null
            
            // Get all node info
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                   AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                   AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            
            // No delay
            notificationTimeout = 0
        }
        
        serviceInfo = info
        Log.e(TAG, "✅ Accessibility service configured with all event types")
        Log.e(TAG, "✅ Monitoring: CLICKS, SELECTIONS, WINDOW_CHANGES, TEXT_CHANGES, CONTENT_CHANGES")
        Log.e(TAG, "✅ Ready to detect Fasst Pay app clicks in Settings!")
        Log.e(TAG, "============================================================")
        
        try {
            android.widget.Toast.makeText(this, "Fasst Pay Protection is active", android.widget.Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Log.e(TAG, "Toast failed: ${e.message}")
        }
        
        testOverlayReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == ACTION_SHOW_TEST_OVERLAY) {
                    Log.e(TAG, "FasstPayOverlay: Test overlay requested via broadcast")
                    showProtectionOverlay(
                        "Protection test",
                        "If you see this, the protection overlay is working.",
                        force = true
                    )
                }
            }
        }.also { receiver ->
            val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) Context.RECEIVER_NOT_EXPORTED else 0
            registerReceiver(receiver, IntentFilter(ACTION_SHOW_TEST_OVERLAY), flag)
        }
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) {
            Log.w(TAG, "⚠️ Received null accessibility event")
            return
        }
        
        try {
            // Don't handle events from our own overlay
            if (event.packageName == packageName) {
                return
            }
            handleAccessibilityEvent(event)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in onAccessibilityEvent: ${e.message}", e)
        }
    }
    
    private fun handleAccessibilityEvent(event: AccessibilityEvent) {
        try {
            // Get event details
            val packageName = event.packageName?.toString()
            val className = event.className?.toString()
            val eventType = event.eventType
            val text = event.text?.toString()
            val pkg = packageName ?: ""
            val isClickOrSelect = (eventType == AccessibilityEvent.TYPE_VIEW_CLICKED || eventType == AccessibilityEvent.TYPE_VIEW_SELECTED)
            val isWindowChange = (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED)
            if (isClickOrSelect) {
                lastUserInteractionEventMs = System.currentTimeMillis()
            }
            // Keep service stable: skip everything except click/select + relevant window changes.
            if (!isClickOrSelect && !isWindowChange) return
            if (isWindowChange && !isRelevantProtectionPackage(pkg)) return

            // MIUI launcher uninstall popup (DeleteDialog) can bypass normal node scans.
            // Block it immediately from class/text signature.
            if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
                checkForMiuiDeleteDialog(event)
                checkForFastLauncherDragUninstallDialog(event)
            }
            
            // CRITICAL: Check for CLICK and SELECTED - both can indicate user tapped Fasst Pay / App info / Pause
            // SELECTED is used by some launchers/Settings for list items
            if (isClickOrSelect) {
                Log.e(TAG, "🖱️ CLICK/SELECT EVENT DETECTED - checking what was clicked")
                checkForImmediateLauncherUninstallTap(event)
                
                // FIRST: Check if user clicked on Fasst Pay app itself in Settings > Apps
                checkForFasstPayAppClick(event)
                
                // Settings > Additional settings (MIUI/OEM) — block path to Accessibility / special access
                checkForAdditionalSettingsMenuClick(event)
                
                // Factory reset / erase all data — anywhere in system Settings (e.g. Reset options)
                checkForFactoryResetMenuClick(event)
                
                // SECOND: Check for app control options (App info, Pause app)
                checkForAppControlClick(event)
                
                // App info screen can paint before row-ancestor match; re-check at front of queue + short backup.
                if (packageName == "com.android.settings" || packageName?.contains("settings") == true) {
                    val h = android.os.Handler(android.os.Looper.getMainLooper())
                    h.postAtFrontOfQueue { checkForAppInfoScreen(event) }
                    h.postDelayed({ checkForAppInfoScreen(event) }, 50)
                }
            }
            
            // NOTE: Avoid broad full-screen control scan on click/select.
            // It causes false positives on MIUI list interactions.
            
            // Refresh "recently seen" only on relevant window changes (prevents constant scanning).
            if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
                if (isSettingsPackage(pkg) || isLauncherPackage(pkg) || isUninstallRelatedPackage(pkg)) {
                    updateLastSeenFasstPayIfVisible()
                }
            }
            
            // Play Store / package installer uninstall dialogs for Fasst Pay
            if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                scanPackageInstallerOrPlayStoreUninstall()
            }
            if (eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED && isUninstallRelatedPackage(packageName)) {
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    scanPackageInstallerOrPlayStoreUninstall()
                }, 120)
            }
            if (isClickOrSelect && isUninstallRelatedPackage(packageName)) {
                scanPackageInstallerOrPlayStoreUninstall()
            }
            if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
                // Settings emits frequent CONTENT_CHANGED while scrolling app list.
                // Restrict risky-screen scan there to WINDOW_STATE_CHANGED only.
                val shouldScanDangerous = !isSettingsPackage(pkg) ||
                    eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
                if (shouldScanDangerous) {
                    if (overlayView != null) return
                    checkForDangerousScreensOnWindowChange(event)
                }
            }

            // Do NOT run checkForAppInfoScreen on WINDOW_STATE_CHANGED — Settings home uses the same
            // words as app info (Battery, Notifications, …) and falsely triggers overlay.
            
            // Do NOT run checkForAppInfoScreen on TYPE_WINDOW_CONTENT_CHANGED — it fires on every list scroll
            // and falsely matches "Fasst Pay" list rows as app info. Navigation to app info is covered by
            // WINDOW_STATE_CHANGED + click-path handlers.
            
            // Any click on Uninstall / OK inside uninstall flow for our app (all packages)
            if (isClickOrSelect) {
                checkForUninstallConfirmationClick(event)
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error handling accessibility event: ${e.message}", e)
        }
    }
    
    /** Play Store, OEM package installers, permission controller (some uninstall flows). */
    private fun isUninstallRelatedPackage(pkg: String?): Boolean {
        if (pkg == null) return false
        val p = pkg.lowercase()
        if (p.contains("packageinstaller")) return true
        if (p.contains("finsky")) return true
        if (p.contains("vending")) return true
        if (p.contains("permissioncontroller")) return true
        return false
    }

    private fun isLauncherPackage(pkg: String?): Boolean {
        if (pkg == null) return false
        val p = pkg.lowercase()
        return p == "com.miui.home" ||
            p.contains("miui.home") ||
            p.contains("launcher") ||
            p.contains("trebuchet") ||
            p.contains("quickstep")
    }

    private fun isSettingsPackage(pkg: String?): Boolean {
        if (pkg == null) return false
        return pkg == "com.android.settings" ||
            pkg == "com.miui.securitycenter" ||
            pkg.contains("settings", ignoreCase = true) ||
            pkg.contains("securitycenter", ignoreCase = true)
    }

    private fun isRelevantProtectionPackage(pkg: String): Boolean {
        if (pkg.isBlank()) return false
        val p = pkg.lowercase()
        return isSettingsPackage(pkg) ||
            isLauncherPackage(pkg) ||
            isUninstallRelatedPackage(pkg) ||
            p.contains("systemui") ||
            p == "com.miui.home"
    }

    /**
     * Server GET /users/me/uninstall-flag → when [canUserUninstallFlag] is true, user may uninstall;
     * skip EMI blocking overlays (Settings → Apps, factory reset, uninstall UI).
     */
    private fun isUninstallAllowedByServerFlag(): Boolean {
        return try {
            getSharedPreferences("protection_prefs", Context.MODE_PRIVATE)
                .getBoolean("can_user_uninstall", false)
        } catch (_: Exception) {
            false
        }
    }

    private fun checkForMiuiDeleteDialog(event: AccessibilityEvent) {
        try {
            if (isUninstallAllowedByServerFlag()) return
            val pkg = event.packageName?.toString() ?: return
            if (pkg != "com.miui.home") return
            val cls = event.className?.toString() ?: ""
            val txt = event.text?.joinToString(" ") ?: ""
            val isDeleteDialogClass = cls.contains("launcher.uninstall.DeleteDialog", ignoreCase = true)
            val hasUninstallPrompt = txt.contains("Uninstall", true) && txt.contains("Cancel", true)
            val hasOurAppInPrompt = txt.contains("Fasst Pay", true) || txt.contains("EMI Locker", true)
            if (!(isDeleteDialogClass || (hasUninstallPrompt && hasOurAppInPrompt))) return

            val now = System.currentTimeMillis()
            if (now - lastInstallerUninstallBlockTime < INSTALLER_UNINSTALL_DEBOUNCE_MS) return
            lastInstallerUninstallBlockTime = now

            Log.e(TAG, "🚨 MIUI DeleteDialog detected - forcing HOME + protection overlay")
            performGlobalAction(GLOBAL_ACTION_HOME)
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                showProtectionOverlay(
                    "Uninstall blocked",
                    "Fasst Pay cannot be uninstalled during EMI period",
                    force = true
                )
            }, 80)
        } catch (e: Exception) {
            Log.e(TAG, "checkForMiuiDeleteDialog: ${e.message}", e)
        }
    }

    /**
     * Fast path for drag-to-uninstall dialogs: block as soon as dialog appears,
     * before user taps the Uninstall button.
     */
    private fun checkForFastLauncherDragUninstallDialog(event: AccessibilityEvent) {
        try {
            if (isUninstallAllowedByServerFlag()) return
            val pkg = event.packageName?.toString() ?: return
            if (!isLauncherPackage(pkg)) return
            if (overlayView != null) return
            if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
            val now0 = System.currentTimeMillis()
            if (now0 - lastUserInteractionEventMs > USER_INTERACTION_GATE_MS) return

            val roots = mutableListOf<AccessibilityNodeInfo>()
            rootInActiveWindow?.let { roots.add(it) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                @Suppress("DEPRECATION")
                windows?.forEach { w -> w.root?.let { r -> if (roots.none { it == r }) roots.add(r) } }
            }
            if (roots.isEmpty()) return

            val uninstallKeys = listOf("Uninstall", "Remove", "Delete", "अनइंस्टॉल", "हटाए")
            val cancelKeys = listOf("Cancel", "No", "रद्द करें", "नहीं")
            val appKeys = listOf(
                "Fasst Pay", "FasstPay", "fasst pay", "EMI Locker", "Emi Locker",
                "emilockercustomer", "com.rohit.emilockercustomer"
            )

            for (root in roots) {
                val hasUninstall = findNodesByText(root, uninstallKeys).isNotEmpty()
                val hasCancel = findNodesByText(root, cancelKeys).isNotEmpty()
                val hasOurApp = findNodesByText(root, appKeys).isNotEmpty()
                if (!hasUninstall || !hasCancel || !hasOurApp) continue

                val now = System.currentTimeMillis()
                if (now - lastLauncherDialogBlockTime < LAUNCHER_DIALOG_BLOCK_DEBOUNCE_MS) return
                lastLauncherDialogBlockTime = now
                uninstallGuardUntilMs = now + LAUNCHER_UNINSTALL_GUARD_MS
                Log.e(TAG, "🚨 Fast launcher drag-uninstall dialog detected ($pkg) — pre-emptive HOME + overlay")
                performGlobalAction(GLOBAL_ACTION_HOME)
                showProtectionOverlay(
                    "Uninstall blocked",
                    "Fasst Pay cannot be uninstalled during EMI period",
                    force = true
                )
                return
            }
        } catch (e: Exception) {
            Log.e(TAG, "checkForFastLauncherDragUninstallDialog: ${e.message}", e)
        }
    }
    
    /**
     * Generic launcher uninstall dialog detector (also catches drag-to-uninstall flows).
     */
    /**
     * Fast-path block: launcher uninstall tap should be blocked instantly before any delayed scans.
     * This closes uninstall popup immediately so user can't press confirm in the delay window.
     */
    private fun checkForImmediateLauncherUninstallTap(event: AccessibilityEvent) {
        try {
            if (isUninstallAllowedByServerFlag()) return
            val pkg = event.packageName?.toString() ?: return
            if (!isLauncherPackage(pkg)) return
            val nowGate = System.currentTimeMillis()
            if (nowGate - lastUserInteractionEventMs > USER_INTERACTION_GATE_MS) return
            val uninstallKeywords = listOf("Uninstall", "Remove", "Delete", "अनइंस्टॉल", "हटाए")
            val cancelKeywords = listOf("Cancel", "No", "रद्द करें", "नहीं")
            val clickedText = event.text?.toString() ?: ""
            val contentDesc = event.contentDescription?.toString() ?: ""
            val uninstallTapped = uninstallKeywords.any { key ->
                clickedText.contains(key, ignoreCase = true) || contentDesc.contains(key, ignoreCase = true)
            } || nodeOrAncestorsContainText(event.source, uninstallKeywords)
            
            val appKeywords = listOf(
                "Fasst Pay", "FasstPay", "fasst pay", "Fasst pay",
                "EMI Locker", "Emi Locker", "emilockercustomer",
                "com.rohit.emilockercustomer", "rohit.emilockercustomer"
            )
            if (!uninstallTapped) return
            // STRICT: only near clicked node context (self + limited ancestors), no root/dialog inference.
            val sourceTargetsOurApp = nodeSelfOrNearAncestorsContainText(event.source, appKeywords, maxDepth = 2)
            val hasDialogClass = event.className?.toString()?.contains("dialog", ignoreCase = true) == true
            val root = rootInActiveWindow
            val dialogClearlyForOurApp = hasDialogClass &&
                root != null &&
                findNodesByText(root, uninstallKeywords).isNotEmpty() &&
                findNodesByText(root, cancelKeywords).isNotEmpty() &&
                findNodesByText(root, appKeywords).isNotEmpty()
            if (!sourceTargetsOurApp && !dialogClearlyForOurApp) return
            
            val now = System.currentTimeMillis()
            if (now - lastImmediateLauncherBlockTime < IMMEDIATE_LAUNCHER_BLOCK_DEBOUNCE_MS) return
            lastImmediateLauncherBlockTime = now
            uninstallGuardUntilMs = now + LAUNCHER_UNINSTALL_GUARD_MS
            
            Log.e(TAG, "🚨 Immediate launcher uninstall tap detected — forcing HOME + overlay")
            performGlobalAction(GLOBAL_ACTION_HOME)
            showProtectionOverlay(
                "Uninstall blocked",
                "Fasst Pay cannot be uninstalled during EMI period",
                force = true
            )
        } catch (e: Exception) {
            Log.e(TAG, "checkForImmediateLauncherUninstallTap: ${e.message}", e)
        }
    }

    /**
     * Window/content-change guard so risky screens are blocked even when CLICK event is missed.
     */
    private fun checkForDangerousScreensOnWindowChange(event: AccessibilityEvent) {
        try {
            val pkg = event.packageName?.toString() ?: ""
            val fromRelevantPkg = isSettingsPackage(pkg) || isUninstallRelatedPackage(pkg)
            if (!fromRelevantPkg) return
            
            // In Settings app list screens (e.g., "Downloaded apps"), content-change fires on scroll.
            // Do not auto-block there; actual tap actions are already blocked by click handlers.
            if (isSettingsPackage(pkg) && isLikelyAppsListScreen()) {
                return
            }

            val appKeys = listOf(
                "Fasst Pay", "FasstPay", "fasst pay", "EMI Locker", "Emi Locker",
                "emilockercustomer", "com.rohit.emilockercustomer", "rohit.emilockercustomer"
            )
            val uninstallKeys = listOf("Uninstall", "Remove", "Delete", "अनइंस्टॉल", "हटाए")
            val resetKeys = factoryResetScreenKeywords()

            val roots = mutableListOf<AccessibilityNodeInfo>()
            rootInActiveWindow?.let { roots.add(it) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                @Suppress("DEPRECATION")
                windows?.forEach { w -> w.root?.let { r -> if (roots.none { it == r }) roots.add(r) } }
            }

            for (root in roots) {
                val hasOurApp = findNodesByText(root, appKeys).isNotEmpty() || checkForFasstPayPackage(root)
                val hasUninstallUi = findNodesByText(root, uninstallKeys).isNotEmpty()
                val hasResetUi = findNodesByText(root, resetKeys).isNotEmpty()
                val recentFasstPay = System.currentTimeMillis() - lastSeenFasstPayTime < FASST_PAY_RECENT_MS
                val uninstallGuardActive = System.currentTimeMillis() < uninstallGuardUntilMs

                // Keep WINDOW_CHANGE logic strict and deterministic:
                // - Always block true reset screens.
                // - App info blocking is handled by checkForAppInfoScreen + click handlers.
                val shouldBlockSettingsDanger = isSettingsPackage(pkg) && hasResetUi
                val shouldBlockInstallerUninstall = isUninstallRelatedPackage(pkg) && hasUninstallUi &&
                    (hasOurApp || recentFasstPay || uninstallGuardActive)

                if (shouldBlockSettingsDanger || shouldBlockInstallerUninstall) {
                    val now = System.currentTimeMillis()
                    if (now - lastInstallerUninstallBlockTime < INSTALLER_UNINSTALL_DEBOUNCE_MS) return
                    lastInstallerUninstallBlockTime = now
                    Log.e(TAG, "🚨 Dangerous screen detected on window change ($pkg) — blocking now")
                    blockImmediatelyAndShowOverlay(
                        "Action Blocked",
                        "App info, pause, uninstall and reset actions are blocked during EMI period"
                    )
                    return
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "checkForDangerousScreensOnWindowChange: ${e.message}", e)
        }
    }
    
    private fun factoryResetScreenKeywords(): List<String> = listOf(
        "Erase all data",
        "Factory reset",
        "Factory data reset",
        "Erase all content and settings",
        "Delete all data",
        "Wipe data",
        "Master clear",
        "Reset phone",
        "Reset device",
        "Restore factory settings",
        "Erase phone",
        "सभी डेटा मिटाएं",
        "फ़ैक्टरी रीसेट",
        "सभी सामग्री और सेटिंग्स मिटाएँ"
    )

    /** Heuristic for Settings app list pages where scroll should not trigger protection overlay. */
    private fun isLikelyAppsListScreen(): Boolean {
        return try {
            val root = rootInActiveWindow ?: return false
            val listKeys = listOf(
                "Downloaded apps",
                "Manage apps",
                "All apps",
                "Installed apps",
                "App management",
                "Apps",
                "See all apps",
                "App list",
                "Applications",
                "ऐप्स",
                "इंस्टॉल किए गए ऐप्स",
                "डाउनलोड किए गए ऐप्स",
                "सभी ऐप्स"
            )
            // Detail screen has these; list rows usually don't (scroll would otherwise false-trigger).
            val appInfoKeys = listOf(
                "App info",
                "Force stop",
                "Uninstall",
                "Clear data",
                "Clear storage"
            )
            val hasListHeader = findNodesByText(root, listKeys).isNotEmpty()
            val hasAppInfoControls = findNodesByText(root, appInfoKeys).isNotEmpty()
            // Header visible + no detail controls => still on list / filter UI (including after "screen change").
            hasListHeader && !hasAppInfoControls
        } catch (_: Exception) {
            false
        }
    }
    
    /**
     * Block when system uninstall / Play Store uninstall UI shows Fasst Pay.
     */
    private fun scanPackageInstallerOrPlayStoreUninstall() {
        try {
            val ourKeys = listOf(
                "Fasst Pay", "FasstPay", "fasst pay", "Fasst pay",
                "EMI Locker", "Emi Locker", "emilockercustomer",
                "com.rohit.emilockercustomer", "rohit.emilockercustomer"
            )
            val roots = mutableListOf<AccessibilityNodeInfo>()
            rootInActiveWindow?.let { roots.add(it) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                @Suppress("DEPRECATION")
                val wins = windows
                if (wins != null) {
                    for (w in wins) {
                        val r = w.root ?: continue
                        if (roots.none { it == r }) roots.add(r)
                    }
                }
            }
            for (root in roots) {
                val pkg = root.packageName?.toString() ?: continue
                if (!isUninstallRelatedPackage(pkg)) continue
                val ours = findNodesByText(root, ourKeys).isNotEmpty() || checkForFasstPayPackage(root)
                if (!ours) continue
                val now = System.currentTimeMillis()
                if (now - lastInstallerUninstallBlockTime < INSTALLER_UNINSTALL_DEBOUNCE_MS) return
                lastInstallerUninstallBlockTime = now
                Log.e(TAG, "🚨 Uninstall UI ($pkg) for Fasst Pay — blocking")
                blockImmediatelyAndShowOverlay(
                    "Uninstall blocked",
                    "Fasst Pay cannot be uninstalled during EMI period."
                )
                return
            }
        } catch (e: Exception) {
            Log.e(TAG, "scanPackageInstallerOrPlayStoreUninstall: ${e.message}", e)
        }
    }
    
    /**
     * Block Uninstall / OK / Yes taps when dialog is for our app (installer, Play Store, Settings).
     */
    private fun checkForUninstallConfirmationClick(event: AccessibilityEvent) {
        try {
            val clicked = (event.text?.toString() ?: "") + (event.contentDescription?.toString() ?: "")
            val strongUninstall = listOf("Uninstall", "uninstall", "REMOVE", "Remove", "Delete", "हटाए", "अनइंस्टॉल")
            val okYes = listOf("OK", "Ok", "yes", "Yes")
            val pkgEvent = event.packageName?.toString() ?: ""
            val fromInstaller = isUninstallRelatedPackage(pkgEvent)
            val fromSettingsFlow = pkgEvent.contains("settings", ignoreCase = true) ||
                pkgEvent.contains("securitycenter", ignoreCase = true)
            val fromLauncher = isLauncherPackage(pkgEvent)
            val clickedStrong = strongUninstall.any { clicked.contains(it, ignoreCase = true) } ||
                nodeOrDescendantsContainText(event.source, strongUninstall)
            val clickedOk = okYes.any { clicked.equals(it, ignoreCase = true) || clicked.contains(it) } ||
                nodeOrDescendantsContainText(event.source, okYes)
            if (!clickedStrong && !(clickedOk && (fromInstaller || fromSettingsFlow || fromLauncher))) return

            val now = System.currentTimeMillis()
            if ((clickedStrong || clickedOk) && now < uninstallGuardUntilMs) {
                if (now - lastInstallerUninstallBlockTime < INSTALLER_UNINSTALL_DEBOUNCE_MS) return
                lastInstallerUninstallBlockTime = now
                Log.e(TAG, "🚨 Uninstall flow guard active — blocking dialog click")
                blockImmediatelyAndShowOverlay(
                    "Uninstall blocked",
                    "Fasst Pay cannot be uninstalled during EMI period."
                )
                return
            }
            
            val ourKeys = listOf(
                "Fasst Pay", "FasstPay", "fasst pay", "EMI Locker", "emilockercustomer",
                "com.rohit.emilockercustomer", "rohit.emilockercustomer"
            )
            val roots = mutableListOf<AccessibilityNodeInfo>()
            rootInActiveWindow?.let { roots.add(it) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                @Suppress("DEPRECATION")
                windows?.forEach { w -> w.root?.let { r -> if (roots.none { it == r }) roots.add(r) } }
            }
            for (root in roots) {
                val pkg = root.packageName?.toString() ?: ""
                val relevant = fromInstaller || isUninstallRelatedPackage(pkg) ||
                    pkg.contains("settings", ignoreCase = true) ||
                    pkg.contains("securitycenter", ignoreCase = true) ||
                    isLauncherPackage(pkg)
                if (!relevant) continue
                if (findNodesByText(root, ourKeys).isEmpty() && !checkForFasstPayPackage(root)) continue
                val now2 = System.currentTimeMillis()
                if (now2 - lastInstallerUninstallBlockTime < INSTALLER_UNINSTALL_DEBOUNCE_MS) return
                lastInstallerUninstallBlockTime = now2
                Log.e(TAG, "🚨 Uninstall confirm click for Fasst Pay ($pkg) — blocking")
                blockImmediatelyAndShowOverlay(
                    "Uninstall blocked",
                    "Fasst Pay cannot be uninstalled during EMI period."
                )
                return
            }
        } catch (e: Exception) {
            Log.e(TAG, "checkForUninstallConfirmationClick: ${e.message}", e)
        }
    }
    
    /**
     * Settings / MIUI apps list: block tap on Fasst Pay row only.
     * Do NOT block launcher home-screen single tap (same node often has "Fasst Pay" as label — that opens the app).
     */
    private fun checkForFasstPayAppClick(event: AccessibilityEvent) {
        try {
            val packageName = event.packageName?.toString() ?: ""
            val isSettingsAppsList = packageName == "com.android.settings" ||
                packageName == "com.miui.securitycenter" ||
                packageName.contains("settings", ignoreCase = true) ||
                packageName.contains("securitycenter", ignoreCase = true)
            if (!isSettingsAppsList) return
            
            val fasstPayKeywords = listOf(
                "Fasst Pay", "FasstPay", "fasst pay", "Fasst pay",
                "EMI Locker", "Emi Locker", "emilockercustomer"
            )
            val blob = (event.text?.toString() ?: "") + " " + (event.contentDescription?.toString() ?: "")
            val fromEventText = fasstPayKeywords.any { blob.contains(it, ignoreCase = true) }
            
            val rootNode = rootInActiveWindow
            val fasstPayNodes = if (rootNode != null) findNodesByText(rootNode, fasstPayKeywords) else emptyList()
            val hasFasstPayPackage = rootNode != null && checkForFasstPayPackage(rootNode)
            if (fasstPayNodes.isEmpty() && !hasFasstPayPackage && !fromEventText) return
            
            val source = event.source
            val hierarchyHit = source != null && fasstPayNodes.any { fp ->
                isSameOrAncestor(fp, source) || isSameOrAncestor(source, fp)
            }
            // OEM rows: label on sibling — use screen bounds overlap with Fasst Pay row (Settings app list only).
            val boundsHitOnAppList = rootNode != null && isLikelyAppsListScreen() &&
                source != null && fasstPayNodes.isNotEmpty() &&
                clickBoundsOverlapAnyFasstPayNode(source, fasstPayNodes)
            val shouldBlock = fromEventText || hierarchyHit || boundsHitOnAppList
            if (shouldBlock) {
                val now = System.currentTimeMillis()
                uninstallGuardUntilMs = now + SETTINGS_APP_FLOW_GUARD_MS
                Log.e(TAG, "🚨 Fasst Pay row/tap in Settings/Apps — block + guard ${SETTINGS_APP_FLOW_GUARD_MS}ms")
                blockImmediatelyAndShowOverlay("App Access Blocked", "Fasst Pay app settings cannot be accessed during EMI period")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking Fasst Pay app click: ${e.message}", e)
        }
    }

    private fun clickBoundsOverlapAnyFasstPayNode(
        source: AccessibilityNodeInfo,
        fasstPayNodes: List<AccessibilityNodeInfo>
    ): Boolean {
        return try {
            val rs = Rect()
            source.getBoundsInScreen(rs)
            if (rs.isEmpty) return false
            for (fp in fasstPayNodes) {
                val rf = Rect()
                fp.getBoundsInScreen(rf)
                if (!rf.isEmpty && Rect.intersects(rs, rf)) return true
            }
            false
        } catch (_: Exception) {
            false
        }
    }
    
    /** Block Settings → Additional settings (MIUI/OEM); same overlay + BACK as other protection taps. */
    private fun checkForAdditionalSettingsMenuClick(event: AccessibilityEvent) {
        try {
            val packageName = event.packageName?.toString() ?: ""
            val isSettings = isSettingsPackage(packageName)
            if (!isSettings) return

            val labels = listOf(
                "Additional settings",
                "Additional setting",
                "Additional Settings",
                // Hindi (MIUI)
                "अतिरिक्त सेटिंग",
                "अतिरिक्त सेटिंग्स"
            )
            val clickedText = event.text?.toString() ?: ""
            val contentDesc = event.contentDescription?.toString() ?: ""
            val fromEvent = labels.any { label ->
                clickedText.contains(label, ignoreCase = true) ||
                    contentDesc.contains(label, ignoreCase = true)
            }
            val fromNode = nodeOrDescendantsContainText(event.source, labels)
            if (!fromEvent && !fromNode) return

            Log.e(TAG, "🚨 Additional settings clicked in System Settings — BACK + overlay!")
            blockImmediatelyAndShowOverlay(
                "Settings Blocked",
                "Additional settings cannot be accessed during EMI period"
            )
        } catch (e: Exception) {
            Log.e(TAG, "checkForAdditionalSettingsMenuClick: ${e.message}", e)
        }
    }
    
    /**
     * Block taps on factory reset / erase-all-data style entries anywhere under system Settings.
     * Phrases chosen to avoid "Reset app preferences" / network reset rows.
     */
    private fun checkForFactoryResetMenuClick(event: AccessibilityEvent) {
        try {
            val packageName = event.packageName?.toString() ?: ""
            val isSettings = isSettingsPackage(packageName)
            if (!isSettings) return

            val labels = factoryResetScreenKeywords()
            val clickedText = event.text?.toString() ?: ""
            val contentDesc = event.contentDescription?.toString() ?: ""
            val blob = "$clickedText $contentDesc"
            val fromEvent = labels.any { label ->
                blob.contains(label, ignoreCase = true)
            }
            val fromNode = nodeOrDescendantsContainText(event.source, labels)
            if (!fromEvent && !fromNode) return

            Log.e(TAG, "🚨 Factory reset / erase all data clicked in Settings — BACK + overlay!")
            blockImmediatelyAndShowOverlay(
                "Factory reset blocked",
                "Erase all data and factory reset are not allowed during EMI period"
            )
        } catch (e: Exception) {
            Log.e(TAG, "checkForFactoryResetMenuClick: ${e.message}", e)
        }
    }
    
    /** Check if node or any descendant/ancestor contains any of the keywords */
    private fun nodeOrDescendantsContainText(node: AccessibilityNodeInfo?, keywords: List<String>): Boolean {
        if (node == null) return false
        try {
            val text = node.text?.toString() ?: ""
            val contentDesc = node.contentDescription?.toString() ?: ""
            if (keywords.any { text.contains(it, true) || contentDesc.contains(it, true) }) return true
            var n: AccessibilityNodeInfo? = node.parent
            while (n != null) {
                val pt = n.text?.toString() ?: ""
                val pd = n.contentDescription?.toString() ?: ""
                if (keywords.any { pt.contains(it, true) || pd.contains(it, true) }) return true
                n = n.parent
            }
            for (i in 0 until node.childCount) {
                if (nodeOrDescendantsContainText(node.getChild(i), keywords)) return true
            }
        } catch (e: Exception) {
            Log.e(TAG, "nodeOrDescendantsContainText error: ${e.message}")
        }
        return false
    }

    /**
     * Launcher click safety: check only clicked node + ancestors (no descendants traversal).
     */
    private fun nodeOrAncestorsContainText(node: AccessibilityNodeInfo?, keywords: List<String>): Boolean {
        if (node == null) return false
        return try {
            var n: AccessibilityNodeInfo? = node
            while (n != null) {
                val text = n.text?.toString() ?: ""
                val contentDesc = n.contentDescription?.toString() ?: ""
                if (keywords.any { key -> text.contains(key, true) || contentDesc.contains(key, true) }) {
                    return true
                }
                n = n.parent
            }
            false
        } catch (e: Exception) {
            Log.e(TAG, "nodeOrAncestorsContainText error: ${e.message}")
            false
        }
    }

    /** Strict matcher for launcher taps: check only self + limited ancestors. */
    private fun nodeSelfOrNearAncestorsContainText(
        node: AccessibilityNodeInfo?,
        keywords: List<String>,
        maxDepth: Int
    ): Boolean {
        if (node == null) return false
        return try {
            var depth = 0
            var n: AccessibilityNodeInfo? = node
            while (n != null && depth <= maxDepth) {
                val text = n.text?.toString() ?: ""
                val contentDesc = n.contentDescription?.toString() ?: ""
                if (keywords.any { key -> text.contains(key, true) || contentDesc.contains(key, true) }) {
                    return true
                }
                n = n.parent
                depth++
            }
            false
        } catch (e: Exception) {
            Log.e(TAG, "nodeSelfOrNearAncestorsContainText error: ${e.message}")
            false
        }
    }
    
    /** True if a is same as b or an ancestor of b */
    private fun isSameOrAncestor(a: AccessibilityNodeInfo, b: AccessibilityNodeInfo): Boolean {
        if (a == b) return true
        var n: AccessibilityNodeInfo? = b.parent
        while (n != null) {
            if (n == a) return true
            n = n.parent
        }
        return false
    }
    
    /**
     * Check if node contains Fasst Pay package name
     */
    private fun checkForFasstPayPackage(rootNode: AccessibilityNodeInfo): Boolean {
        try {
            // Check package name in node info
            val packageName = rootNode.packageName?.toString() ?: ""
            if (packageName.contains("emilockercustomer", ignoreCase = true)) {
                return true
            }
            
            // Recursively check child nodes
            for (i in 0 until rootNode.childCount) {
                val child = rootNode.getChild(i)
                if (child != null) {
                    val childPackage = child.packageName?.toString() ?: ""
                    if (childPackage.contains("emilockercustomer", ignoreCase = true)) {
                        return true
                    }
                    // Recursively check deeper
                    if (checkForFasstPayPackage(child)) {
                        return true
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking package name: ${e.message}", e)
        }
        return false
    }
    
    /**
     * Check if user clicked on app control options (App info, Pause app, etc.)
     * Works for long-press menu from launcher or system UI.
     */
    private fun checkForAppControlClick(event: AccessibilityEvent) {
        try {
            val clickedText = event.text?.toString() ?: ""
            val contentDesc = event.contentDescription?.toString() ?: ""
            val pkgEvent = event.packageName?.toString() ?: ""
            
            val appControlKeywords = listOf(
                "App info", "App Info", "Application info", "Application Info",
                "Pause app", "Pause App", "Uninstall", "Remove", "Delete",
                "Clear data", "Clear Data", "Clear storage", "Clear Storage",
                "Force stop", "Force Stop", "Disable", "Storage", "Data usage"
            )
            
            // Event text/contentDesc OR clicked node (source) has App info / Pause app
            val isAppControlClick = appControlKeywords.any { keyword ->
                clickedText.contains(keyword, ignoreCase = true) ||
                contentDesc.contains(keyword, ignoreCase = true)
            } || nodeOrDescendantsContainText(event.source, appControlKeywords)
            
            if (isAppControlClick) {
                Log.e(TAG, "🚨 CRITICAL: User clicked on app control option (App info / Uninstall)!")
                
                // Check active window first
                val rootNode = rootInActiveWindow
                var shouldBlock = false
                val sourceTargetsOurApp = nodeSelfOrNearAncestorsContainText(event.source, listOf(
                    "Fasst Pay", "FasstPay", "fasst pay", "Fasst pay",
                    "EMI Locker", "Emi Locker", "emilockercustomer",
                    "com.rohit.emilockercustomer", "rohit.emilockercustomer"
                ), maxDepth = 2)
                if (sourceTargetsOurApp) {
                    shouldBlock = true
                }
                if (rootNode != null) {
                    val fasstPayNodes = findNodesByText(rootNode, listOf(
                        "Fasst Pay", "FasstPay", "fasst pay", "Fasst pay",
                        "EMI Locker", "Emi Locker", "emilockercustomer"
                    ))
                    val hasFasstPayPackage = checkForFasstPayPackage(rootNode)
                    // Launcher shows many app labels; don't infer target app from full-window presence there.
                    val shouldUseWindowSignals = !isLauncherPackage(pkgEvent)
                    if (!shouldBlock && shouldUseWindowSignals) {
                        shouldBlock = fasstPayNodes.isNotEmpty() || hasFasstPayPackage
                    }
                }
                // When user long-presses app icon, popup (App info/Uninstall) may be focused -
                // Fasst Pay text stays in launcher window behind. Check ALL windows.
                if (!shouldBlock &&
                    !isLauncherPackage(pkgEvent) &&
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    @Suppress("DEPRECATION")
                    val windows = windows
                    if (windows != null) {
                        for (win in windows) {
                            val winRoot = win.root ?: continue
                            if (findNodesByText(winRoot, listOf(
                                "Fasst Pay", "FasstPay", "fasst pay", "Fasst pay",
                                "EMI Locker", "Emi Locker", "emilockercustomer"
                            )).isNotEmpty() || checkForFasstPayPackage(winRoot)) {
                                shouldBlock = true
                                Log.e(TAG, "🚨 Fasst Pay found in another window (launcher) - blocking App info/Uninstall")
                                break
                            }
                        }
                    }
                }
                // Also block if user recently had Fasst Pay on screen (e.g. long-pressed icon then tapped App info)
                if (!shouldBlock &&
                    !isLauncherPackage(pkgEvent) &&
                    System.currentTimeMillis() - lastSeenFasstPayTime < FASST_PAY_RECENT_MS) {
                    shouldBlock = true
                    Log.e(TAG, "🚨 App info/Uninstall clicked shortly after Fasst Pay was visible - blocking")
                }
                val uninstallKeywords = listOf("Uninstall", "Remove", "Delete", "अनइंस्टॉल", "हटाए")
                val uninstallTapped = uninstallKeywords.any { key ->
                    clickedText.contains(key, ignoreCase = true) ||
                        contentDesc.contains(key, ignoreCase = true)
                } || nodeOrDescendantsContainText(event.source, uninstallKeywords)
                if (uninstallTapped && shouldBlock && isLauncherPackage(pkgEvent)) {
                    uninstallGuardUntilMs = System.currentTimeMillis() + LAUNCHER_UNINSTALL_GUARD_MS
                    Log.e(TAG, "🚨 Armed launcher uninstall guard for ${LAUNCHER_UNINSTALL_GUARD_MS}ms")
                }
                if (shouldBlock) {
                    Log.e(TAG, "🚨 BLOCKING: App info/Uninstall clicked - BACK + overlay immediately!")
                    blockImmediatelyAndShowOverlay("App Control Blocked", "Fasst Pay app cannot be modified or uninstalled during EMI period")
                } else {
                    Log.d(TAG, "App control clicked but not for Fasst Pay - skip overlay")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking app control click: ${e.message}", e)
        }
    }
    
    /** Update lastSeenFasstPayTime when our app name is visible in any window (so next App info/Uninstall tap can be blocked). */
    private fun updateLastSeenFasstPayIfVisible() {
        try {
            val keywords = listOf("Fasst Pay", "FasstPay", "fasst pay", "Fasst pay", "EMI Locker", "Emi Locker", "emilockercustomer")
            var seen = false
            val root = rootInActiveWindow
            if (root != null) {
                if (findNodesByText(root, keywords).isNotEmpty() || checkForFasstPayPackage(root)) seen = true
            }
            if (!seen && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                @Suppress("DEPRECATION")
                val wins = windows ?: return
                for (w in wins) {
                    val r = w.root ?: continue
                    if (findNodesByText(r, keywords).isNotEmpty() || checkForFasstPayPackage(r)) {
                        seen = true
                        break
                    }
                }
            }
            if (seen) lastSeenFasstPayTime = System.currentTimeMillis()
        } catch (e: Exception) {
            Log.d(TAG, "updateLastSeenFasstPayIfVisible: ${e.message}")
        }
    }
    
    /**
     * Per-app details screen only: must show uninstall/force-stop style actions (not Settings home tiles like Battery).
     * Block only for Fasst Pay / our package, or right after user tapped Fasst Pay row (guard).
     */
    private fun checkForAppInfoScreen(event: AccessibilityEvent) {
        try {
            val rootNode = rootInActiveWindow ?: return
            if (isLikelyAppsListScreen()) return

            val strongAppDetailMarkers = listOf(
                "Force stop", "Force Stop", "Uninstall", "Clear data", "Clear storage",
                "Disable",
                "अनइंस्टॉल", "बलपूर्वक रोकें", "डेटा साफ़ करें",
            )
            if (findNodesByText(rootNode, strongAppDetailMarkers).isEmpty()) return

            val fasstPayNodes = findNodesByText(rootNode, listOf(
                "Fasst Pay", "FasstPay", "fasst pay", "Fasst pay",
                "EMI Locker", "Emi Locker", "emilockercustomer"
            ))
            val hasFasstPayPackage = checkForFasstPayPackage(rootNode)

            // Do not use uninstallGuard here — guard stays hot after a tap and would block other apps' info screens.
            if (fasstPayNodes.isNotEmpty() || hasFasstPayPackage) {
                uninstallGuardUntilMs = System.currentTimeMillis() + SETTINGS_APP_FLOW_GUARD_MS
                Log.e(TAG, "🚨 Fasst Pay app info screen - BACK + overlay immediately!")
                blockImmediatelyAndShowOverlay("App Settings Blocked", "Fasst Pay settings cannot be modified during EMI period")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error checking app info screen: ${e.message}", e)
        }
    }
    
    /**
     * Find nodes containing specific text
     */
    private fun findNodesByText(rootNode: AccessibilityNodeInfo, textList: List<String>): List<AccessibilityNodeInfo> {
        val foundNodes = mutableListOf<AccessibilityNodeInfo>()
        
        try {
            if (textList.isEmpty()) return foundNodes
            val keys = textList.map { it.lowercase() }
            val stack = ArrayDeque<AccessibilityNodeInfo>()
            stack.add(rootNode)
            while (stack.isNotEmpty()) {
                val node = stack.removeLast()
                val t = node.text?.toString()?.lowercase().orEmpty()
                val d = node.contentDescription?.toString()?.lowercase().orEmpty()
                if (keys.any { k -> k.isNotBlank() && (t.contains(k) || d.contains(k)) }) {
                    foundNodes.add(node)
                }
                for (i in 0 until node.childCount) {
                    node.getChild(i)?.let { stack.add(it) }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error finding nodes by text: ${e.message}", e)
        }
        
        return foundNodes
    }
    
    /**
     * Block immediately: BACK first (so App Info screen / menu doesn't open or closes),
     * then show overlay. Use this for click-triggered blocks so screen on hi na ho.
     */
    private fun blockImmediatelyAndShowOverlay(title: String, message: String) {
        if (overlayView != null) return
        val fg = rootInActiveWindow?.packageName?.toString()
        if (fg == packageName) return
        if (isUninstallAllowedByServerFlag()) {
            Log.d(TAG, "Skip block+overlay — canUserUninstallFlag=true from server")
            return
        }
        Log.e(TAG, "🚨 blockImmediatelyAndShowOverlay: BACK burst + overlay ASAP (no queue tail delay)")
        val h = android.os.Handler(android.os.Looper.getMainLooper())
        repeat(5) { performGlobalAction(GLOBAL_ACTION_BACK) }
        h.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 30)
        h.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 90)
        lastOverlayTime = System.currentTimeMillis()
        lastOverlayTimeForClick = System.currentTimeMillis()
        showProtectionOverlayImmediate(title, message)
    }
    
    /** Send BACK burst to close underlying risky UI before/while showing overlay. */
    private fun performBackBurstForProtection() {
        val fg = rootInActiveWindow?.packageName?.toString()
        if (fg == packageName) return
        val h = android.os.Handler(android.os.Looper.getMainLooper())
        performGlobalAction(GLOBAL_ACTION_BACK)
        h.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 40)
        h.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 110)
    }
    
    /**
     * Show protection overlay with cooldown (for content-changed / window-changed triggers only).
     */
    private fun showProtectionOverlayWithCooldown(title: String, message: String) {
        if (overlayView != null) return
        if (isUninstallAllowedByServerFlag()) return
        val now = System.currentTimeMillis()
        if (now - lastOverlayTime < OVERLAY_COOLDOWN_MS) return
        lastOverlayTime = now
        performGlobalAction(GLOBAL_ACTION_BACK)
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            performGlobalAction(GLOBAL_ACTION_BACK)
        }, 60)
        showProtectionOverlay(title, message)
    }
    
    /**
     * Same as [showProtectionOverlay] but runs at front of main queue so UI is not blocked behind
     * other posted work (reduces 1–3s gap where App info stays tappable).
     */
    private fun showProtectionOverlayImmediate(title: String, message: String) {
        fun applyOverlay() {
            try {
                if (isUninstallAllowedByServerFlag()) return
                if (System.currentTimeMillis() < protectionGraceUntilMs) return
                val fg = rootInActiveWindow?.packageName?.toString()
                if (fg == packageName) return
                if (overlayView != null) return
                Log.e(TAG, "========== SHOWING PROTECTION OVERLAY (immediate) ==========")
                performBackBurstForProtection()
                hideDirectOverlay(alsoSendGlobalBack = false)
                createDirectOverlay(title, message)
            } catch (e: Exception) {
                Log.e(TAG, "showProtectionOverlayImmediate: ${e.message}", e)
            }
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            applyOverlay()
        } else {
            android.os.Handler(android.os.Looper.getMainLooper()).postAtFrontOfQueue { applyOverlay() }
        }
    }
    
    /**
     * Show protection overlay when user tries to control app.
     * Always run on main thread so overlay is added correctly.
     */
    private fun showProtectionOverlay(title: String, message: String, force: Boolean = false) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            try {
                if (isUninstallAllowedByServerFlag()) {
                    Log.d(TAG, "Skip protection overlay — canUserUninstallFlag=true")
                    return@post
                }
                if (!force && System.currentTimeMillis() < protectionGraceUntilMs) {
                    Log.d(TAG, "Skip show overlay — grace period")
                    return@post
                }
                if (!force) {
                    val fg = rootInActiveWindow?.packageName?.toString()
                    if (fg == packageName) {
                        Log.d(TAG, "Skip protection overlay — Fasst Pay is foreground (avoid closing app)")
                        return@post
                    }
                }
                Log.e(TAG, "========== SHOWING DIRECT PROTECTION OVERLAY ==========")
                Log.e(TAG, "Title: $title")
                Log.e(TAG, "Message: $message")

                performBackBurstForProtection()
                hideDirectOverlay(alsoSendGlobalBack = false)
                createDirectOverlay(title, message)
                Log.e(TAG, "✅ Direct protection overlay created successfully")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error showing direct protection overlay: ${e.message}", e)
            }
        }
    }
    
    /**
     * Create direct overlay in accessibility service
     */
    private fun createDirectOverlay(title: String, message: String) {
        try {
            if (isUninstallAllowedByServerFlag()) return
            // Create overlay view
            overlayView = createProtectionOverlayView(title, message)
            
            // Set up layout parameters
            overlayParams = WindowManager.LayoutParams().apply {
                width = WindowManager.LayoutParams.MATCH_PARENT
                height = WindowManager.LayoutParams.MATCH_PARENT
                type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }
                flags = WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                format = PixelFormat.TRANSLUCENT
                gravity = Gravity.CENTER
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            }
            
            windowManager?.addView(overlayView, overlayParams)
            Log.e(TAG, "✅ Direct overlay view added to WindowManager")
            
            dismissTimer = android.os.Handler(android.os.Looper.getMainLooper())
            dismissTimer?.postDelayed({
                Log.e(TAG, "⏰ Auto-dismiss — removing overlay now")
                hideDirectOverlay(alsoSendGlobalBack = true)
            }, 8000) // Keep visible longer so user can't instantly bypass protection
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error creating direct overlay: ${e.message}", e)
        }
    }
    
    /**
     * Create protection overlay view
     */
    private fun createProtectionOverlayView(title: String, message: String): View {
        // Create main container with proper key handling
        val container = object : LinearLayout(this@AppUsageMonitorService) {
            override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
                Log.d(TAG, "🔑 Key event: ${event?.keyCode}, action: ${event?.action}")
                
                if (event?.keyCode == KeyEvent.KEYCODE_BACK) {
                    if (event.action == KeyEvent.ACTION_DOWN) {
                        Log.e(TAG, "🔙 BACK BUTTON DOWN - Preparing to hide overlay")
                        return true
                    } else if (event.action == KeyEvent.ACTION_UP) {
                        Log.e(TAG, "🔙 BACK BUTTON UP - Hiding direct overlay NOW")
                        hideDirectOverlay(alsoSendGlobalBack = true)
                        return true
                    }
                }
                return super.dispatchKeyEvent(event)
            }
            
            override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
                Log.d(TAG, "🔑 onKeyDown: $keyCode")
                if (keyCode == KeyEvent.KEYCODE_BACK) {
                    Log.e(TAG, "🔙 BACK KEY DOWN detected")
                    return true
                }
                return super.onKeyDown(keyCode, event)
            }
            
            override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
                Log.d(TAG, "🔑 onKeyUp: $keyCode")
                if (keyCode == KeyEvent.KEYCODE_BACK) {
                    Log.e(TAG, "🔙 BACK KEY UP - Hiding overlay")
                    hideDirectOverlay(alsoSendGlobalBack = true)
                    return true
                }
                return super.onKeyUp(keyCode, event)
            }
            
            override fun onTouchEvent(event: MotionEvent?): Boolean {
                // Allow touches but don't let them pass through
                return true
            }
        }.apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#F2000000")) // Near-opaque so App Info screen not visible behind
            gravity = Gravity.CENTER
            setPadding(40, 40, 40, 40)
            isFocusable = true
            isFocusableInTouchMode = true
            isClickable = true
            
            // CRITICAL: Request focus to receive key events
            post {
                requestFocus()
                Log.e(TAG, "🎯 Focus requested for overlay container")
            }
        }
        
        // Create card container
        val cardContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.WHITE)
            setPadding(60, 60, 60, 60)
            gravity = Gravity.CENTER
        }
        
        // Shield icon
        val iconText = TextView(this).apply {
            text = "🛡️"
            textSize = 48f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 20)
        }
        cardContainer.addView(iconText)
        
        // Title
        val titleView = TextView(this).apply {
            text = title
            textSize = 24f
            setTextColor(Color.parseColor("#1976D2")) // Blue color
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 20)
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        cardContainer.addView(titleView)
        
        // Message
        val messageView = TextView(this).apply {
            text = "$message\n\nThis app is protected during your EMI period."
            textSize = 16f
            setTextColor(Color.BLACK)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 30)
        }
        cardContainer.addView(messageView)
        
        // Instruction
        val instructionView = TextView(this).apply {
            text = "Action blocked. Please wait..."
            textSize = 14f
            setTextColor(Color.parseColor("#666666"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 20)
            setTypeface(null, android.graphics.Typeface.ITALIC)
        }
        cardContainer.addView(instructionView)
        
        container.addView(cardContainer)
        return container
    }
    
    /**
     * Overlay turant WindowManager se hatao (Dismiss / Back / auto-dismiss).
     * @param alsoSendGlobalBack true = hatne ke baad 2x BACK taaki App Info / menu band rahe
     * @param alsoSendGlobalBack false = sirf view hatao (naya overlay dikhane ya service destroy par)
     */
    private fun hideDirectOverlay(alsoSendGlobalBack: Boolean = true) {
        try {
            dismissTimer?.removeCallbacksAndMessages(null)
            dismissTimer = null
            
            try {
                overlayView?.let { view ->
                    windowManager?.removeView(view)
                    Log.e(TAG, "✅ Overlay turant remove ho gaya")
                }
            } catch (e: Exception) {
                Log.e(TAG, "removeView: ${e.message}")
            }
            overlayView = null
            overlayParams = null
            
            // Never send global BACK when our Flutter app is foreground — it pops routes / exits app.
            if (alsoSendGlobalBack) {
                val fg = rootInActiveWindow?.packageName?.toString()
                if (fg == packageName) {
                    Log.d(TAG, "Skip global BACK — Fasst Pay (Flutter) is foreground")
                } else {
                    val h = android.os.Handler(android.os.Looper.getMainLooper())
                    h.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 50)
                    h.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 120)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error hiding direct overlay: ${e.message}", e)
            overlayView = null
            overlayParams = null
        }
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "⚠️ App Usage Monitor Service interrupted")
        // Do not mark disabled on interrupt; OEMs (especially MIUI) can interrupt transiently
        // while the service is still enabled in system settings.
        isServiceEnabled = true
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "❌ App Usage Monitor Service destroyed")
        isServiceEnabled = false
        try {
            testOverlayReceiver?.let { unregisterReceiver(it) }
        } catch (e: Exception) {
            Log.d(TAG, "unregisterReceiver: ${e.message}")
        }
        testOverlayReceiver = null
        hideDirectOverlay(alsoSendGlobalBack = false)
    }
    
    override fun onUnbind(intent: Intent?): Boolean {
        Log.d(TAG, "❌ App Usage Monitor Service unbound")
        // Keep previous state here; real disable is handled by onDestroy/onServiceConnected.
        // Some OEMs can transiently unbind/rebind and this should not instantly flip app UI to "not working".
        return super.onUnbind(intent)
    }
}