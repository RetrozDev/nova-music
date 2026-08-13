package com.novamusic.nova_music

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLException
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.youtubedl_android.mapper.VideoInfo
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var progressSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            YoutubeDL.getInstance().init(applicationContext)
        } catch (e: YoutubeDLException) {
            // yt-dlp indisponible : les flux utiliseront le repli Dart.
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova_music/installer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> handleInstallApk(call, result)
                    "openInstallSettings" -> handleOpenInstallSettings(result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova_music/ytdl")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "streamUrl" -> handleStreamUrl(call, result)
                    "download" -> handleDownload(call, result)
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "nova_music/ytdl_progress")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressSink = events
                }

                override fun onCancel(arguments: Any?) {
                    progressSink = null
                }
            })
    }

    // ---- Installation APK ----

    private fun handleInstallApk(call: MethodCall, result: MethodChannel.Result) {
        val path = call.arguments as? String
        if (path.isNullOrEmpty()) {
            result.error("bad_args", "Chemin APK manquant", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            result.error(
                "install_permission_required",
                "Autorisez l'installation d'applications inconnues",
                null
            )
            return
        }
        try {
            val file = File(path)
            if (!file.exists()) {
                result.error("file_not_found", "APK introuvable : $path", null)
                return
            }
            val uri: Uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error(
                "install_failed",
                e.message ?: "Impossible d'ouvrir l'installeur",
                null
            )
        }
    }

    private fun handleOpenInstallSettings(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                )
                startActivity(intent)
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            result.error("settings_failed", e.message, null)
        }
    }

    // ---- yt-dlp : URL de lecture ----

    private fun handleStreamUrl(call: MethodCall, result: MethodChannel.Result) {
        val videoId = call.arguments as? String
        if (videoId.isNullOrEmpty()) {
            result.error("bad_args", "videoId manquant", null)
            return
        }
        Thread {
            try {
                val url = "https://www.youtube.com/watch?v=$videoId"
                val request = YoutubeDLRequest(url)
                request.addOption("-f", "bestaudio[ext=m4a]/bestaudio/best")
                request.addOption("--no-playlist")
                request.addOption("--no-warnings")
                val info: VideoInfo = YoutubeDL.getInstance().getInfo(request)
                val streamUrl = info.url
                mainHandler.post {
                    if (streamUrl.isNullOrBlank()) {
                        result.error("no_url", "Aucune URL de flux", null)
                    } else {
                        result.success(streamUrl)
                    }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error(
                        "ytdl_failed",
                        e.message ?: "yt-dlp a échoué",
                        null
                    )
                }
            }
        }.start()
    }

    // ---- yt-dlp : téléchargement avec progression ----

    private fun handleDownload(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val videoId = args?.get("videoId") as? String
        val outputPath = args?.get("outputPath") as? String
        if (videoId.isNullOrEmpty() || outputPath.isNullOrEmpty()) {
            result.error("bad_args", "videoId/outputPath manquant", null)
            return
        }
        Thread {
            try {
                val url = "https://www.youtube.com/watch?v=$videoId"
                val request = YoutubeDLRequest(url)
                request.addOption("-f", "bestaudio[ext=m4a]/bestaudio/best")
                request.addOption("--no-playlist")
                request.addOption("--no-warnings")
                request.addOption("--no-mtime")
                request.addOption("-o", "$outputPath.%(ext)s")

                YoutubeDL.getInstance().execute(
                    request,
                    "nova_music_$videoId"
                ) { progress, _, _ ->
                    val percent = if (progress == null || progress.isNaN()) 0f else progress
                    mainHandler.post {
                        progressSink?.success(
                            mapOf(
                                "id" to videoId,
                                "percent" to percent,
                            )
                        )
                    }
                }

                // Cherche le fichier produit.
                val parent = File(outputPath).parentFile
                val baseName = File(outputPath).name
                val candidates = parent?.listFiles { f ->
                    f.name.startsWith("$baseName.") && !f.name.endsWith(".part")
                }
                val newest = candidates?.maxByOrNull { it.lastModified() }
                mainHandler.post {
                    if (newest != null && newest.exists()) {
                        result.success(newest.absolutePath)
                    } else {
                        result.error(
                            "no_file",
                            "Le fichier téléchargé est introuvable",
                            null
                        )
                    }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("ytdl_failed", e.message ?: "yt-dlp a échoué", null)
                }
            }
        }.start()
    }
}
