package com.appshub.bettbox

import android.os.Build
import android.os.Bundle
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import com.appshub.bettbox.plugins.AppPlugin
import com.appshub.bettbox.plugins.ServicePlugin
import com.appshub.bettbox.plugins.TilePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    // Android 13+ 预测性返回动画的回调
    private var onBackInvokedCallback: OnBackInvokedCallback? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 仅 Android 13+（API 33）注册 OnBackInvokedCallback
        // 这样侧滑时系统会播放"返回主屏"预测性动画，动画完成后执行 moveTaskToBack
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val callback = OnBackInvokedCallback {
                // 将 Activity 移到后台，而非销毁，保持内核继续运行
                moveTaskToBack(true)
            }
            onBackInvokedCallback = callback
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                callback
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(ServicePlugin())
        flutterEngine.plugins.add(TilePlugin())
        GlobalState.flutterEngine = flutterEngine
    }

    override fun onDestroy() {
        // 注销回调，防止内存泄漏
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedCallback?.let {
                onBackInvokedDispatcher.unregisterOnBackInvokedCallback(it)
            }
        }
        GlobalState.flutterEngine = null
        super.onDestroy()
    }
}