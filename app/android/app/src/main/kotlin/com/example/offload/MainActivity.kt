package com.example.offload

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "offload/updater"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "appVersion" -> result.success(appVersion())
                    "canInstall" -> result.success(canInstall())
                    "openInstallSettings" -> {
                        openInstallSettings()
                        result.success(null)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("bad_args", "Не указан путь к APK", null)
                        } else {
                            try {
                                installApk(File(path))
                                result.success(null)
                            } catch (error: Exception) {
                                result.error("install_failed", error.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun appVersion(): Map<String, Any?> {
        val info = packageManager.getPackageInfo(packageName, 0)
        val build = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return mapOf("version" to info.versionName, "build" to build)
    }

    private fun canInstall(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
        }
    }

    /**
     * Ставит APK через системный PackageInstaller, а не через ACTION_VIEW.
     *
     * На vivo/iQOO обработчиком APK по умолчанию может быть V-Appstore: он
     * показывает «APK damaged» и предлагает свой магазин. PackageInstaller
     * открывает штатный установщик Android и не даёт магазину перехватить файл.
     */
    private fun installApk(file: File) {
        check(file.exists()) { "Файл обновления не найден" }
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL,
        ).apply {
            setAppPackageName(packageName)
        }
        val sessionId = installer.createSession(params)
        val session = installer.openSession(sessionId)
        try {
            file.inputStream().use { input ->
                session.openWrite("base.apk", 0, file.length()).use { output ->
                    input.copyTo(output)
                    session.fsync(output)
                }
            }
            val callback = Intent(this, InstallResultReceiver::class.java)
            val mutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                sessionId,
                callback,
                PendingIntent.FLAG_UPDATE_CURRENT or mutable,
            )
            session.commit(pendingIntent.intentSender)
        } finally {
            session.close()
        }
    }
}

/**
 * Получает результат установки от PackageInstaller. На статусе
 * STATUS_PENDING_USER_ACTION открывает системный экран подтверждения.
 */
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE,
        )
        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirmIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                if (confirmIntent != null) {
                    confirmIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(confirmIntent)
                } else {
                    Toast.makeText(
                        context,
                        "Не удалось открыть установщик",
                        Toast.LENGTH_LONG,
                    ).show()
                }
            }
            PackageInstaller.STATUS_SUCCESS -> {
                Toast.makeText(
                    context,
                    "Обновление установлено",
                    Toast.LENGTH_SHORT,
                ).show()
            }
            else -> {
                val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                Toast.makeText(
                    context,
                    message ?: "Не удалось установить обновление",
                    Toast.LENGTH_LONG,
                ).show()
            }
        }
    }
}
