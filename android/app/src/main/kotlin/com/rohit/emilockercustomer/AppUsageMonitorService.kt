package com.rohit.emilockercustomer

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
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
    private val FASST_PAY_RECENT_MS = 4000L
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.e(TAG, "========== ✅ APP USAGE MONITOR SERVICE CONNECTED ==========")
        Log.e(TAG, "✅ Service is now active and monitoring events")
        isServiceEnabled = true
        
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
                    showProtectionOverlay("Protection test", "If you see this, the protection overlay is working.")
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
            
            // Log every event for debugging (can be removed later)
            Log.d(TAG, "📱 Event: ${event.packageName} | Type: ${getEventTypeName(event.eventType)}")
            
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
            
            // Log ALL events for debugging
            Log.d(TAG, "=== ACCESSIBILITY EVENT ===")
            Log.d(TAG, "Package: $packageName")
            Log.d(TAG, "Class: $className") 
            Log.d(TAG, "Type: $eventType (${getEventTypeName(eventType)})")
            Log.d(TAG, "Text: $text")
            Log.d(TAG, "========================")
            
            // CRITICAL: Check for CLICK and SELECTED - both can indicate user tapped Fasst Pay / App info / Pause
            // SELECTED is used by some launchers/Settings for list items
            val isClickOrSelect = (eventType == AccessibilityEvent.TYPE_VIEW_CLICKED || eventType == AccessibilityEvent.TYPE_VIEW_SELECTED)
            if (isClickOrSelect) {
                Log.e(TAG, "🖱️ CLICK/SELECT EVENT DETECTED - checking what was clicked")
                
                // FIRST: Check if user clicked on Fasst Pay app itself in Settings > Apps
                checkForFasstPayAppClick(event)
                
                // SECOND: Check for app control options (App info, Pause app)
                checkForAppControlClick(event)
                
                if (packageName == "com.android.settings" || packageName?.contains("settings") == true) {
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        checkForAppInfoScreen(event)
                    }, 150)
                }
            }
            
            if (isClickOrSelect) {
                checkForAppControlClick(event)
                checkForAppControlOptions(event)
            }
            
            updateLastSeenFasstPayIfVisible()
            
            if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
                (packageName == "com.android.settings" || packageName == "com.miui.securitycenter" || packageName?.contains("settings") == true)) {
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    checkForAppInfoScreen(event)
                }, 200)
            }
            
            // Only check Settings screen on content change (e.g. navigated to app info). Do NOT run
            // checkForAppControlOptions here - that runs on CLICK only, else overlay shows without user tap.
            if (eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
                if (packageName == "com.android.settings" || packageName?.contains("settings") == true) {
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        checkForAppInfoScreen(event)
                    }, 150)
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error handling accessibility event: ${e.message}", e)
        }
    }
    
    /**
     * Get human-readable event type name for debugging
     */
    private fun getEventTypeName(eventType: Int): String {
        return when (eventType) {
            AccessibilityEvent.TYPE_VIEW_CLICKED -> "CLICKED"
            AccessibilityEvent.TYPE_VIEW_SELECTED -> "SELECTED"
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> "WINDOW_CHANGED"
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> "TEXT_CHANGED"
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> "CONTENT_CHANGED"
            else -> "OTHER($eventType)"
        }
    }
    
    /**
     * Check if user clicked on Fasst Pay app itself in Settings > Apps list (or App info screen)
     * This detects the click when user taps App info/Pause, or goes to Apps and taps Fasst Pay.
     */
    private fun checkForFasstPayAppClick(event: AccessibilityEvent) {
        try {
            val clickedText = event.text?.toString() ?: ""
            val contentDesc = event.contentDescription?.toString() ?: ""
            val packageName = event.packageName?.toString() ?: ""
            
            Log.e(TAG, "🔍 Checking for Fasst Pay app click...")
            Log.e(TAG, "🖱️ Clicked text: '$clickedText'")
            Log.e(TAG, "🖱️ Content desc: '$contentDesc'")
            Log.e(TAG, "🖱️ Package: '$packageName'")
            
            val fasstPayKeywords = listOf(
                "Fasst Pay", "FasstPay", "fasst pay", "Fasst pay",
                "EMI Locker", "Emi Locker", "emilockercustomer"
            )
            
            // 1) Event text/contentDesc has Fasst Pay
            val isFasstPayClick = fasstPayKeywords.any { keyword ->
                clickedText.contains(keyword, ignoreCase = true) ||
                contentDesc.contains(keyword, ignoreCase = true)
            }
            
            // 2) Clicked node (source) or its parents/children contain Fasst Pay (e.g. list row in Apps)
            val sourceHasFasstPay = nodeOrDescendantsContainText(event.source, fasstPayKeywords)
            
            if (isFasstPayClick || sourceHasFasstPay) {
                Log.e(TAG, "🚨 CRITICAL: Fasst Pay clicked - BACK + overlay immediately!")
                blockImmediatelyAndShowOverlay("App Access Blocked", "Fasst Pay app settings cannot be accessed during EMI period")
                return
            }
            
            // 3) In Settings > Apps: root has Fasst Pay and clicked node is the Fasst Pay row
            if (packageName == "com.android.settings") {
                val rootNode = rootInActiveWindow ?: return
                val fasstPayNodes = findNodesByText(rootNode, listOf(
                    "Fasst Pay", "FasstPay", "fasst pay", "Fasst pay",
                    "EMI Locker", "Emi Locker", "emilockercustomer"
                ))
                val hasFasstPayPackage = checkForFasstPayPackage(rootNode)
                if (fasstPayNodes.isNotEmpty() || hasFasstPayPackage) {
                    val source = event.source
                    val clickedFasstPayRow = source != null && fasstPayNodes.any { fp ->
                        isSameOrAncestor(fp, source) || isSameOrAncestor(source, fp)
                    }
                    if (clickedFasstPayRow) {
                        Log.e(TAG, "🚨 Fasst Pay row clicked in Settings - BACK + overlay immediately!")
                        blockImmediatelyAndShowOverlay("App Access Blocked", "Fasst Pay app settings cannot be accessed during EMI period")
                    }
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking Fasst Pay app click: ${e.message}", e)
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
                if (rootNode != null) {
                    val fasstPayNodes = findNodesByText(rootNode, listOf(
                        "Fasst Pay", "FasstPay", "fasst pay", "Fasst pay",
                        "EMI Locker", "Emi Locker", "emilockercustomer"
                    ))
                    val hasFasstPayPackage = checkForFasstPayPackage(rootNode)
                    shouldBlock = fasstPayNodes.isNotEmpty() || hasFasstPayPackage
                }
                // When user long-presses app icon, popup (App info/Uninstall) may be focused -
                // Fasst Pay text stays in launcher window behind. Check ALL windows.
                if (!shouldBlock && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
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
                if (!shouldBlock && System.currentTimeMillis() - lastSeenFasstPayTime < FASST_PAY_RECENT_MS) {
                    shouldBlock = true
                    Log.e(TAG, "🚨 App info/Uninstall clicked shortly after Fasst Pay was visible - blocking")
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
    
    // REMOVED: Continuous monitoring - was causing false positives
    // Now we only check on actual click events, not continuously scanning
    
    // REMOVED: checkForFasstPayInLauncher - Not needed anymore
    // We now detect actual clicks on app control options instead of just context menu presence
    
    /**
     * Check for "App info" or "Pause app" options in popup menus
     */
    private fun checkForAppControlOptions(event: AccessibilityEvent) {
        try {
            val rootNode = rootInActiveWindow ?: return
            
            Log.d(TAG, "Checking for app control options in system UI...")
            
            // Look for text containing "App info" or "Pause app" - more comprehensive search
            // Include all variations of uninstall, clear data, etc.
            val appControlTexts = listOf(
                "App info", "App Info", "Application info", "Application Info",
                "Pause app", "Pause App", "Disable app", "Disable App",
                "Force stop", "Force Stop", "Uninstall", "Remove", "Delete",
                "Clear data", "Clear Data", "Clear storage", "Clear Storage",
                "Storage", "Data usage", "Data Usage", "Permissions",
                "Battery", "Notifications", "App details", "App Details"
            )
            
            val appInfoNodes = findNodesByText(rootNode, appControlTexts)
            
            if (appInfoNodes.isNotEmpty()) {
                Log.e(TAG, "🚨 DETECTED: App control options (App info / Uninstall) found!")
                Log.e(TAG, "Found ${appInfoNodes.size} app control nodes")
                
                var fasstPayVisible = false
                val fasstPayKeywords = listOf(
                    "Fasst Pay", "FasstPay", "fasst pay", "Fasst pay",
                    "EMI Locker", "Emi Locker", "emilockercustomer"
                )
                // Current window
                val fasstPayNodes = findNodesByText(rootNode, fasstPayKeywords)
                val hasFasstPayPackage = checkForFasstPayPackage(rootNode)
                fasstPayVisible = fasstPayNodes.isNotEmpty() || hasFasstPayPackage
                // Long-press menu may be in focus; Fasst Pay can be in launcher window behind
                if (!fasstPayVisible && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    @Suppress("DEPRECATION")
                    val windows = windows
                    if (windows != null) {
                        for (win in windows) {
                            val winRoot = win.root ?: continue
                            if (findNodesByText(winRoot, fasstPayKeywords).isNotEmpty() || checkForFasstPayPackage(winRoot)) {
                                fasstPayVisible = true
                                Log.e(TAG, "🚨 Fasst Pay in another window - blocking menu")
                                break
                            }
                        }
                    }
                }
                if (fasstPayVisible) {
                    Log.e(TAG, "🚨 App control menu for Fasst Pay - BACK + overlay immediately!")
                    blockImmediatelyAndShowOverlay("App Control Blocked", "Fasst Pay app cannot be modified or uninstalled during EMI period")
                } else {
                    Log.d(TAG, "✅ App control options detected but not for Fasst Pay")
                }
            } else {
                Log.d(TAG, "No app control options detected in current screen")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error checking app control options: ${e.message}", e)
        }
    }
    
    /**
     * Check for app info screen in settings
     */
    private fun checkForAppInfoScreen(event: AccessibilityEvent) {
        try {
            val rootNode = rootInActiveWindow ?: return
            
            // Look for Fasst Pay in app info screen with more keywords
            val fasstPayNodes = findNodesByText(rootNode, listOf(
                "Fasst Pay", "FasstPay", "fasst pay", "Fasst pay",
                "EMI Locker", "Emi Locker", "emilockercustomer"
            ))
            
            // Also check for package name
            val hasFasstPayPackage = checkForFasstPayPackage(rootNode)
            
            if (fasstPayNodes.isNotEmpty() || hasFasstPayPackage) {
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
            for (text in textList) {
                // Use findAccessibilityNodeInfosByText for exact matches
                val nodes = rootNode.findAccessibilityNodeInfosByText(text)
                foundNodes.addAll(nodes)
                
                // Also search recursively for partial matches
                findNodesByTextRecursive(rootNode, text, foundNodes)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error finding nodes by text: ${e.message}", e)
        }
        
        return foundNodes
    }
    
    /**
     * Recursively find nodes containing text (for partial matches)
     */
    private fun findNodesByTextRecursive(node: AccessibilityNodeInfo, searchText: String, foundNodes: MutableList<AccessibilityNodeInfo>) {
        try {
            val nodeText = node.text?.toString() ?: ""
            val nodeContentDesc = node.contentDescription?.toString() ?: ""
            
            // Check if this node contains the search text
            if (nodeText.contains(searchText, ignoreCase = true) || 
                nodeContentDesc.contains(searchText, ignoreCase = true)) {
                foundNodes.add(node)
            }
            
            // Recursively check children
            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    findNodesByTextRecursive(child, searchText, foundNodes)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in recursive text search: ${e.message}", e)
        }
    }
    
    /**
     * Block immediately: BACK first (so App Info screen / menu doesn't open or closes),
     * then show overlay. Use this for click-triggered blocks so screen on hi na ho.
     */
    private fun blockImmediatelyAndShowOverlay(title: String, message: String) {
        if (overlayView != null) return
        Log.e(TAG, "🚨 blockImmediatelyAndShowOverlay: BACK first so screen never opens")
        val h = android.os.Handler(android.os.Looper.getMainLooper())
        performGlobalAction(GLOBAL_ACTION_BACK)
        h.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 50)
        h.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 110)
        h.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 170)
        lastOverlayTime = System.currentTimeMillis()
        lastOverlayTimeForClick = System.currentTimeMillis()
        showProtectionOverlay(title, message)
    }
    
    /**
     * Show protection overlay with cooldown (for content-changed / window-changed triggers only).
     */
    private fun showProtectionOverlayWithCooldown(title: String, message: String) {
        if (overlayView != null) return
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
     * Show protection overlay when user tries to control app.
     * Always run on main thread so overlay is added correctly.
     */
    private fun showProtectionOverlay(title: String, message: String) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            try {
                Log.e(TAG, "========== SHOWING DIRECT PROTECTION OVERLAY ==========")
                Log.e(TAG, "Title: $title")
                Log.e(TAG, "Message: $message")
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    if (!android.provider.Settings.canDrawOverlays(this@AppUsageMonitorService)) {
                        Log.e(TAG, "❌ CRITICAL: No overlay permission! Enable \"Display over other apps\" for Fasst Pay.")
                        try {
                            android.widget.Toast.makeText(this@AppUsageMonitorService, "Fasst Pay: Enable overlay permission", android.widget.Toast.LENGTH_LONG).show()
                        } catch (e: Exception) {
                            Log.e(TAG, "Toast failed: ${e.message}")
                        }
                        return@post
                    }
                }
                
                hideDirectOverlay()
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
            // Create overlay view
            overlayView = createProtectionOverlayView(title, message)
            
            // Set up layout parameters
            overlayParams = WindowManager.LayoutParams().apply {
                width = WindowManager.LayoutParams.MATCH_PARENT
                height = WindowManager.LayoutParams.MATCH_PARENT
                type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }
                flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
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
            
            // Extra BACK 150ms after overlay shown so any App Info screen that started opening is closed
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                performGlobalAction(GLOBAL_ACTION_BACK)
                performGlobalAction(GLOBAL_ACTION_BACK)
            }, 150)
            
            dismissTimer = android.os.Handler(android.os.Looper.getMainLooper())
            dismissTimer?.postDelayed({
                Log.e(TAG, "⏰ Auto-dismiss timer triggered - hiding overlay")
                hideDirectOverlay()
            }, 5000) // 5 seconds
            
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
                        hideDirectOverlay()
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
                    hideDirectOverlay()
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
        
        // Back button instruction
        val instructionView = TextView(this).apply {
            text = "Press back button to dismiss"
            textSize = 14f
            setTextColor(Color.parseColor("#666666"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 20)
            setTypeface(null, android.graphics.Typeface.ITALIC)
        }
        cardContainer.addView(instructionView)
        
        // Dismiss button
        val dismissButton = Button(this).apply {
            text = "Dismiss"
            textSize = 16f
            setBackgroundColor(Color.parseColor("#1976D2"))
            setTextColor(Color.WHITE)
            setPadding(40, 20, 40, 20)
            
            setOnClickListener {
                Log.e(TAG, "🔙 DISMISS BUTTON CLICKED - Hiding direct overlay")
                post {
                    hideDirectOverlay()
                }
            }
        }
        cardContainer.addView(dismissButton)
        
        // Add click listener to background to dismiss
        container.setOnClickListener {
            Log.e(TAG, "🔙 BACKGROUND CLICKED - Hiding direct overlay")
            hideDirectOverlay()
        }
        
        container.addView(cardContainer)
        return container
    }
    
    /**
     * Hide direct overlay. FIRST send multiple BACKs (while overlay still visible) so App Info
     * / Uninstall screen is closed, THEN remove overlay. This way user never sees that screen.
     */
    private fun hideDirectOverlay() {
        try {
            dismissTimer?.removeCallbacksAndMessages(null)
            dismissTimer = null
            
            val handler = android.os.Handler(android.os.Looper.getMainLooper())
            val backDelayMs = 90L
            val backCount = 5
            
            fun doBackThenRemove(remaining: Int) {
                if (remaining <= 0) {
                    try {
                        overlayView?.let { view ->
                            windowManager?.removeView(view)
                            Log.e(TAG, "✅ Overlay removed after BACKs - app control screen closed")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error removing overlay: ${e.message}")
                    }
                    overlayView = null
                    overlayParams = null
                    return
                }
                performGlobalAction(GLOBAL_ACTION_BACK)
                Log.e(TAG, "🔙 BACK to close app control (${backCount - remaining + 1}/$backCount)")
                handler.postDelayed({ doBackThenRemove(remaining - 1) }, backDelayMs)
            }
            
            doBackThenRemove(backCount)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error hiding direct overlay: ${e.message}", e)
            overlayView = null
            overlayParams = null
        }
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "⚠️ App Usage Monitor Service interrupted")
        isServiceEnabled = false
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
        hideDirectOverlay()
    }
    
    override fun onUnbind(intent: Intent?): Boolean {
        Log.d(TAG, "❌ App Usage Monitor Service unbound")
        isServiceEnabled = false
        return super.onUnbind(intent)
    }
}