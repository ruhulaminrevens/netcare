package com.ruhulaminrevens.ruhul_netcare

import android.app.*
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.TrafficStats
import android.os.*
import android.provider.Settings
import android.view.*
import android.widget.TextView
import java.util.Locale

@Suppress("DEPRECATION")
class MeterService : Service() {
    companion object { @Volatile var running = false; private set }
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var windows: WindowManager
    private var label: TextView? = null
    private var lastTime = 0L
    private var rx = -1L
    private var tx = -1L
    private var unit = "Mbps"
    private val tick = object : Runnable {
        override fun run() {
            if (!Settings.canDrawOverlays(this@MeterService)) { stopSelf(); return }
            val now = SystemClock.elapsedRealtime()
            val down = TrafficStats.getTotalRxBytes()
            val up = TrafficStats.getTotalTxBytes()
            val seconds = (now - lastTime) / 1000.0
            if (lastTime > 0 && seconds > 0 && rx >= 0 && tx >= 0 && down >= rx && up >= tx) {
                val divisor = if (unit == "KB/s") 1000.0 else 125000.0
                label?.text = String.format(Locale.US, "↓ %.2f %s\n↑ %.2f %s", (down-rx)/seconds/divisor, unit, (up-tx)/seconds/divisor, unit)
            } else label?.text = "↓ —   ↑ —"
            lastTime = now; rx = down; tx = up
            handler.postDelayed(this, 1000)
        }
    }
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "stop" || intent == null) { stopSelf(); return START_NOT_STICKY }
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel("netcare_meter", "Live traffic meter", NotificationManager.IMPORTANCE_LOW))
            Notification.Builder(this, "netcare_meter")
        } else Notification.Builder(this)
        val stop = PendingIntent.getService(this, 1, Intent(this, MeterService::class.java).setAction("stop"), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val open = PendingIntent.getActivity(this, 2, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = builder.setSmallIcon(android.R.drawable.stat_notify_sync)
            .setContentTitle("RAR NetCare mini meter").setContentText("Live device download and upload")
            .setContentIntent(open).setOngoing(true).addAction(android.R.drawable.ic_delete, "Stop", stop).build()
        startForeground(18, notification)
        if (!Settings.canDrawOverlays(this)) { stopSelf(); return START_NOT_STICKY }
        windows = getSystemService(WINDOW_SERVICE) as WindowManager
        if (label == null) {
            val params = WindowManager.LayoutParams(-2, -2, if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT)
            params.gravity = Gravity.TOP or Gravity.LEFT
            params.x = 16; params.y = 140
            val view = TextView(this).apply {
                setPadding(18, 8, 18, 8)
                background = GradientDrawable().apply { setColor(Color.argb(232, 14, 30, 45)); cornerRadius = 16f }
                typeface = Typeface.MONOSPACE
            }
            var originX = 0; var originY = 0; var touchX = 0f; var touchY = 0f
            view.setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> { originX = params.x; originY = params.y; touchX = event.rawX; touchY = event.rawY }
                    MotionEvent.ACTION_MOVE -> {
                        val bounds = resources.displayMetrics
                        params.x = (originX + (event.rawX-touchX).toInt()).coerceIn(0, (bounds.widthPixels-view.width).coerceAtLeast(0))
                        params.y = (originY + (event.rawY-touchY).toInt()).coerceIn(0, (bounds.heightPixels-view.height).coerceAtLeast(0))
                        windows.updateViewLayout(view, params)
                    }
                }
                true
            }
            try { windows.addView(view, params) } catch (_: RuntimeException) { stopSelf(); return START_NOT_STICKY }
            label = view; running = true; handler.post(tick)
        }
        unit = if (intent.getStringExtra("unit") == "KB/s") "KB/s" else "Mbps"
        label?.textSize = intent.getIntExtra("size", 15).coerceIn(12, 24).toFloat()
        label?.setTextColor(if (intent.getBooleanExtra("amber", false)) Color.rgb(255, 198, 84) else Color.rgb(106, 242, 218))
        return START_NOT_STICKY
    }
    override fun onDestroy() {
        handler.removeCallbacks(tick)
        label?.let { windows.removeViewImmediate(it) }; label = null; running = false
        stopForeground(true); super.onDestroy()
    }
}
