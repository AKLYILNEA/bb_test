package com.appshub.bettbox.plugins

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.ComponentInfo
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.util.Base64
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.ContextCompat.getSystemService
import androidx.core.content.FileProvider
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile
import com.appshub.bettbox.BettboxApplication
import com.appshub.bettbox.GlobalState
import com.appshub.bettbox.R
import com.appshub.bettbox.extensions.awaitResult
import com.appshub.bettbox.extensions.getActionIntent
import com.appshub.bettbox.models.Package
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.lang.ref.WeakReference
import java.util.zip.ZipFile

class AppPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private var activityRef: WeakReference<Activity>? = null

    private lateinit var channel: MethodChannel

    private lateinit var scope: CoroutineScope

    private var vpnCallBack: (() -> Unit)? = null

    private val packages = mutableListOf<Package>()
    
    // Icon cache dir
    private val iconCacheDir by lazy {
        File(BettboxApplication.getAppContext().cacheDir, "app_icons").apply {
            if (!exists()) mkdirs()
        }
    }
    
    // Icon size (48dp)
    private val ICON_SIZE = 48

    private val skipPrefixList = listOf(
        "com.google",
        "com.android.chrome",
        "com.android.vending",
        "com.facebook",
        "com.instagram",
        "com.whatsapp",
        "com.twitter",
        "com.linkedin",
        "com.snapchat",
        "com.amazon",
        "com.microsoft",
        "com.apple",
        "com.dropbox",
        "com.mozilla",
        "com.brave",
        "com.duckduckgo",
        "com.vivaldi",
        "com.kiwibrowser",
        "org.torproject.torbrowser",
        "com.opera.browser",
        "com.lemon.browser",
        "net.waterfox",
        "ch.protonmail",
        "org.thoughtcrime.securesms",
        "org.telegram",
        "com.surfshark",
        "com.netflix",
        "com.spotify",
        "tv.twitch",
        "com.hulu",
        "com.disney",
        "com.hbo",
        "com.primevideo",
        "com.zhiliaoapp.musically",
        "com.nytimes",
        "bbc.mobile",
        "com.wsj",
        "com.bloomberg",
        "com.medium",
        "com.quora",
        "com.github",
        "io.github",
        "com.slack",
        "com.notion",
        "us.zoom",
        "com.discord",
        "com.reddit",
        "com.pinterest",
        "com.tumblr",
        "jp.naver.line",
        "com.skype",
        "com.box",
        "org.wikipedia",
        "com.gitlab",
        "com.openai",
        "com.valvesoftware",
        "com.roblox",
        "com.ea.gp",
        "com.ubisoft",
        "com.sogou.activity.src",
        "com.qihoo.browser",
        "com.qihoo.haosou",
        "com.liebao",
        "com.mx.browser",
        "com.browser2345",
        "com.ijinshan.browser",
        "com.quark.browser",
        "com.ylmf.androidclient",
        "mark.via",
        "com.xbrowser.play",
        "com.mycompany.app.soulbrowser",
        "com.hshentong.alook",
        "info.bmmk.mbrowser",
        "com.rainsee.browser",
        "com.liuzh.browser",
        "com.yuzhe.browser",
        "org.easyweb.browser",
        "any.browser",
        "us.spotco.fennec_dos",
        "app.grapheneos.vanadium",
        "org.ironfoxoss",
        "com.samsung.android.app.sbrowser",
        "com.mi.global.browser",
        "com.android.browser",
        "com.huawei.browser",
        "com.hihonor.browser",
        "com.heytap.browser",
        "com.coloros.browser",
        "com.oppo.browser",
        "com.vivo.browser",
        "com.bbk.browser",
        "com.meizu.browser",
        "com.meizu.mbrowser",
        "com.lenovo.browser",
        "com.zte.browser",
        "com.gionee.browser",
    )

    private val chinaAppPrefixList = listOf(
        "com.tencent",
        "com.alibaba",
        "com.ali",
        "com.alipay",
        "com.taobao",
        "com.baidu",
        "com.iqiyi",
        "com.bytedance",
        "com.ss.android",
        "com.kuaishou",
        "com.smile.gifmaker",
        "com.xunmeng",
        "com.pinduoduo",
        "com.sankuai",
        "com.meituan",
        "com.jingdong",
        "com.jd",
        "tv.danmaku",
        "com.sina",
        "com.weibo",
        "com.sohu",
        "com.netease",
        "com.zhihu",
        "com.xingin",
        "com.huawei",
        "com.xiaomi",
        "com.miui",
        "com.oppo",
        "com.coloros",
        "com.oplus",
        "andes.oplus",
        "com.vivo",
        "com.bbk",
        "com.iqoo",
        "com.meizu",
        "com.flyme",
        "com.gionee",
        "cn.nubia",
        "com.zte",
        "com.lenovo",
        "com.oneplus",
        "com.qihoo",
        "com.360",
        "com.ijiami",
        "com.bangcle",
        "com.secneo",
        "com.kiwisec",
        "com.stub",
        "com.wrapper",
        "cn.securitystack",
        "com.mogosec",
        "com.secoen",
        "com.secshell",
        "com.umeng",
        "com.igexin",
        "cn.jpush",
        "cn.jiguang",
        "com.bugly",
        "com.mob",
        "cn.wps",
        "com.kingsoft",
        "com.xunlei",
        "com.unionpay",
        "com.cainiao",
        "com.sf",
        "com.sdu",
        "com.xiaojukeji",
        "com.autonavi",
        "com.amap",
        "com.chinamobile",
        "com.chinaunicom",
        "com.chinatelecom",
        "com.icbc",
        "com.ccb",
        "com.cmbchina",
        "com.mx",
        "com.qq",
    )

    private val chinaAppRegex by lazy {
        ("(" + chinaAppPrefixList.joinToString("|").replace(".", "\\.") + ").*").toRegex()
    }

    // Cache scan results
    private val chinaPackageCache = java.util.concurrent.ConcurrentHashMap<String, Boolean>()

    val VPN_PERMISSION_REQUEST_CODE = 1001

    val NOTIFICATION_PERMISSION_REQUEST_CODE = 1002

    private var isBlockNotification: Boolean = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "app")
        channel.setMethodCallHandler(this)
        
        // Background clean icon cache on startup
        scope.launch(Dispatchers.IO) {
            cleanIconCache()
        }
    }

    private fun initShortcuts(label: String) {
        // Select icon by theme
        val iconRes = if (isSystemInDarkMode()) {
            R.mipmap.ic_launcher_round
        } else {
            R.mipmap.ic_launcher_round_light
        }
        
        val shortcut = ShortcutInfoCompat.Builder(BettboxApplication.getAppContext(), "toggle")
            .setShortLabel(label)
            .setIcon(
                IconCompat.createWithResource(
                    BettboxApplication.getAppContext(),
                    iconRes
                )
            )
            .setIntent(BettboxApplication.getAppContext().getActionIntent("CHANGE"))
            .build()
        ShortcutManagerCompat.setDynamicShortcuts(
            BettboxApplication.getAppContext(),
            listOf(shortcut)
        )
    }
    
    /**
     * Check dark mode
     */
    private fun isSystemInDarkMode(): Boolean {
        val nightModeFlags = BettboxApplication.getAppContext().resources.configuration.uiMode and 
            android.content.res.Configuration.UI_MODE_NIGHT_MASK
        return nightModeFlags == android.content.res.Configuration.UI_MODE_NIGHT_YES
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    private fun tip(message: String?) {
        if (GlobalState.flutterEngine == null) {
            Toast.makeText(BettboxApplication.getAppContext(), message, Toast.LENGTH_LONG).show()
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "moveTaskToBack" -> {
                activityRef?.get()?.moveTaskToBack(true)
                result.success(true)
            }

            "updateExcludeFromRecents" -> {
                val value = call.argument<Boolean>("value")
                updateExcludeFromRecents(value)
                result.success(true)
            }

            "initShortcuts" -> {
                initShortcuts(call.arguments as String)
                result.success(true)
            }

            "getPackages" -> {
                scope.launch {
                    try {
                        result.success(getPackagesToList())
                    } catch (e: SecurityException) {
                        result.error("PACKAGE_LIST_PERMISSION", e.message, null)
                    } catch (e: Exception) {
                        result.error("GET_PACKAGES_FAILED", e.message, null)
                    }
                }
            }

            "getChinaPackageNames" -> {
                scope.launch {
                    try {
                        result.success(getChinaPackageNamesList())
                    } catch (e: SecurityException) {
                        result.error("PACKAGE_LIST_PERMISSION", e.message, null)
                    } catch (e: Exception) {
                        result.error("GET_CHINA_PACKAGES_FAILED", e.message, null)
                    }
                }
            }

            "getPackageIcon" -> {
                scope.launch {
                    try {
                        val packageName = call.argument<String>("packageName")
                        val forceRefresh = call.argument<Boolean>("forceRefresh") ?: false
                        if (packageName == null) {
                            result.success(null)
                            return@launch
                        }
                        val packageIcon = getPackageIconBytes(packageName, forceRefresh)
                        if (packageIcon != null) {
                            result.success(packageIcon)
                            return@launch
                        }
                        result.success(getDefaultIconBytes())
                    } catch (e: Exception) {
                        result.success(getDefaultIconBytes())
                    }
                }
            }

            "tip" -> {
                val message = call.argument<String>("message")
                tip(message)
                result.success(true)
            }

            "openFile" -> {
                val path = call.argument<String>("path")!!
                openFile(path)
                result.success(true)
            }

            "getSelfLastUpdateTime" -> {
                // Get APK last update time
                // Detect reinstall/update
                val packageManager = BettboxApplication.getAppContext().packageManager
                val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    packageManager?.getPackageInfo(
                        BettboxApplication.getAppContext().packageName,
                        PackageManager.PackageInfoFlags.of(0)
                    )
                } else {
                    packageManager?.getPackageInfo(
                        BettboxApplication.getAppContext().packageName,
                        0
                    )
                }
                result.success(packageInfo?.lastUpdateTime ?: 0L)
            }

            "isIgnoringBatteryOptimizations" -> {
                result.success(isIgnoringBatteryOptimizations())
            }

            "requestIgnoreBatteryOptimizations" -> {
                requestIgnoreBatteryOptimizations()
                result.success(true)
            }

            "setLauncherIcon" -> {
                val useLightIcon = call.argument<Boolean>("useLightIcon") ?: false
                setLauncherIcon(useLightIcon)
                result.success(true)
            }

            "hasPackageListPermission" -> {
                result.success(hasPackageListPermission())
            }

            "requestPackageListPermission" -> {
                requestPackageListPermission()
                result.success(true)
            }

            "hasCameraPermission" -> {
                result.success(hasCameraPermission())
            }

            "openAppSettings" -> {
                openAppSettings()
                result.success(true)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun openFile(path: String) {
        val file = File(path)
        val uri = FileProvider.getUriForFile(
            BettboxApplication.getAppContext(),
            "${BettboxApplication.getAppContext().packageName}.fileProvider",
            file
        )

        val intent = Intent(Intent.ACTION_VIEW).setDataAndType(
            uri,
            "text/plain"
        )

        val flags =
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION

        val resInfoList = BettboxApplication.getAppContext().packageManager.queryIntentActivities(
            intent, PackageManager.MATCH_DEFAULT_ONLY
        )

        for (resolveInfo in resInfoList) {
            val packageName = resolveInfo.activityInfo.packageName
            BettboxApplication.getAppContext().grantUriPermission(
                packageName,
                uri,
                flags
            )
        }

        try {
            activityRef?.get()?.startActivity(intent)
        } catch (e: Exception) {
            println(e)
        }
    }

    private fun updateExcludeFromRecents(value: Boolean?) {
        // Block for Android 13+ (API 33+)
        if (Build.VERSION.SDK_INT >= 33) {
            android.util.Log.d("AppPlugin", "ExcludeFromRecents blocked on Android 13+")
            return
        }
        
        val am = getSystemService(BettboxApplication.getAppContext(), ActivityManager::class.java)
        val task = am?.appTasks?.firstOrNull {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                it.taskInfo.taskId == activityRef?.get()?.taskId
            } else {
                it.taskInfo.id == activityRef?.get()?.taskId
            }
        }

        when (value) {
            true -> task?.setExcludeFromRecents(value)
            false -> task?.setExcludeFromRecents(value)
            null -> task?.setExcludeFromRecents(false)
        }
    }

    private fun getIconSizePx(): Int {
        val density = BettboxApplication.getAppContext().resources.displayMetrics.density
        return (ICON_SIZE * density).toInt().coerceAtLeast(1)
    }

    private fun drawableToPngBytes(
        drawable: android.graphics.drawable.Drawable,
        sizePx: Int,
    ): ByteArray {
        val bitmap = android.graphics.Bitmap.createBitmap(
            sizePx, sizePx, android.graphics.Bitmap.Config.ARGB_8888
        )
        val canvas = android.graphics.Canvas(bitmap)
        drawable.setBounds(0, 0, sizePx, sizePx)
        drawable.draw(canvas)
        val outputStream = java.io.ByteArrayOutputStream()
        bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 80, outputStream)
        val bytes = outputStream.toByteArray()
        try {
            outputStream.close()
        } catch (_: Exception) {
        }
        bitmap.recycle()
        return bytes
    }

    private fun getDefaultIconBytes(): ByteArray? {
        val drawable = BettboxApplication.getAppContext().packageManager?.defaultActivityIcon ?: return null
        return try {
            drawableToPngBytes(drawable, getIconSizePx())
        } catch (_: Exception) {
            null
        }
    }

    private fun isPngBytes(bytes: ByteArray): Boolean {
        if (bytes.size < 8) return false
        return (bytes[0].toInt() and 0xFF) == 0x89 &&
                (bytes[1].toInt() and 0xFF) == 0x50 &&
                (bytes[2].toInt() and 0xFF) == 0x4E &&
                (bytes[3].toInt() and 0xFF) == 0x47 &&
                (bytes[4].toInt() and 0xFF) == 0x0D &&
                (bytes[5].toInt() and 0xFF) == 0x0A &&
                (bytes[6].toInt() and 0xFF) == 0x1A &&
                (bytes[7].toInt() and 0xFF) == 0x0A
    }

    private suspend fun getPackageIconBytes(packageName: String, forceRefresh: Boolean = false): ByteArray? {
        return withContext(Dispatchers.IO) {
            val packageManager = BettboxApplication.getAppContext().packageManager
            
            try {
                // 1. Get update time for cache key
                val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    packageManager?.getPackageInfo(
                        packageName,
                        PackageManager.PackageInfoFlags.of(0)
                    )
                } else {
                    packageManager?.getPackageInfo(packageName, 0)
                }
                val lastUpdateTime = packageInfo?.lastUpdateTime ?: 0L
                val cacheKey = "${packageName}_${lastUpdateTime}"
                val cacheFile = File(iconCacheDir, cacheKey)
                
                // 2. Check force refresh
                val shouldRefresh = if (forceRefresh) {
                    val currentTime = System.currentTimeMillis()
                    val twentyFourHoursInMillis = 24 * 60 * 60 * 1000L
                    (currentTime - lastUpdateTime) < twentyFourHoursInMillis
                } else {
                    false
                }
                
                if (shouldRefresh && cacheFile.exists()) {
                    cacheFile.delete()
                }
                
                // 3. Check disk cache
                if (cacheFile.exists() && cacheFile.length() > 0) {
                    try {
                        val cachedBytes = cacheFile.readBytes()
                        if (isPngBytes(cachedBytes)) {
                            return@withContext cachedBytes
                        }
                    } catch (_: Exception) {
                        cacheFile.delete()
                    }
                }
                
                // 4. Load and cache icon
                val drawable = packageManager?.getApplicationIcon(packageName)
                if (drawable != null) {
                    val bytes = drawableToPngBytes(drawable, getIconSizePx())
                    
                    try {
                        // Sync write since we are already on IO thread
                        cacheFile.writeBytes(bytes)
                    } catch (_: Exception) {
                        // Ignore write errors
                    }
                    
                    return@withContext bytes
                }
            } catch (e: Exception) {
                // Ignore
            }
            
            return@withContext null
        }
    }

    private suspend fun getPackages(): List<Package> = withContext(Dispatchers.IO) {
        if (packages.isNotEmpty()) return@withContext packages
        
        val packageManager = BettboxApplication.getAppContext().packageManager
        val appContext = BettboxApplication.getAppContext()
        val selfPackageName = appContext.packageName
        
        val apps = packageManager?.getInstalledApplications(PackageManager.GET_META_DATA).orEmpty()
        val results = ArrayList<Package>(apps.size)

        for (appInfo in apps) {
            val packageName = appInfo.packageName ?: continue
            if (packageName == selfPackageName) continue

            val label = try {
                appInfo.loadLabel(packageManager).toString()
            } catch (_: Exception) {
                packageName
            }

            val system = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            val internet = try {
                packageManager?.checkPermission(
                    Manifest.permission.INTERNET,
                    packageName
                ) == PackageManager.PERMISSION_GRANTED
            } catch (_: Exception) {
                false
            }

            val lastUpdateTime = try {
                appInfo.sourceDir?.let { File(it).lastModified() } ?: 0L
            } catch (_: Exception) {
                0L
            }

            results.add(
                Package(
                    packageName = packageName,
                    label = label,
                    system = system,
                    lastUpdateTime = lastUpdateTime,
                    internet = internet
                )
            )
        }

        packages.addAll(results)
        return@withContext packages
    }

    private suspend fun getPackagesToList(): List<Map<String, Any>> {
        return withContext(Dispatchers.Default) {
            getPackages().map {
                hashMapOf(
                    "packageName" to it.packageName,
                    "label" to it.label,
                    "system" to it.system,
                    "internet" to it.internet,
                    "lastUpdateTime" to it.lastUpdateTime,
                )
            }
        }
    }

    private suspend fun getChinaPackageNamesList(): List<String> {
        val pkgs = getPackages()
        return withContext(Dispatchers.Default) {
            pkgs.map { it.packageName }.filter { isChinaPackage(it) }
        }
    }

    private fun cleanIconCache() {
        try {
            val cacheFiles = iconCacheDir.listFiles()
            if (cacheFiles != null && cacheFiles.size > 500) {
                cacheFiles.sortedBy { it.lastModified() }
                    .take(cacheFiles.size - 500)
                    .forEach { it.delete() }
            }
        } catch (_: Exception) {}
    }

    fun requestVpnPermission(callBack: () -> Unit) {
        vpnCallBack = callBack
        val intent = VpnService.prepare(BettboxApplication.getAppContext())
        if (intent != null) {
            activityRef?.get()?.startActivityForResult(intent, VPN_PERMISSION_REQUEST_CODE)
            return
        }
        vpnCallBack?.invoke()
    }

    fun requestNotificationsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permission = ContextCompat.checkSelfPermission(
                BettboxApplication.getAppContext(),
                Manifest.permission.POST_NOTIFICATIONS
            )
            if (permission != PackageManager.PERMISSION_GRANTED) {
                if (isBlockNotification) return
                if (activityRef?.get() == null) return
                activityRef?.get()?.let {
                    ActivityCompat.requestPermissions(
                        it,
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        NOTIFICATION_PERMISSION_REQUEST_CODE
                    )
                    return
                }
            }
        }
    }

    suspend fun getText(text: String): String? {
        return withContext(Dispatchers.Default) {
            channel.awaitResult<String>("getText", text)
        }
    }

    private fun isChinaPackage(packageName: String): Boolean {
        // Check cache
        chinaPackageCache[packageName]?.let { return it }
        
        // Detect and cache
        val result = isChinaPackageInternal(packageName)
        chinaPackageCache[packageName] = result
        return result
    }

    private fun isChinaPackageInternal(packageName: String): Boolean {
        val packageManager = BettboxApplication.getAppContext().packageManager ?: return false
        
        // 1. Fast exclusion
        skipPrefixList.forEach {
            if (packageName == it || packageName.startsWith("$it.")) return false
        }
        
        // 2. Prefix matching
        if (packageName.matches(chinaAppRegex)) {
            return true
        }
        
        // 3. Certificate country check
        if (isChinaCertificate(packageName, packageManager)) {
            return true
        }
        
        // 4. Component name check
        // Note: only scan installed apps
        val packageManagerFlags = 
            PackageManager.GET_ACTIVITIES or 
            PackageManager.GET_SERVICES or 
            PackageManager.GET_RECEIVERS or 
            PackageManager.GET_PROVIDERS
        
        try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(packageManagerFlags.toLong())
                )
            } else {
                packageManager.getPackageInfo(
                    packageName, packageManagerFlags
                )
            }
            
            // Check component class names
            mutableListOf<ComponentInfo>().apply {
                packageInfo.services?.let { addAll(it) }
                packageInfo.activities?.let { addAll(it) }
                packageInfo.receivers?.let { addAll(it) }
                packageInfo.providers?.let { addAll(it) }
            }.forEach {
                if (it.name.matches(chinaAppRegex)) return true
            }
        } catch (_: Exception) {
            return false
        }
        
        return false
    }

    /**
     * Check certificate country code (CN/86)
     */
    private fun isChinaCertificate(packageName: String, packageManager: PackageManager): Boolean {
        try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES
                )
            }
            
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }
            
            signatures?.forEach { signature ->
                val cert = java.security.cert.CertificateFactory.getInstance("X.509")
                    .generateCertificate(java.io.ByteArrayInputStream(signature.toByteArray()))
                
                if (cert is java.security.cert.X509Certificate) {
                    val subject = cert.subjectDN.name
                    // Check C=CN or C=86
                    if (subject.contains("C=CN", ignoreCase = true) || 
                        subject.contains("C=86", ignoreCase = true)) {
                        return true
                    }
                }
            }
        } catch (e: Exception) {
            // Ignore errors, continue detection
        }
        return false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityRef = WeakReference(binding.activity)
        binding.addActivityResultListener(::onActivityResult)
        binding.addRequestPermissionsResultListener(::onRequestPermissionsResultListener)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityRef = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityRef = WeakReference(binding.activity)
    }

    override fun onDetachedFromActivity() {
        channel.invokeMethod("exit", null)
        activityRef = null
    }

    private fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            if (resultCode == FlutterActivity.RESULT_OK) {
                GlobalState.initServiceEngine()
                vpnCallBack?.invoke()
            }
        }
        return true
    }

    private fun onRequestPermissionsResultListener(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            isBlockNotification = true
        }
        return true
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = BettboxApplication.getAppContext().getSystemService(android.content.Context.POWER_SERVICE) as? android.os.PowerManager
            powerManager?.isIgnoringBatteryOptimizations(BettboxApplication.getAppContext().packageName) ?: false
        } else {
            true // No permission needed below Android M
        }
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent().apply {
                    action = android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                    data = android.net.Uri.parse("package:${BettboxApplication.getAppContext().packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                BettboxApplication.getAppContext().startActivity(intent)
            } catch (e: Exception) {
                // Fallback to battery optimization list
                try {
                    val intent = Intent().apply {
                        action = android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    BettboxApplication.getAppContext().startActivity(intent)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    /**
     * Switch launcher icon
     * @param useLightIcon true: light, false: dark
     */
    private fun setLauncherIcon(useLightIcon: Boolean) {
        val packageManager = BettboxApplication.getAppContext().packageManager
        val packageName = BettboxApplication.getAppContext().packageName
        
        // Default icon (dark)
        val defaultComponent = android.content.ComponentName(
            packageName,
            "com.appshub.bettbox.MainActivity"
        )
        
        // Light icon
        val lightComponent = android.content.ComponentName(
            packageName,
            "com.appshub.bettbox.MainActivityLight"
        )
        
        if (useLightIcon) {
            // Enable light icon
            packageManager.setComponentEnabledSetting(
                lightComponent,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            // Disable default icon
            packageManager.setComponentEnabledSetting(
                defaultComponent,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        } else {
            // Enable default icon
            packageManager.setComponentEnabledSetting(
                defaultComponent,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            // Disable light icon
            packageManager.setComponentEnabledSetting(
                lightComponent,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }
        
        // Update notification icon if VPN running
        VpnPlugin.updateNotificationIcon()
    }

    /**
     * Check package list permission (Android 11+)
     */
    private fun hasPackageListPermission(): Boolean {
        // Not needed below Android 11
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return true
        }

        val packageManager = BettboxApplication.getAppContext().packageManager
        val candidates = arrayOf(
            "com.android.settings",
            "com.android.systemui",
        )

        for (pkg in candidates) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    packageManager.getPackageInfo(
                        pkg,
                        PackageManager.PackageInfoFlags.of(0)
                    )
                } else {
                    packageManager.getPackageInfo(pkg, 0)
                }
                return true
            } catch (_: Exception) {
            }
        }

        return false
    }

    /**
     * Request package list permission (Open settings)
     */
    private fun requestPackageListPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            openAppSettings()
        }
    }

    private fun hasCameraPermission(): Boolean {
        val permission = ContextCompat.checkSelfPermission(
            BettboxApplication.getAppContext(),
            Manifest.permission.CAMERA
        )
        return permission == PackageManager.PERMISSION_GRANTED
    }

    private fun openAppSettings() {
        try {
            val intent = Intent().apply {
                action = android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                data = android.net.Uri.parse("package:${BettboxApplication.getAppContext().packageName}")
            }
            val activity = activityRef?.get()
            if (activity != null) {
                activity.startActivity(intent)
            } else {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                BettboxApplication.getAppContext().startActivity(intent)
            }
        } catch (_: Exception) {
        }
    }
}
