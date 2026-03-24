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
        return engineCache.get(MAIN_ENGINE_ID) ?: createAndCacheEngine(context, engineCache)
    }

    private fun createAndCacheEngine(context: Context, cache: FlutterEngineCache): FlutterEngine {
        val engine = FlutterEngine(context.applicationContext).apply {
            GeneratedPluginRegistrant.registerWith(this)
            dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        }
        cache.put(MAIN_ENGINE_ID, engine)
        GlobalState.flutterEngine = engine
        return engine
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        listOf(
            VpnPlugin to VpnPlugin::class.java,
            AppPlugin() to AppPlugin::class.java,
            ServicePlugin() to ServicePlugin::class.java,
            TilePlugin() to TilePlugin::class.java,
        ).forEach { (plugin, clazz) ->
            if (flutterEngine.plugins.get(clazz) == null) {
                flutterEngine.plugins.add(plugin)
            }
        }

        GlobalState.flutterEngine = flutterEngine
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false
}
