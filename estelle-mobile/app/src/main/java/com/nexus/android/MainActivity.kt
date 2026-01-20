package com.nexus.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.nexus.android.ui.theme.EstelleMobileTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            EstelleMobileTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    EstelleScreen()
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EstelleScreen(viewModel: MainViewModel = viewModel()) {
    val isConnected by viewModel.isConnected.collectAsState()
    val devices by viewModel.devices.collectAsState()
    val chatMessages by viewModel.chatMessages.collectAsState()
    val updateInfo by viewModel.updateInfo.collectAsState()
    val downloadProgress by viewModel.downloadProgress.collectAsState()

    var chatInput by remember { mutableStateOf("") }
    var showUpdateDialog by remember { mutableStateOf(false) }
    val chatListState = rememberLazyListState()

    // 자동 연결
    LaunchedEffect(Unit) {
        viewModel.connect()
    }

    // 채팅 자동 스크롤
    LaunchedEffect(chatMessages.size) {
        if (chatMessages.isNotEmpty()) {
            chatListState.animateScrollToItem(chatMessages.size - 1)
        }
    }

    // 업데이트 다이얼로그
    LaunchedEffect(updateInfo) {
        if (updateInfo?.hasUpdate == true) {
            showUpdateDialog = true
        }
    }

    // 업데이트 다이얼로그
    if (showUpdateDialog && updateInfo?.hasUpdate == true) {
        AlertDialog(
            onDismissRequest = { showUpdateDialog = false },
            title = { Text("Update Available") },
            text = {
                Column {
                    Text("A new version is available: v${updateInfo?.latestVersion}")
                    Text("Current version: v${BuildConfig.VERSION_NAME}", color = Color.Gray)
                    if (downloadProgress >= 0) {
                        Spacer(modifier = Modifier.height(16.dp))
                        LinearProgressIndicator(
                            progress = downloadProgress / 100f,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Text("Downloading: $downloadProgress%", fontSize = 12.sp)
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        updateInfo?.downloadUrl?.let { url ->
                            viewModel.downloadAndInstall(url)
                        }
                    },
                    enabled = downloadProgress < 0
                ) {
                    Text(if (downloadProgress >= 0) "Downloading..." else "Update")
                }
            },
            dismissButton = {
                TextButton(onClick = { showUpdateDialog = false }) {
                    Text("Later")
                }
            }
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "Estelle Mobile",
                    style = MaterialTheme.typography.headlineMedium
                )
                Text(
                    text = "v${BuildConfig.VERSION_NAME}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // Deploy 버튼
                Button(
                    onClick = { viewModel.requestDeploy() },
                    enabled = isConnected && devices.any { it.deviceType == "pylon" },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF569CD6)
                    ),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
                ) {
                    Text("Deploy", fontSize = 13.sp)
                }
                Text(
                    text = if (isConnected) "ON" else "OFF",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (isConnected) Color(0xFF4EC9B0) else Color(0xFFF14C4C)
                )
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .background(
                            color = if (isConnected) Color(0xFF4EC9B0) else Color(0xFFF14C4C),
                            shape = RoundedCornerShape(6.dp)
                        )
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Devices
        Text(
            text = "Connected Devices (${devices.size})",
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(8.dp))

        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(devices) { device ->
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            text = when (device.deviceType) {
                                "pylon" -> "\uD83D\uDCBB"
                                "mobile" -> "\uD83D\uDCF1"
                                "desktop" -> "\uD83D\uDDA5"
                                else -> "❓"
                            },
                            fontSize = 14.sp
                        )
                        Text(
                            text = device.deviceId,
                            fontSize = 13.sp
                        )
                    }
                }
            }
            if (devices.isEmpty()) {
                item {
                    Text(
                        text = "No devices connected",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontSize = 13.sp
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Chat
        Text(
            text = "Chat",
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(8.dp))

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .background(
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    shape = RoundedCornerShape(8.dp)
                )
                .padding(8.dp)
        ) {
            if (chatMessages.isEmpty()) {
                Text(
                    text = "No messages yet",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.align(Alignment.Center)
                )
            } else {
                LazyColumn(
                    state = chatListState,
                    modifier = Modifier.fillMaxSize()
                ) {
                    items(chatMessages) { message ->
                        Row(
                            modifier = Modifier.padding(vertical = 4.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Text(
                                text = message.time,
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = "${message.from}:",
                                fontSize = 14.sp,
                                color = Color(0xFF569CD6),
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                text = message.message,
                                fontSize = 14.sp,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Chat input
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedTextField(
                value = chatInput,
                onValueChange = { chatInput = it },
                modifier = Modifier.weight(1f),
                placeholder = { Text("Type a message...") },
                singleLine = true,
                enabled = isConnected
            )
            Button(
                onClick = {
                    if (chatInput.isNotBlank()) {
                        viewModel.sendChat(chatInput)
                        chatInput = ""
                    }
                },
                enabled = isConnected && chatInput.isNotBlank()
            ) {
                Text("Send")
            }
        }
    }
}
