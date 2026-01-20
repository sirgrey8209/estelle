package com.nexus.android

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

class UpdateChecker(private val context: Context) {
    private val client = OkHttpClient()
    private val githubApiUrl = "https://api.github.com/repos/sirgrey8209/estelle/releases/latest"
    private val currentVersion = BuildConfig.VERSION_NAME

    data class UpdateInfo(
        val hasUpdate: Boolean,
        val latestVersion: String,
        val downloadUrl: String?
    )

    suspend fun checkForUpdate(): UpdateInfo = withContext(Dispatchers.IO) {
        try {
            val request = Request.Builder()
                .url(githubApiUrl)
                .header("Accept", "application/vnd.github.v3+json")
                .build()

            val response = client.newCall(request).execute()
            if (!response.isSuccessful) {
                return@withContext UpdateInfo(false, currentVersion, null)
            }

            val json = JSONObject(response.body?.string() ?: "")
            val tagName = json.getString("tag_name")
            val latestVersion = tagName.removePrefix("v")

            // Find APK asset
            val assets = json.getJSONArray("assets")
            var apkUrl: String? = null
            for (i in 0 until assets.length()) {
                val asset = assets.getJSONObject(i)
                if (asset.getString("name").endsWith(".apk")) {
                    apkUrl = asset.getString("browser_download_url")
                    break
                }
            }

            val hasUpdate = isNewerVersion(latestVersion, currentVersion)
            UpdateInfo(hasUpdate, latestVersion, apkUrl)
        } catch (e: Exception) {
            e.printStackTrace()
            UpdateInfo(false, currentVersion, null)
        }
    }

    private fun isNewerVersion(latest: String, current: String): Boolean {
        // Compare versions like "1.0.m1" vs "1.0.m0"
        try {
            val latestParts = latest.replace("m", ".").split(".")
            val currentParts = current.replace("m", ".").split(".")

            for (i in 0 until maxOf(latestParts.size, currentParts.size)) {
                val latestNum = latestParts.getOrNull(i)?.toIntOrNull() ?: 0
                val currentNum = currentParts.getOrNull(i)?.toIntOrNull() ?: 0
                if (latestNum > currentNum) return true
                if (latestNum < currentNum) return false
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return false
    }

    suspend fun downloadApk(url: String, onProgress: (Int) -> Unit): File? = withContext(Dispatchers.IO) {
        try {
            val request = Request.Builder().url(url).build()
            val response = client.newCall(request).execute()

            if (!response.isSuccessful) return@withContext null

            val contentLength = response.body?.contentLength() ?: 0
            val inputStream = response.body?.byteStream() ?: return@withContext null

            val downloadDir = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            val apkFile = File(downloadDir, "estelle-mobile.apk")

            FileOutputStream(apkFile).use { output ->
                val buffer = ByteArray(8192)
                var bytesRead: Int
                var totalBytesRead = 0L

                while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                    totalBytesRead += bytesRead
                    if (contentLength > 0) {
                        val progress = ((totalBytesRead * 100) / contentLength).toInt()
                        withContext(Dispatchers.Main) {
                            onProgress(progress)
                        }
                    }
                }
            }

            apkFile
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    fun installApk(apkFile: File) {
        val apkUri: Uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            apkFile
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
        }
        context.startActivity(intent)
    }
}
