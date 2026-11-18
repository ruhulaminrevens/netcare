package com.ruhulaminrevens.ruhul_netcare

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.concurrent.Executors

@Suppress("DEPRECATION")
class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val accounting get() = getSystemService(NETWORK_STATS_SERVICE) as NetworkStatsManager
    private fun usageAccess(): Boolean {
        val ops = getSystemService(APP_OPS_SERVICE) as AppOpsManager
        return ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName) == AppOpsManager.MODE_ALLOWED
    }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "rar_netcare/android").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "permissions" -> result.success(mapOf("usage" to usageAccess(), "overlay" to Settings.canDrawOverlays(this), "running" to MeterService.running))
                    "usageSettings" -> { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)); result.success(null) }
                    "overlaySettings" -> { startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + packageName))); result.success(null) }
                    "meter" -> {
                        val intent = Intent(this, MeterService::class.java)
                        if (call.argument<Boolean>("enabled") == true) {
                            check(Settings.canDrawOverlays(this)) { "Allow display over other apps first." }
                            intent.putExtra("unit", call.argument<String>("unit") ?: "Mbps")
                            intent.putExtra("size", call.argument<Int>("size") ?: 15)
                            intent.putExtra("amber", call.argument<Boolean>("amber") == true)
                            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                        } else stopService(intent)
                        result.success(null)
                    }
                    "network" -> result.success(networkInfo())
                    "usage", "plan", "activity" -> worker.execute {
                        try {
                            check(usageAccess()) { "Grant Usage Access in Android settings." }
                            val now = System.currentTimeMillis()
                            val transport = if (call.argument<String>("network") == "Wi-Fi") ConnectivityManager.TYPE_WIFI else ConnectivityManager.TYPE_MOBILE
                            val value: Any = when (call.method) {
                                "activity" -> activityRows(now)
                                "plan" -> {
                                    val month = midnight().apply { set(Calendar.DAY_OF_MONTH, 1) }
                                    val b = accounting.querySummaryForDevice(transport, null, month.timeInMillis, now) ?: error("Monthly usage is unavailable")
                                    mapOf("rx" to b.rxBytes, "tx" to b.txBytes)
                                }
                                else -> usageRows(transport, (call.argument<Int>("days") ?: 7).coerceIn(1,90), now, call.argument<Boolean>("apps") == true)
                            }
                            runOnUiThread { result.success(value) }
                        } catch (e: Exception) { runOnUiThread { result.error("usage", e.localizedMessage ?: "Android usage unavailable", null) } }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("android", e.localizedMessage ?: "Android operation unavailable", null) }
        }
    }
    private fun midnight() = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }
    private fun appLabel(pkg: String): String = try {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
    } catch (_: Exception) { pkg }

    private fun usageRows(type: Int, days: Int, now: Long, apps: Boolean): List<Map<String, Any>> {
        val date = midnight().apply { add(Calendar.DATE, 1 - days) }
        if (apps) {
            val totals = mutableMapOf<Int, LongArray>()
            val stats = accounting.querySummary(type, null, date.timeInMillis, now) ?: error("Usage records unavailable")
            try {
                val b = NetworkStats.Bucket()
                while (stats.getNextBucket(b)) {
                    val v = totals.getOrPut(b.uid) { longArrayOf(0, 0) }
                    v[0] += b.rxBytes; v[1] += b.txBytes
                }
            } finally { stats.close() }
            return totals.entries.sortedByDescending { it.value.sum() }.map { (uid, bytes) ->
                val names = packageManager.getPackagesForUid(uid)?.map { appLabel(it) }?.distinct().orEmpty()
                mapOf("label" to names.joinToString(", ").ifEmpty { "UID " + uid }, "rx" to bytes[0], "tx" to bytes[1])
            }
        }
        return List(days) {
            val start = date.timeInMillis
            date.add(Calendar.DATE, 1)
            val bucket = accounting.querySummaryForDevice(type, null, start, minOf(now, date.timeInMillis)) ?: error("Daily usage is unavailable")
            mapOf("day" to start, "rx" to bucket.rxBytes, "tx" to bucket.txBytes)
        }
    }
    private fun activityRows(now: Long): List<Map<String, Any>> {
        val manager = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
        val start = now - 24L * 60 * 60 * 1000
        return manager.queryAndAggregateUsageStats(start, now).values
            .filter { it.lastTimeUsed in start..now }.sortedByDescending { it.lastTimeUsed }
            .map { mapOf("label" to appLabel(it.packageName), "package" to it.packageName, "last" to it.lastTimeUsed) }
    }
    private fun networkInfo(): Map<String, String> {
        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        val link = cm.getLinkProperties(cm.activeNetwork)
        val caps = cm.getNetworkCapabilities(cm.activeNetwork)
        val types = listOf(NetworkCapabilities.TRANSPORT_WIFI to "Wi-Fi", NetworkCapabilities.TRANSPORT_CELLULAR to "Mobile", NetworkCapabilities.TRANSPORT_VPN to "VPN", NetworkCapabilities.TRANSPORT_ETHERNET to "Ethernet")
        val out = linkedMapOf("Connection" to types.filter { caps?.hasTransport(it.first) == true }.joinToString(" + ") { it.second }.ifEmpty { "No active connection" })
        if (link != null) {
            out["Interface"] = link.interfaceName ?: "—"
            out["Local addresses"] = link.linkAddresses.joinToString("\n") { it.address.hostAddress + "/" + it.prefixLength }
            out["DNS"] = link.dnsServers.joinToString("\n") { it.hostAddress.orEmpty() }
            out["Gateway"] = link.routes.filter { it.isDefaultRoute }.mapNotNull { it.gateway?.hostAddress }.distinct().joinToString("\n").ifEmpty { "—" }
            out["Metered"] = if (cm.isActiveNetworkMetered) "Yes" else "No"
        }
        if (caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true) {
            val wifi = (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager).connectionInfo
            if (wifi != null) {
                out["Wi-Fi name"] = wifi.ssid.takeUnless { it == "<unknown ssid>" }?.trim('"') ?: "Hidden by Android"
                if (wifi.rssi in -126..0) out["Signal"] = wifi.rssi.toString() + " dBm"
                if (wifi.frequency > 0) out["Frequency"] = wifi.frequency.toString() + " MHz"
                if (wifi.linkSpeed > 0) out["Link speed"] = wifi.linkSpeed.toString() + " Mbps"
            }
        }
        val am = getSystemService(ACTIVITY_SERVICE) as ActivityManager
        out["Visible processes"] = am.runningAppProcesses.orEmpty().joinToString("\n") { it.processName + " · PID " + it.pid }.ifEmpty { "Unavailable" }
        return out
    }
    override fun onDestroy() { worker.shutdown(); super.onDestroy() }
}
