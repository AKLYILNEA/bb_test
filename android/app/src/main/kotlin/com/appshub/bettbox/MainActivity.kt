package com.appshub.bettbox

import android.content.Context
import android.os.Bundle
import com.appshub.bettbox.plugins.AppPlugin
import com.appshub.bettbox.plugins.ServicePlugin
import com.appshub.bettbox.plugins.TilePlugin
import com.appshub.bettbox.plugins.VpnPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    companion object {
        private const val MAIN_ENGINE_ID = "bettbox_main_engine"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val engineCache = FlutterEngineCache.getInstance()
        val cachedEngine = engineCache.get(MAIN_ENGINE_ID)
        if (cachedEngine != null) {
            GlobalState.flutterEngine = cachedEngine
            return cachedEngine
        }

        val engine = FlutterEngine(context.applicationContext)
        GeneratedPluginRegistrant.registerWith(engine)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        engineCache.put(MAIN_ENGINE_ID, engine)
        GlobalState.flutterEngine = engine
        return engine
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (flutterEngine.plugins.get(VpnPlugin::class.java) == null) {
            flutterEngine.plugins.add(VpnPlugin)
        }
        if (flutterEngine.plugins.get(AppPlugin::class.java) == null) {
            flutterEngine.plugins.add(AppPlugin())
        }
        if (flutterEngine.plugins.get(ServicePlugin::class.java) == null) {
            flutterEngine.plugins.add(ServicePlugin())
        }
        if (flutterEngine.plugins.get(TilePlugin::class.java) == null) {
            flutterEngine.plugins.add(TilePlugin())
        }

        GlobalState.flutterEngine = flutterEngine
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false
}
