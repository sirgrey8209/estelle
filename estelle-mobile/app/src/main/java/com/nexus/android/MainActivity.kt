package com.nexus.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.nexus.android.ui.theme.EstelleMobileTheme
import kotlinx.coroutines.launch

// 상태 아이콘/색상
fun getStatusIcon(status: String): String = when (status) {
    "idle" -> "\uD83D\uDCA4"
    "working" -> "\uD83D\uDCAC"
    "permission" -> "⏳"
    "offline" -> "\uD83D\uDD0C"
    else -> "❓"
}

fun getStatusColor(status: String): Color = when (status) {
    "idle" -> Color(0xFF4EC9B0)
    "working" -> Color(0xFF569CD6)
    "permission" -> Color(0xFFDCDCAA)
    "offline" -> Color(0xFFF14C4C)
    else -> Color.Gray
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            EstelleMobileTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    EstelleApp()
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun EstelleApp(viewModel: MainViewModel = viewModel()) {
    val pagerState = rememberPagerState(initialPage = 0, pageCount = { 2 })
    val coroutineScope = rememberCoroutineScope()

    val isConnected by viewModel.isConnected.collectAsState()
    val updateInfo by viewModel.updateInfo.collectAsState()
    val downloadProgress by viewModel.downloadProgress.collectAsState()
    var showUpdateDialog by remember { mutableStateOf(false) }

    // 자동 연결
    LaunchedEffect(Unit) {
        viewModel.connect()
    }

    // 업데이트 다이얼로그
    LaunchedEffect(updateInfo) {
        if (updateInfo?.hasUpdate == true) {
            showUpdateDialog = true
        }
    }

    if (showUpdateDialog && updateInfo?.hasUpdate == true) {
        UpdateDialog(
            updateInfo = updateInfo,
            downloadProgress = downloadProgress,
            onUpdate = { url -> viewModel.downloadAndInstall(url) },
            onDismiss = { showUpdateDialog = false }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Estelle", fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            "v${BuildConfig.VERSION_NAME}",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                },
                actions = {
                    Box(
                        modifier = Modifier
                            .padding(end = 16.dp)
                            .background(
                                color = if (isConnected) Color(0xFF4EC9B0) else Color(0xFFF14C4C),
                                shape = RoundedCornerShape(8.dp)
                            )
                            .padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = if (isConnected) "ON" else "OFF",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                }
            )
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
            // 페이지 인디케이터
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                horizontalArrangement = Arrangement.Center
            ) {
                repeat(2) { index ->
                    Box(
                        modifier = Modifier
                            .padding(horizontal = 4.dp)
                            .size(8.dp)
                            .background(
                                color = if (pagerState.currentPage == index)
                                    MaterialTheme.colorScheme.primary
                                else
                                    MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f),
                                shape = RoundedCornerShape(4.dp)
                            )
                    )
                }
            }

            // 스와이프 페이저
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.fillMaxSize()
            ) { page ->
                when (page) {
                    0 -> DeskListPage(
                        viewModel = viewModel,
                        onDeskSelected = {
                            coroutineScope.launch {
                                pagerState.animateScrollToPage(1)
                            }
                        }
                    )
                    1 -> ChatPage(viewModel = viewModel)
                }
            }
        }
    }
}

// ============ DeskListPage (페이지 0) ============

@Composable
fun DeskListPage(
    viewModel: MainViewModel,
    onDeskSelected: () -> Unit
) {
    val desks by viewModel.allDesks.collectAsState()
    val selectedDesk by viewModel.selectedDesk.collectAsState()

    // Pylon별로 그룹화
    val pylonGroups = remember(desks) {
        desks.groupBy { it.deviceName to it.deviceIcon }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Text(
            "Desks",
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        if (pylonGroups.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("\uD83D\uDCAB", fontSize = 48.sp)
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        "No Pylons connected",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        "Swipe right for chat \u2192",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                    )
                }
            }
        } else {
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                pylonGroups.forEach { (pylonInfo, pylonDesks) ->
                    val (deviceName, deviceIcon) = pylonInfo

                    // Pylon 헤더
                    item {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(deviceIcon, fontSize = 24.sp)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                deviceName,
                                fontSize = 18.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }

                    // 데스크 목록
                    items(pylonDesks) { desk ->
                        val isSelected = desk.deskId == selectedDesk?.deskId
                        Surface(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    viewModel.selectDesk(desk)
                                    onDeskSelected()
                                },
                            shape = RoundedCornerShape(12.dp),
                            color = if (isSelected) MaterialTheme.colorScheme.primaryContainer
                            else MaterialTheme.colorScheme.surfaceVariant,
                            tonalElevation = if (isSelected) 4.dp else 0.dp
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column {
                                    Text(
                                        desk.deskName,
                                        fontWeight = FontWeight.Medium,
                                        fontSize = 16.sp
                                    )
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                                    ) {
                                        Text(getStatusIcon(desk.status), fontSize = 12.sp)
                                        Text(
                                            desk.status,
                                            fontSize = 12.sp,
                                            color = getStatusColor(desk.status)
                                        )
                                    }
                                }
                                if (isSelected) {
                                    Icon(
                                        Icons.Default.Check,
                                        contentDescription = "Selected",
                                        tint = MaterialTheme.colorScheme.primary
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// ============ ChatPage (페이지 1) ============

@Composable
fun ChatPage(viewModel: MainViewModel) {
    val selectedDesk by viewModel.selectedDesk.collectAsState()
    val claudeMessages by viewModel.claudeMessages.collectAsState()
    val currentTextBuffer by viewModel.currentTextBuffer.collectAsState()
    val pendingRequests by viewModel.pendingRequests.collectAsState()

    var inputText by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    // 메시지 자동 스크롤
    LaunchedEffect(claudeMessages.size, currentTextBuffer) {
        if (claudeMessages.isNotEmpty()) {
            listState.animateScrollToItem(claudeMessages.size - 1)
        }
    }

    val currentRequest = pendingRequests.firstOrNull()

    Column(modifier = Modifier.fillMaxSize()) {
        // 현재 데스크 헤더
        if (selectedDesk != null) {
            Surface(
                modifier = Modifier.fillMaxWidth(),
                tonalElevation = 2.dp
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(selectedDesk?.deviceIcon ?: "\uD83D\uDCBB", fontSize = 20.sp)
                    Spacer(modifier = Modifier.width(8.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            selectedDesk?.fullName ?: "",
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp
                        )
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Text(getStatusIcon(selectedDesk?.status ?: ""), fontSize = 10.sp)
                            Text(
                                (selectedDesk?.status ?: "").uppercase(),
                                fontSize = 10.sp,
                                color = getStatusColor(selectedDesk?.status ?: "")
                            )
                        }
                    }
                    Text(
                        "\u2190 Swipe for desks",
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                    )
                }
            }
        }

        // 메시지 목록
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
        ) {
            if (selectedDesk == null) {
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text("\uD83D\uDCAB", fontSize = 48.sp)
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        "Select a desk to start",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        "\u2190 Swipe left to select",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                    )
                }
            } else if (claudeMessages.isEmpty() && currentTextBuffer.isEmpty()) {
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(selectedDesk?.deviceIcon ?: "\uD83D\uDCBB", fontSize = 48.sp)
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        "Start a conversation",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    contentPadding = PaddingValues(vertical = 8.dp)
                ) {
                    items(claudeMessages, key = { it.id }) { message ->
                        MessageBubble(message = message, pcIcon = selectedDesk?.deviceIcon ?: "\uD83D\uDCBB")
                    }

                    // 스트리밍 중인 텍스트
                    if (currentTextBuffer.isNotEmpty()) {
                        item {
                            StreamingBubble(
                                content = currentTextBuffer,
                                pcIcon = selectedDesk?.deviceIcon ?: "\uD83D\uDCBB"
                            )
                        }
                    }
                }
            }
        }

        // 권한/질문 요청
        currentRequest?.let { request ->
            RequestBar(
                request = request,
                onPermissionResponse = { viewModel.respondPermission(it) },
                onQuestionResponse = { viewModel.respondQuestion(it) }
            )
        }

        // 컨트롤 바
        if (selectedDesk != null && currentRequest == null) {
            ControlBar(
                desk = selectedDesk!!,
                onStop = { viewModel.stopClaude() },
                onNewSession = { viewModel.newSession() }
            )
        }

        // 입력창
        if (currentRequest == null) {
            InputBar(
                value = inputText,
                onValueChange = { inputText = it },
                onSend = {
                    if (inputText.isNotBlank() && selectedDesk != null) {
                        viewModel.sendToSelectedDesk(inputText)
                        inputText = ""
                    }
                },
                enabled = selectedDesk != null && selectedDesk?.status != "offline"
            )
        }
    }
}

// ============ 메시지 버블 ============

@Composable
fun MessageBubble(message: ClaudeMessage, pcIcon: String) {
    when (message) {
        is ClaudeMessage.UserText -> {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                Surface(
                    shape = RoundedCornerShape(16.dp, 16.dp, 4.dp, 16.dp),
                    color = MaterialTheme.colorScheme.primaryContainer,
                    modifier = Modifier.widthIn(max = 300.dp)
                ) {
                    Text(
                        message.content,
                        modifier = Modifier.padding(12.dp)
                    )
                }
                Text("\uD83D\uDCF1", fontSize = 20.sp, modifier = Modifier.padding(start = 8.dp))
            }
        }
        is ClaudeMessage.AssistantText -> {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Start
            ) {
                Text(pcIcon, fontSize = 20.sp, modifier = Modifier.padding(end = 8.dp))
                Surface(
                    shape = RoundedCornerShape(16.dp, 16.dp, 16.dp, 4.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    modifier = Modifier.widthIn(max = 300.dp)
                ) {
                    Text(
                        message.content,
                        modifier = Modifier.padding(12.dp)
                    )
                }
            }
        }
        is ClaudeMessage.ToolCall -> {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Start
            ) {
                Text(pcIcon, fontSize = 20.sp, modifier = Modifier.padding(end = 8.dp))
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.surface,
                    tonalElevation = 2.dp
                ) {
                    Column(modifier = Modifier.padding(8.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                if (message.isComplete) {
                                    if (message.success == true) "\u2705" else "\u274C"
                                } else "\u23F3",
                                fontSize = 14.sp
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                message.toolName,
                                fontWeight = FontWeight.Medium,
                                fontSize = 14.sp
                            )
                        }
                        // 간단한 입력 표시
                        val inputPreview = message.toolInput.entries.take(1)
                            .joinToString { "${it.key}: ${it.value.toString().take(30)}" }
                        if (inputPreview.isNotEmpty()) {
                            Text(
                                inputPreview,
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                        if (!message.isComplete) {
                            Spacer(modifier = Modifier.height(4.dp))
                            LinearProgressIndicator(
                                modifier = Modifier.fillMaxWidth(),
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                }
            }
        }
        is ClaudeMessage.ResultInfo -> {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                val totalTokens = message.inputTokens + message.outputTokens
                val durationSec = message.durationMs / 1000.0
                Text(
                    "${"%.1f".format(durationSec)}s \u00B7 $totalTokens tokens",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        is ClaudeMessage.ErrorMessage -> {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Start
            ) {
                Text("\u26A0\uFE0F", fontSize = 20.sp, modifier = Modifier.padding(end = 8.dp))
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = Color(0xFFF14C4C).copy(alpha = 0.2f)
                ) {
                    Text(
                        message.error,
                        modifier = Modifier.padding(12.dp),
                        color = Color(0xFFF14C4C)
                    )
                }
            }
        }
        is ClaudeMessage.UserResponse -> {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = MaterialTheme.colorScheme.secondaryContainer
                ) {
                    Text(
                        message.content,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                        fontSize = 12.sp
                    )
                }
            }
        }
    }
}

@Composable
fun StreamingBubble(content: String, pcIcon: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Start
    ) {
        Text(pcIcon, fontSize = 20.sp, modifier = Modifier.padding(end = 8.dp))
        Surface(
            shape = RoundedCornerShape(16.dp, 16.dp, 16.dp, 4.dp),
            color = MaterialTheme.colorScheme.surfaceVariant,
            modifier = Modifier.widthIn(max = 300.dp)
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Text(content)
                Spacer(modifier = Modifier.height(4.dp))
                LinearProgressIndicator(
                    modifier = Modifier.fillMaxWidth(),
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}

// ============ 요청 바 (권한/질문) ============

@Composable
fun RequestBar(
    request: PendingRequest,
    onPermissionResponse: (String) -> Unit,
    onQuestionResponse: (String) -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        tonalElevation = 4.dp,
        color = MaterialTheme.colorScheme.secondaryContainer
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            when (request) {
                is PendingRequest.Permission -> {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("\u26A0\uFE0F", fontSize = 20.sp)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Permission: ${request.toolName}", fontWeight = FontWeight.Bold)
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = { onPermissionResponse("deny") },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Deny", color = Color(0xFFF14C4C))
                        }
                        Button(
                            onClick = { onPermissionResponse("allow") },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Allow")
                        }
                    }
                }
                is PendingRequest.Question -> {
                    val question = request.questions.firstOrNull()
                    if (question != null) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("\u2753", fontSize = 20.sp)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(question.header, fontWeight = FontWeight.Bold)
                        }
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(question.question, fontSize = 14.sp)
                        Spacer(modifier = Modifier.height(12.dp))

                        // 선택지 버튼
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            items(question.options) { option ->
                                OutlinedButton(
                                    onClick = { onQuestionResponse(option) }
                                ) {
                                    Text(option, maxLines = 1)
                                }
                            }
                        }

                        // 커스텀 입력
                        var customAnswer by remember { mutableStateOf("") }
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            OutlinedTextField(
                                value = customAnswer,
                                onValueChange = { customAnswer = it },
                                modifier = Modifier.weight(1f),
                                placeholder = { Text("Or type...") },
                                singleLine = true
                            )
                            Button(
                                onClick = {
                                    if (customAnswer.isNotBlank()) {
                                        onQuestionResponse(customAnswer)
                                    }
                                },
                                enabled = customAnswer.isNotBlank()
                            ) {
                                Text("Send")
                            }
                        }
                    }
                }
            }
        }
    }
}

// ============ 컨트롤 바 ============

@Composable
fun ControlBar(
    desk: DeskInfo,
    onStop: () -> Unit,
    onNewSession: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        tonalElevation = 2.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(getStatusIcon(desk.status), fontSize = 16.sp)
            Text(
                desk.status.uppercase(),
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = getStatusColor(desk.status)
            )

            Spacer(modifier = Modifier.weight(1f))

            if (desk.status == "working" || desk.status == "permission") {
                FilledTonalButton(
                    onClick = onStop,
                    colors = ButtonDefaults.filledTonalButtonColors(
                        containerColor = Color(0xFFF14C4C).copy(alpha = 0.2f)
                    ),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
                ) {
                    Icon(Icons.Default.Close, contentDescription = "Stop", modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Stop", fontSize = 12.sp)
                }
            }

            FilledTonalButton(
                onClick = onNewSession,
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
            ) {
                Icon(Icons.Default.Refresh, contentDescription = "New", modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("New", fontSize = 12.sp)
            }
        }
    }
}

// ============ 입력 바 ============

@Composable
fun InputBar(
    value: String,
    onValueChange: (String) -> Unit,
    onSend: () -> Unit,
    enabled: Boolean
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        tonalElevation = 4.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedTextField(
                value = value,
                onValueChange = onValueChange,
                modifier = Modifier.weight(1f),
                placeholder = { Text("Message to Claude...") },
                singleLine = false,
                maxLines = 4,
                enabled = enabled
            )
            FilledIconButton(
                onClick = onSend,
                enabled = enabled && value.isNotBlank()
            ) {
                Icon(Icons.Default.Send, contentDescription = "Send")
            }
        }
    }
}

// ============ 업데이트 다이얼로그 ============

@Composable
fun UpdateDialog(
    updateInfo: UpdateChecker.UpdateInfo?,
    downloadProgress: Int,
    onUpdate: (String) -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
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
                onClick = { updateInfo?.downloadUrl?.let { onUpdate(it) } },
                enabled = downloadProgress < 0
            ) {
                Text(if (downloadProgress >= 0) "Downloading..." else "Update")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Later")
            }
        }
    )
}
