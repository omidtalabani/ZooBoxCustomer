package com.zoobox.customer

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import android.webkit.CookieManager
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.work.*
import okhttp3.*
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

class CookieSenderService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()
    private val serverBaseUrl = "https://mikmik.site/notification_checker.php"
    private val sendInterval = 15000L // 15 seconds

    // Enhanced wake lock management
    private var partialWakeLock: PowerManager.WakeLock? = null
    private var screenWakeLock: PowerManager.WakeLock? = null

    // Keep track of the last notification time to avoid spamming
    private var lastNotificationTime = 0L

    // Service restart counter for exponential backoff
    private var restartCount = 0

    // Multiple restart handlers for redundancy
    private val restartHandler1 = Handler(Looper.getMainLooper())
    private val restartHandler2 = Handler(Looper.getMainLooper())
    private val restartHandler3 = Handler(Looper.getMainLooper())

    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "order_check_service"
        private const val ORDER_CHANNEL_ID = "customer_notifications"
        private const val RESTART_SERVICE_ALARM_ID = 12345
        private const val BACKUP_ALARM_ID = 12346
        private const val IMMEDIATE_RESTART_ALARM_ID = 12347
        private var userId: String? = null

        // Service state tracking
        @Volatile
        private var isServiceRunning = false

        // Static references to track active notification effects
        private var activeMediaPlayer: MediaPlayer? = null
        private var activeVibrator: Vibrator? = null
        private var stopVibrationRunnable: Runnable? = null
        private var notificationHandler: Handler? = null

        // Method to cache user ID from MainActivity
        fun setUserId(id: String?) {
            userId = id
            Log.d("CookieSenderService", "Static userId set to: $id")
        }

        // Check if service is running
        fun isRunning(): Boolean = isServiceRunning

        // Static method to stop notification effects (sound and vibration)
        fun stopNotificationEffects(context: Context) {
            try {
                Log.d("CookieSenderService", "Stopping notification effects")

                // Stop and release MediaPlayer
                activeMediaPlayer?.let { mediaPlayer ->
                    if (mediaPlayer.isPlaying) {
                        mediaPlayer.stop()
                        Log.d("CookieSenderService", "MediaPlayer stopped")
                    }
                    mediaPlayer.release()
                    activeMediaPlayer = null
                }

                // Cancel vibration
                activeVibrator?.let { vibrator ->
                    vibrator.cancel()
                    Log.d("CookieSenderService", "Vibration cancelled")
                    activeVibrator = null
                }

                // Cancel scheduled vibration stop if it exists
                stopVibrationRunnable?.let { runnable ->
                    notificationHandler?.removeCallbacks(runnable)
                    stopVibrationRunnable = null
                    Log.d("CookieSenderService", "Scheduled vibration stop cancelled")
                }

                // Show feedback to user
                Toast.makeText(context, "Notification silenced", Toast.LENGTH_SHORT).show()

            } catch (e: Exception) {
                Log.e("CookieSenderService", "Error stopping notification effects", e)
            }
        }
    }

    // Runnable that sends the cookie and reschedules itself
    private val checkOrdersRunnable = object : Runnable {
        override fun run() {
            // Mark service as active
            isServiceRunning = true

            // Debug user ID retrieval
            debugUserIdRetrieval()

            val cachedUserId = userId

            if (cachedUserId != null) {
                checkPendingOrders(cachedUserId)

                // Store user ID in shared preferences for recovery
                val prefs = applicationContext.getSharedPreferences("ZooBoxCustomerPrefs", Context.MODE_PRIVATE)
                prefs.edit().putString("user_id", cachedUserId).apply()
                Log.d("CookieSenderService", "User ID stored in preferences: $cachedUserId")
            } else {
                // If no cached user ID, try to get it from cookies
                val newUserId = getUserIdCookie()
                if (newUserId != null) {
                    userId = newUserId
                    checkPendingOrders(newUserId)

                    // Store user ID in shared preferences for recovery
                    val prefs = applicationContext.getSharedPreferences("ZooBoxCustomerPrefs", Context.MODE_PRIVATE)
                    prefs.edit().putString("user_id", newUserId).apply()
                    Log.d("CookieSenderService", "New user ID found and stored: $newUserId")

                    // Update notification to show "Connected"
                    updateNotificationStatus()
                } else {
                    Log.w("CookieSenderService", "No user ID available from any source")
                }
            }

            // Schedule next run with multiple handlers for redundancy
            handler.postDelayed(this, sendInterval)

            // Also schedule with backup handlers
            restartHandler1.postDelayed({
                if (!isServiceRunning) {
                    Log.d("CookieSenderService", "Service not running detected by backup handler 1")
                    triggerImmediateRestart()
                }
            }, sendInterval + 5000) // 5 seconds after main check

            restartHandler2.postDelayed({
                if (!isServiceRunning) {
                    Log.d("CookieSenderService", "Service not running detected by backup handler 2")
                    triggerImmediateRestart()
                }
            }, sendInterval + 10000) // 10 seconds after main check
        }
    }

    // Enhanced debugging method for user ID retrieval
    private fun debugUserIdRetrieval() {
        Log.d("CookieSenderService", "=== USER ID DEBUG START ===")
        Log.d("CookieSenderService", "Static userId: $userId")

        // Check cookies
        val cookieUserId = getUserIdCookie()
        Log.d("CookieSenderService", "Cookie userId: $cookieUserId")

        // Check SharedPreferences
        val prefs = applicationContext.getSharedPreferences("ZooBoxCustomerPrefs", Context.MODE_PRIVATE)
        val prefsUserId = prefs.getString("user_id", null)
        Log.d("CookieSenderService", "SharedPrefs userId: $prefsUserId")

        // Check all cookies for debugging
        try {
            val cookieManager = CookieManager.getInstance()
            val allCookies = cookieManager.getCookie("https://mikmik.site")
            Log.d("CookieSenderService", "All cookies for mikmik.site: $allCookies")
        } catch (e: Exception) {
            Log.e("CookieSenderService", "Error getting all cookies", e)
        }

        Log.d("CookieSenderService", "=== USER ID DEBUG END ===")
    }

    // Method to update notification when user ID becomes available
    private fun updateNotificationStatus() {
        if (isServiceRunning) {
            try {
                val notification = createNotification()
                val notificationManager = getSystemService(NotificationManager::class.java)
                notificationManager.notify(NOTIFICATION_ID, notification)
                Log.d("CookieSenderService", "Notification updated - Connected: ${userId != null}")
            } catch (e: Exception) {
                Log.e("CookieSenderService", "Error updating notification", e)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()

        isServiceRunning = true
        Log.d("CookieSenderService", "Service created - marking as running")

        // Create notification channels
        createNotificationChannels()

        // Initialize the static handler reference
        notificationHandler = handler

        // Acquire enhanced wake locks to keep service running on locked device
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager

        // Partial wake lock to keep CPU running - use indefinite duration
        try {
            partialWakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "ZooBox:OrderCheckPartialWakeLock"
            )
            partialWakeLock?.acquire() // Acquire indefinitely
            Log.d("CookieSenderService", "Partial wake lock acquired")
        } catch (e: Exception) {
            Log.e("CookieSenderService", "Failed to acquire partial wake lock", e)
        }

        // Screen dim wake lock for notification visibility
        try {
            @Suppress("DEPRECATION")
            screenWakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_DIM_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "ZooBox:OrderCheckScreenWakeLock"
            )
            Log.d("CookieSenderService", "Screen wake lock created successfully")
        } catch (e: Exception) {
            Log.w("CookieSenderService", "Could not create screen wake lock", e)
        }

        // Set up multiple restart mechanisms immediately
        setupImmediateRestartMechanisms()
        setupServiceRestartAlarms()

        // Schedule WorkManager backup job
        scheduleBackupWorker()

        // Schedule aggressive monitoring
        scheduleAggressiveMonitoring()

        Log.d("CookieSenderService", "Service created with all restart mechanisms")
    }

    private fun setupImmediateRestartMechanisms() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Immediate restart alarm (every 30 seconds)
        val immediateRestartIntent = Intent(this, BootCompletedReceiver::class.java).apply {
            action = "com.zoobox.customer.IMMEDIATE_RESTART"
        }

        val immediatePendingIntent = PendingIntent.getBroadcast(
            this,
            IMMEDIATE_RESTART_ALARM_ID,
            immediateRestartIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + 30000, // 30 seconds
                    immediatePendingIntent
                )
            } else {
                alarmManager.setRepeating(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + 30000,
                    30000, // Every 30 seconds
                    immediatePendingIntent
                )
            }
            Log.d("CookieSenderService", "Immediate restart alarm set (30 seconds)")
        } catch (e: Exception) {
            Log.e("CookieSenderService", "Failed to set immediate restart alarm", e)
        }
    }

    private fun setupServiceRestartAlarms() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Primary restart alarm (every 5 minutes)
        val primaryRestartIntent = Intent(this, BootCompletedReceiver::class.java).apply {
            action = "com.zoobox.customer.RESTART_SERVICE"
        }

        val primaryPendingIntent = PendingIntent.getBroadcast(
            this,
            RESTART_SERVICE_ALARM_ID,
            primaryRestartIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        // Backup restart alarm (every 10 minutes)
        val backupRestartIntent = Intent(this, BootCompletedReceiver::class.java).apply {
            action = "com.zoobox.customer.BACKUP_RESTART_SERVICE"
        }

        val backupPendingIntent = PendingIntent.getBroadcast(
            this,
            BACKUP_ALARM_ID,
            backupRestartIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Primary alarm every 5 minutes
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + (5 * 60 * 1000),
                    primaryPendingIntent
                )

                // Backup alarm every 10 minutes
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + (10 * 60 * 1000),
                    backupPendingIntent
                )
            } else {
                // For older devices, use repeating alarms
                alarmManager.setRepeating(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + (5 * 60 * 1000),
                    5 * 60 * 1000,
                    primaryPendingIntent
                )

                alarmManager.setRepeating(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + (10 * 60 * 1000),
                    10 * 60 * 1000,
                    backupPendingIntent
                )
            }
            Log.d("CookieSenderService", "Multiple service restart alarms set successfully")
        } catch (e: Exception) {
            Log.e("CookieSenderService", "Failed to set service restart alarms", e)
        }
    }

    private fun scheduleBackupWorker() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .setRequiresBatteryNotLow(false)
            .build()

        // More frequent WorkManager checks
        val workRequest = PeriodicWorkRequestBuilder<ServiceWatchdogWorker>(15, TimeUnit.MINUTES)
            .setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.LINEAR, 1, TimeUnit.MINUTES)
            .build()

        WorkManager.getInstance(applicationContext)
            .enqueueUniquePeriodicWork(
                "service_watchdog",
                ExistingPeriodicWorkPolicy.REPLACE,
                workRequest
            )

        Log.d("CookieSenderService", "WorkManager watchdog scheduled")
    }

    private fun scheduleAggressiveMonitoring() {
        // Schedule multiple monitoring jobs with different intervals
        val aggressiveWorkRequest = PeriodicWorkRequestBuilder<AggressiveServiceMonitor>(15, TimeUnit.MINUTES)
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()
            )
            .build()

        WorkManager.getInstance(applicationContext)
            .enqueueUniquePeriodicWork(
                "aggressive_monitor",
                ExistingPeriodicWorkPolicy.REPLACE,
                aggressiveWorkRequest
            )
    }

    private fun triggerImmediateRestart() {
        Log.d("CookieSenderService", "Triggering immediate restart")

        // Method 1: Direct restart
        try {
            val serviceIntent = Intent(applicationContext, CookieSenderService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(serviceIntent)
            } else {
                applicationContext.startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.e("CookieSenderService", "Direct restart failed", e)
        }

        // Method 2: Broadcast restart
        try {
            val restartIntent = Intent(applicationContext, BootCompletedReceiver::class.java).apply {
                action = "com.zoobox.customer.IMMEDIATE_RESTART"
            }
            sendBroadcast(restartIntent)
        } catch (e: Exception) {
            Log.e("CookieSenderService", "Broadcast restart failed", e)
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java)

            // Service notification channel (low priority)
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Order Check Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background service to check for pending orders"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }

            // High-priority order notification channel optimized for locked devices
            val orderChannel = NotificationChannel(
                ORDER_CHANNEL_ID,
                "New Orders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Critical notifications for new orders"
                enableLights(true)
                lightColor = Color.RED
                enableVibration(true)
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true) // Bypass Do Not Disturb
                importance = NotificationManager.IMPORTANCE_HIGH

                // Custom vibration pattern for customer alerts
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 1000)

                // Set custom sound
                try {
                    val soundUri = getRawUri(R.raw.new_order_sound)
                    setSound(
                        soundUri,
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .setFlags(AudioAttributes.FLAG_AUDIBILITY_ENFORCED)
                            .build()
                    )
                    Log.d("CookieSenderService", "Custom notification sound set: $soundUri")
                } catch (e: Exception) {
                    Log.e("CookieSenderService", "Error setting custom sound", e)
                }
            }

            // Create both channels
            notificationManager.createNotificationChannel(serviceChannel)
            notificationManager.createNotificationChannel(orderChannel)
        }
    }

    // Helper method to get the correct URI for the raw resource
    private fun getRawUri(rawResId: Int): Uri {
        return Uri.parse("android.resource://$packageName/$rawResId")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isServiceRunning = true

        // Enhanced user ID recovery with multiple methods
        recoverUserId()

        // Start as a foreground service with notification
        startForeground(NOTIFICATION_ID, createNotification())
        Log.d("CookieSenderService", "Service started in foreground (restart count: $restartCount)")

        // Start checking for orders
        handler.removeCallbacks(checkOrdersRunnable) // Remove any existing callbacks
        handler.post(checkOrdersRunnable)

        // If service is killed by system, restart it with sticky behavior
        return START_STICKY
    }

    // Enhanced user ID recovery method
    private fun recoverUserId() {
        Log.d("CookieSenderService", "Starting user ID recovery process...")

        if (userId == null) {
            // Method 1: Try SharedPreferences first
            val prefs = applicationContext.getSharedPreferences("ZooBoxCustomerPrefs", Context.MODE_PRIVATE)
            val savedUserId = prefs.getString("user_id", null)

            if (savedUserId != null && savedUserId.isNotEmpty()) {
                userId = savedUserId
                Log.d("CookieSenderService", "Recovered user ID from SharedPreferences: $savedUserId")

                // Update notification immediately
                updateNotificationStatus()
                return
            }

            // Method 2: Try cookies if SharedPreferences didn't work
            val cookieUserId = getUserIdCookie()
            if (cookieUserId != null && cookieUserId.isNotEmpty()) {
                userId = cookieUserId
                // Save to SharedPreferences for future recovery
                prefs.edit().putString("user_id", cookieUserId).apply()
                Log.d("CookieSenderService", "Recovered user ID from cookies: $cookieUserId")

                // Update notification immediately
                updateNotificationStatus()
                return
            }

            Log.w("CookieSenderService", "Could not recover user ID from any source")
        } else {
            Log.d("CookieSenderService", "User ID already available: $userId")
        }
    }

    private fun createNotification(): Notification {
        // Create an intent to launch the app when notification is tapped
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            else
                PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Determine connection status more accurately
        val connectionStatus = when {
            userId != null && userId!!.isNotEmpty() -> "Connected"
            else -> "Connecting"
        }

        Log.d("CookieSenderService", "Creating notification with status: $connectionStatus (userId: $userId)")

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ZooBox Customer")
            .setContentText("🟢 Active Monitoring - Orders: $connectionStatus")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null // No binding provided
    }

    override fun onDestroy() {
        super.onDestroy()

        isServiceRunning = false
        restartCount++
        Log.d("CookieSenderService", "Service destroyed (restart count: $restartCount) - IMMEDIATE RESTART TRIGGERED")

        // Store restart count for tracking
        val prefs = applicationContext.getSharedPreferences("ZooBoxCustomerPrefs", Context.MODE_PRIVATE)
        prefs.edit().putInt("service_restart_count", restartCount).apply()

        // Clean up resources
        handler.removeCallbacks(checkOrdersRunnable)
        restartHandler1.removeCallbacksAndMessages(null)
        restartHandler2.removeCallbacksAndMessages(null)
        restartHandler3.removeCallbacksAndMessages(null)

        // Stop any active notification effects
        activeMediaPlayer?.let {
            try {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            } catch (e: Exception) {
                Log.e("CookieSenderService", "Error stopping media player", e)
            }
            activeMediaPlayer = null
        }

        activeVibrator?.let {
            try {
                it.cancel()
            } catch (e: Exception) {
                Log.e("CookieSenderService", "Error stopping vibrator", e)
            }
            activeVibrator = null
        }

        // IMMEDIATE RESTART - Multiple methods simultaneously
        restartServiceImmediately()

        Log.d("CookieSenderService", "Service destroyed, immediate restart methods executed")
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)

        // This gets called when the user swipes away the app from recent tasks
        Log.d("CookieSenderService", "🚨 TASK REMOVED - IMMEDIATE RESTART INITIATED")

        isServiceRunning = false

        // IMMEDIATE restart when task is removed
        restartServiceImmediately()

        // Re-setup all alarms to ensure they survive task removal
        setupImmediateRestartMechanisms()
        setupServiceRestartAlarms()

        Log.d("CookieSenderService", "Task removed - all restart mechanisms re-initialized")
    }

    private fun restartServiceImmediately() {
        // Method 1: Immediate direct restart (no delay)
        try {
            val serviceIntent = Intent(applicationContext, CookieSenderService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(serviceIntent)
            } else {
                applicationContext.startService(serviceIntent)
            }
            Log.d("CookieSenderService", "✅ Immediate direct service restart attempted")
        } catch (e: Exception) {
            Log.e("CookieSenderService", "❌ Error in immediate direct service restart", e)
        }

        // Method 2: Immediate broadcast restart
        try {
            val restartIntent = Intent(applicationContext, BootCompletedReceiver::class.java).apply {
                action = "com.zoobox.customer.IMMEDIATE_RESTART"
            }
            sendBroadcast(restartIntent)
            Log.d("CookieSenderService", "✅ Immediate broadcast restart attempted")
        } catch (e: Exception) {
            Log.e("CookieSenderService", "❌ Error in immediate broadcast restart", e)
        }

        // Method 3: Multiple delayed restarts (1s, 3s, 5s, 10s)
        val delays = listOf(1000L, 3000L, 5000L, 10000L)
        delays.forEach { delay ->
            try {
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        val delayedServiceIntent = Intent(applicationContext, CookieSenderService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            applicationContext.startForegroundService(delayedServiceIntent)
                        } else {
                            applicationContext.startService(delayedServiceIntent)
                        }
                        Log.d("CookieSenderService", "✅ Delayed restart executed after ${delay}ms")
                    } catch (e: Exception) {
                        Log.e("CookieSenderService", "❌ Error in delayed restart after ${delay}ms", e)
                    }
                }, delay)
            } catch (e: Exception) {
                Log.e("CookieSenderService", "❌ Error setting up delayed restart for ${delay}ms", e)
            }
        }

        // Method 4: Aggressive alarm restart
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val aggressiveRestartIntent = Intent(applicationContext, BootCompletedReceiver::class.java).apply {
                action = "com.zoobox.customer.AGGRESSIVE_RESTART"
            }

            val aggressivePendingIntent = PendingIntent.getBroadcast(
                applicationContext,
                99999,
                aggressiveRestartIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + 2000, // 2 seconds
                    aggressivePendingIntent
                )
            } else {
                alarmManager.set(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + 2000,
                    aggressivePendingIntent
                )
            }
            Log.d("CookieSenderService", "✅ Aggressive alarm restart set")
        } catch (e: Exception) {
            Log.e("CookieSenderService", "❌ Error setting aggressive alarm restart", e)
        }
    }

    private fun getUserIdCookie(): String? {
        try {
            val cookieManager = CookieManager.getInstance()
            val cookies = cookieManager.getCookie("https://mikmik.site") ?: return null

            for (cookie in cookies.split(";")) {
                val trimmedCookie = cookie.trim()
                if (trimmedCookie.startsWith("user_id=")) {
                    val extractedUserId = trimmedCookie.substring("user_id=".length)
                    Log.d("CookieSenderService", "Found user_id in cookies: $extractedUserId")
                    return extractedUserId
                }
            }
            Log.d("CookieSenderService", "No user_id found in cookies")
        } catch (e: Exception) {
            Log.e("CookieSenderService", "Error getting user_id from cookies", e)

            // Try to recover from shared preferences as fallback
            val prefs = applicationContext.getSharedPreferences("ZooBoxCustomerPrefs", Context.MODE_PRIVATE)
            val fallbackUserId = prefs.getString("user_id", null)
            Log.d("CookieSenderService", "Fallback to SharedPreferences userId: $fallbackUserId")
            return fallbackUserId
        }
        return null
    }

    private fun checkPendingOrders(userId: String) {
        // Create the URL with user_id as a GET parameter
        val urlBuilder = serverBaseUrl.toHttpUrlOrNull()?.newBuilder() ?: return
        urlBuilder.addQueryParameter("user_id", userId)
        val url = urlBuilder.build()

        // Build the request
        val request = Request.Builder()
            .url(url)
            .get()
            .build()

        // Execute the request asynchronously
        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("CookieSenderService", "Network error: ${e.message}")
            }

            override fun onResponse(call: Call, response: Response) {
                try {
                    val responseBody = response.body?.string()
                    if (responseBody != null) {
                        val json = JSONObject(responseBody)
                        val success = json.optBoolean("success", false)
                        val message = json.optString("message", "")
                        val count = json.optInt("count", 0)

                        // Get notifications array
                        val notificationsArray = json.optJSONArray("notifications")

                        if (success && count > 0 && notificationsArray != null) {
                            // Process each notification
                            for (i in 0 until notificationsArray.length()) {
                                val notification = notificationsArray.getJSONObject(i)
                                val orderId = notification.optString("order_id", "")
                                val type = notification.optString("type", "")
                                val notificationMessage = notification.optString("message", "")
                                val heroName = notification.optString("hero", "")
                                val timestamp = notification.optString("timestamp", "")
                                val orderDate = notification.optString("date", "") // Get date from notification

                                // Show notification only if we haven't shown one recently
                                val currentTime = System.currentTimeMillis()
                                if (currentTime - lastNotificationTime > 5000) { // 5 seconds between notifications
                                    lastNotificationTime = currentTime

                                    handler.post {
                                        // Show toast
                                        Toast.makeText(applicationContext, notificationMessage, Toast.LENGTH_LONG).show()

                                        // Show notification with type-specific handling and date
                                        showOrderNotification(notificationMessage, type, orderId, heroName, orderDate)

                                        Log.d("CookieSenderService", "Notification triggered: $type for order $orderId on date $orderDate")
                                    }
                                }
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e("CookieSenderService", "Error processing response", e)
                }
            }
        })
    }

    private fun showOrderNotification(message: String, type: String = "arrival", orderId: String = "", heroName: String = "", orderDate: String = "") {
        try {
            // Different notification behavior based on type
            val notificationTitle = when (type) {
                "hero_assigned" -> "👨‍🍳 Hero Assigned!"
                "arrival" -> "🚗 Hero Arrived!"
                "pickup" -> "📦 Order Picked Up!"
                "delivered" -> "✅ Order Delivered!"
                else -> "🚨 Order Update!"
            }

            // ALL notifications now use track_order.php with order_id and date parameters
            val targetUrl = "https://mikmik.site/track_order.php?order_id=$orderId&date=$orderDate"

            // Different vibration patterns for different types
            val vibrationPattern = when (type) {
                "hero_assigned" -> longArrayOf(0, 300, 100, 300, 100, 300) // Gentle notification
                "arrival" -> longArrayOf(0, 800, 200, 800, 200, 1200) // Urgent
                "pickup" -> longArrayOf(0, 400, 100, 400) // Medium
                "delivered" -> longArrayOf(0, 200, 100, 200, 100, 200) // Gentle
                else -> longArrayOf(0, 500, 200, 500)
            }

            // Screen wake lock for important notifications (arrival and hero_assigned)
            if (type in listOf("arrival", "hero_assigned")) {
                try {
                    screenWakeLock?.let { wakeLock ->
                        if (!wakeLock.isHeld) {
                            val wakeTime = if (type == "arrival") 30000 else 15000 // 30s for arrival, 15s for hero assigned
                            wakeLock.acquire(wakeTime.toLong())
                            handler.postDelayed({
                                try {
                                    if (wakeLock.isHeld) {
                                        wakeLock.release()
                                    }
                                } catch (e: Exception) {
                                    Log.e("CookieSenderService", "Error releasing screen wake lock", e)
                                }
                            }, wakeTime.toLong())
                        }
                    }
                } catch (e: Exception) {
                    Log.w("CookieSenderService", "Could not acquire screen wake lock", e)
                }
            }

            // Create intent with target URL
            val notificationIntent = Intent(this, MainActivity::class.java).apply {
                putExtra("ORDER_NOTIFICATION", true)
                putExtra("TARGET_URL", targetUrl)
                putExtra("NOTIFICATION_TYPE", type)
                putExtra("ORDER_ID", orderId)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getActivity(
                this,
                System.currentTimeMillis().toInt(),
                notificationIntent,
                pendingIntentFlags
            )

            // Vibration
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            activeVibrator = vibrator

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val vibrationEffect = VibrationEffect.createWaveform(vibrationPattern, -1)
                vibrator.vibrate(vibrationEffect)
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(vibrationPattern, -1)
            }

            // Sound (for hero_assigned, arrival and pickup)
            if (type in listOf("hero_assigned", "arrival", "pickup")) {
                try {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    if (audioManager.ringerMode != AudioManager.RINGER_MODE_SILENT) {
                        val soundUri = getRawUri(R.raw.new_order_sound)
                        val mediaPlayer = MediaPlayer()
                        activeMediaPlayer = mediaPlayer

                        mediaPlayer.setDataSource(this, soundUri)
                        mediaPlayer.setAudioAttributes(
                            AudioAttributes.Builder()
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                                .setFlags(AudioAttributes.FLAG_AUDIBILITY_ENFORCED)
                                .build()
                        )

                        mediaPlayer.setOnCompletionListener { player ->
                            try {
                                player.release()
                                if (activeMediaPlayer == player) {
                                    activeMediaPlayer = null
                                }
                            } catch (e: Exception) {
                                Log.e("CookieSenderService", "Error releasing media player", e)
                            }
                        }

                        mediaPlayer.prepare()
                        mediaPlayer.start()
                    }
                } catch (e: Exception) {
                    Log.e("CookieSenderService", "Error playing notification sound", e)
                    activeMediaPlayer = null
                }
            }

            // Create notification
            val notificationId = NOTIFICATION_ID + 100 + (System.currentTimeMillis() % 100).toInt()

            val priority = when (type) {
                "hero_assigned" -> NotificationCompat.PRIORITY_HIGH
                "arrival" -> NotificationCompat.PRIORITY_MAX
                "pickup" -> NotificationCompat.PRIORITY_HIGH
                "delivered" -> NotificationCompat.PRIORITY_DEFAULT
                else -> NotificationCompat.PRIORITY_HIGH
            }

            val color = when (type) {
                "hero_assigned" -> Color.MAGENTA
                "arrival" -> Color.RED
                "pickup" -> Color.BLUE
                "delivered" -> Color.GREEN
                else -> Color.YELLOW
            }

            val notificationBuilder = NotificationCompat.Builder(this, ORDER_CHANNEL_ID)
                .setContentTitle(notificationTitle)
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText("$notificationTitle\n\n$message\n\nTap to view details"))
                .setSmallIcon(R.mipmap.ic_launcher)
                .setLargeIcon(BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher))
                .setContentIntent(pendingIntent)
                .setPriority(priority)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setColorized(true)
                .setColor(color)
                .setDefaults(0)
                .setOnlyAlertOnce(false)
                .setTimeoutAfter(60000)

            val notification = notificationBuilder.build()
            notification.flags = notification.flags or Notification.FLAG_SHOW_LIGHTS

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(notificationId, notification)

            Log.d("CookieSenderService", "$type notification sent for order $orderId with URL: $targetUrl")

        } catch (e: Exception) {
            Log.e("CookieSenderService", "Error showing order notification", e)
        }
    }
}