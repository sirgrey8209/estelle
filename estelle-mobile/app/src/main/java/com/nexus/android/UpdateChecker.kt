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
    private val deployJsonUrl = "https://github.com/sirgrey8209/estelle/releases/download/deploy/deploy.json"
    private val apkUrl = "https://github.com/sirgrey8209/estelle/releases/download/deploy/estelle-mobile.apk"
    private val currentVersion = BuildConfig.VERSION_NAME

    data class UpdateInfo(
        val hasUpdate: Boolean,
        val latestVersion: String,
        val downloadUrl: String?,
        val deployInfo: DeployInfo? = null
    )

    data class DeployInfo(
        val commit: String,
        val deployedAt: String,
        val relay: String,
        val pylon: String,
        val desktop: String,
        val mobile: String
    )

    suspend fun checkForUpdate(): UpdateInfo = withContext(Dispatchers.IO) {
        try {
            // deploy.json 가져오기
            val request = Request.Builder()
                .url("$deployJsonUrl?t=${System.currentTimeMillis()}")
                .build()

            val response = client.newCall(request).execute()
            if (!response.isSuccessful) {
                return@withContext UpdateInfo(false, currentVersion, null)
            }

            val json = JSONObject(response.body?.string() ?: "")
            val deployInfo = DeployInfo(
                commit = json.optString("commit", ""),
                deployedAt = json.optString("deployedAt", ""),
                relay = json.optString("relay", ""),
                pylon = json.optString("pylon", ""),
                desktop = json.optString("desktop", ""),
                mobile = json.optString("mobile", "")
            )

            val latestVersion = deployInfo.mobile
            val hasUpdate = isNewerVersion(latestVersion, currentVersion)

            UpdateInfo(
                hasUpdate = hasUpdate,
                latestVersion = latestVersion,
                downloadUrl = if (hasUpdate) apkUrl else null,
                deployInfo = deployInfo
            )
        } catch (e: Exception) {
            e.printStackTrace()
            UpdateInfo(false, currentVersion, null)
        }
    }

    private fun isNewerVersion(latest: String, current: String): Boolean {
        // 시간코드 포함 버전 비교: "1.0.m1-0120" vs "1.0.m0"
        try {
            // 기본 버전과 시간코드 분리
            val latestParts = latest.split("-")
            val currentParts = current.split("-")

            val latestBase = latestParts[0]
            val currentBase = currentParts[0]

            // 기본 버전 비교 (1.0.m1 vs 1.0.m0)
            val latestNums = latestBase.replace("m", ".").split(".").mapNotNull { it.toIntOrNull() }
            val currentNums = currentBase.replace("m", ".").split(".").mapNotNull { it.toIntOrNull() }

            for (i in 0 until maxOf(latestNums.size, currentNums.size)) {
                val latestNum = latestNums.getOrElse(i) { 0 }
                val currentNum = currentNums.getOrElse(i) { 0 }
                if (latestNum > currentNum) return true
                if (latestNum < currentNum) return false
            }

            // 기본 버전이 같으면 시간코드 비교
            val latestTimeCode = latestParts.getOrElse(1) { "0" }
            val currentTimeCode = currentParts.getOrElse(1) { "0" }

            return latestTimeCode > currentTimeCode
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
