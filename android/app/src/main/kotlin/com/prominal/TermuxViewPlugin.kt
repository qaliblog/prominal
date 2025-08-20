package com.prominal

import android.content.Context
import android.view.View
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.view.TextureRegistry

class TermuxViewPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "termux_view")
        channel.setMethodCallHandler(this)
        
        binding.platformViewRegistry.registerViewFactory(
            "termux_view",
            TermuxViewFactory(binding.textureRegistry)
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}

class TermuxViewFactory(private val textureRegistry: TextureRegistry) : PlatformViewFactory(io.flutter.plugin.common.StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<String?, Any?>?
        return TermuxView(context, viewId, creationParams, textureRegistry)
    }
}

class TermuxView(
    private val context: Context,
    private val viewId: Int,
    private val creationParams: Map<String?, Any?>?,
    private val textureRegistry: TextureRegistry
) : PlatformView {
    
    private val termuxView: View = createTermuxView()
    
    private fun createTermuxView(): View {
        // Create an enhanced terminal view with better styling
        return android.widget.TextView(context).apply {
            text = "Enhanced Terminal View"
            setBackgroundColor(android.graphics.Color.BLACK)
            setTextColor(android.graphics.Color.GREEN)
            textSize = 14f
            typeface = android.graphics.Typeface.MONOSPACE
            setPadding(16, 16, 16, 16)
        }
    }

    override fun getView(): View {
        return termuxView
    }

    override fun dispose() {
        // Clean up resources
    }
}