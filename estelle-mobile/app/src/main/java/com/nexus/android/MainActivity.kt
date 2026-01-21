package com.nexus.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

// 캐릭터 설정
data class Character(val name: String, val icon: String, val role: String)

val CHARACTERS = mapOf(
    "estelle" to Character("Estelle", "💫", "Relay"),
    "stella" to Character("Stella", "⭐", "회사 PC"),
    "selene" to Character("Selene", "🌙", "집 PC"),
    "lucy" to Character("Lucy", "📱", "Mobile"),
)

fun getCharacter(deviceId: String?, deviceType: String?): Character {
    val id = deviceId?.lowercase()
    CHARACTERS[id]?.let { return it }
    return when (deviceType) {
        "mobile" -> Character(deviceId ?: "Unknown", "📱", "Mobile")
        "pylon" -> Character(deviceId ?: "Unknown", "💻", "Pylon")
        "desktop" -> Character(deviceId ?: "Unknown", "🖥️", "Desktop")
        else -> Character(deviceId ?: "Unknown", "❓", deviceType ?: "")
    }
}

// 상태 아이콘
fun getStatusIcon(status: String): String = when (status) {
    "idle" -> "💤"
    "working" -> "💬"
    "permission" -> "⏳"
    "offline" -> "🔌"
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

@OptIn(ExperimentalMaterial3Api::class)
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
                    // 연결 상태
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
        // bottomBar 제거 - 스와이프로 전환
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

// ============ DeskListPage (스와이프 페이지 0) ============

@Composable
fun DeskListPage(
    viewModel: MainViewModel,
    onDeskSelected: () -> Unit
) {
    val desks by viewModel.desks.collectAsState()
    val selectedDesk by viewModel.selectedDesk.collectAsState()

    // Pylon별로 그룹화
    val pylonGroups = remember(desks) {
        desks.groupBy { it.pcName to it.pcIcon }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        // 헤더
        Text(
            "Desks",
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        if (pylonGroups.isEmpty()) {
            // 연결된 Pylon 없음
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("💫", fontSize = 48.sp)
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        "No Pylons connected",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        "← Swipe to chat",
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
                    val (pcName, pcIcon) = pylonInfo

                    // Pylon 헤더
                    item {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(pcIcon, fontSize = 24.sp)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                pcName,
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

                                // 선택 표시
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

// ============ ChatPage (스와이프 페이지 1) ============

@Composable
fun ChatPage(viewModel: MainViewModel) {
    val selectedDesk by viewModel.selectedDesk.collectAsState()
    val claudeMessages by viewModel.claudeMessages.collectAsState()
    val currentTextBuffer by viewModel.currentTextBuffer.collectAsState()
    val pendingPermission by viewModel.pendingPermission.collectAsState()
    val pendingQuestion by viewModel.pendingQuestion.collectAsState()

    var inputText by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    // 현재 데스크 메시지만 필터링
    val filteredMessages = remember(claudeMessages, selectedDesk) {
        claudeMessages.filter { it.deskId == selectedDesk?.deskId }
    }

    // 메시지 자동 스크롤
    LaunchedEffect(filteredMessages.size, currentTextBuffer) {
        if (filteredMessages.isNotEmpty()) {
            listState.animateScrollToItem(filteredMessages.size - 1)
        }
    }

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
                    Text(selectedDesk?.pcIcon ?: "💻", fontSize = 20.sp)
                    Spacer(modifier = Modifier.width(8.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            "${selectedDesk?.pcName}/${selectedDesk?.deskName}",
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp
                        )
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Text(getStatusIcon(selectedDesk?.status ?: ""), fontSize = 10.sp)
                            Text(
                                selectedDesk?.status?.uppercase() ?: "",
                                fontSize = 10.sp,
                                color = getStatusColor(selectedDesk?.status ?: "")
                            )
                        }
                    }
                    Text(
                        "← Swipe for desks",
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
                // 데스크 미선택
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text("💫", fontSize = 48.sp)
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        "Select a desk to start",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        "← Swipe left to select",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                    )
                }
            } else if (filteredMessages.isEmpty() && currentTextBuffer.isEmpty()) {
                // 메시지 없음
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(selectedDesk?.pcIcon ?: "💻", fontSize = 48.sp)
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
                    items(filteredMessages) { message ->
                        ClaudeMessageBubble(message = message, pcIcon = selectedDesk?.pcIcon ?: "💻")
                    }

                    // 스트리밍 중인 텍스트
                    if (currentTextBuffer.isNotEmpty()) {
                        item {
                            ClaudeMessageBubble(
                                message = ClaudeMessage(
                                    id = "streaming",
                                    deskId = selectedDesk?.deskId ?: "",
                                    isUser = false,
                                    content = currentTextBuffer,
                                    timestamp = System.currentTimeMillis()
                                ),
                                pcIcon = selectedDesk?.pcIcon ?: "💻",
                                isStreaming = true
                            )
                        }
                    }
                }
            }
        }

        // 권한 요청 다이얼로그
        pendingPermission?.let { perm ->
            PermissionDialog(
                permission = perm,
                onAllow = { viewModel.respondPermission("allow") },
                onDeny = { viewModel.respondPermission("deny") },
                onAllowAll = { viewModel.respondPermission("allowAll") }
            )
        }

        // 질문 다이얼로그
        pendingQuestion?.let { question ->
            QuestionDialog(
                question = question,
                onAnswer = { viewModel.respondQuestion(it) }
            )
        }

        // 컨트롤 바
        if (selectedDesk != null) {
            ClaudeControlBar(
                desk = selectedDesk!!,
                onStop = { viewModel.stopClaude() },
                onNewSession = { viewModel.newSession() }
            )
        }

        // 입력창
        ClaudeInputBar(
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

// ============ Legacy Claude Screen (참고용) ============

@Composable
fun ClaudeScreen(viewModel: MainViewModel) {
    val desks by viewModel.desks.collectAsState()
    val selectedDesk by viewModel.selectedDesk.collectAsState()
    val claudeMessages by viewModel.claudeMessages.collectAsState()
    val currentTextBuffer by viewModel.currentTextBuffer.collectAsState()
    val pendingPermission by viewModel.pendingPermission.collectAsState()
    val pendingQuestion by viewModel.pendingQuestion.collectAsState()

    var inputText by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    // 현재 데스크 메시지만 필터링
    val filteredMessages = remember(claudeMessages, selectedDesk) {
        claudeMessages.filter { it.deskId == selectedDesk?.deskId }
    }

    // 메시지 자동 스크롤
    LaunchedEffect(filteredMessages.size, currentTextBuffer) {
        if (filteredMessages.isNotEmpty()) {
            listState.animateScrollToItem(filteredMessages.size - 1)
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        // 데스크 선택 바
        DeskSelector(
            desks = desks,
            selectedDesk = selectedDesk,
            onSelectDesk = { viewModel.selectDesk(it) }
        )

        // 메시지 목록
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
        ) {
            if (selectedDesk == null) {
                // 데스크 미선택
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text("💫", fontSize = 48.sp)
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        "Select a desk to start",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else if (filteredMessages.isEmpty() && currentTextBuffer.isEmpty()) {
                // 메시지 없음
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(selectedDesk?.pcIcon ?: "💻", fontSize = 48.sp)
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        "${selectedDesk?.pcName}/${selectedDesk?.deskName}",
                        fontWeight = FontWeight.Bold
                    )
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
                    items(filteredMessages) { message ->
                        ClaudeMessageBubble(message = message, pcIcon = selectedDesk?.pcIcon ?: "💻")
                    }

                    // 스트리밍 중인 텍스트
                    if (currentTextBuffer.isNotEmpty()) {
                        item {
                            ClaudeMessageBubble(
                                message = ClaudeMessage(
                                    id = "streaming",
                                    deskId = selectedDesk?.deskId ?: "",
                                    isUser = false,
                                    content = currentTextBuffer,
                                    timestamp = System.currentTimeMillis()
                                ),
                                pcIcon = selectedDesk?.pcIcon ?: "💻",
                                isStreaming = true
                            )
                        }
                    }
                }
            }
        }

        // 권한 요청 다이얼로그
        pendingPermission?.let { perm ->
            PermissionDialog(
                permission = perm,
                onAllow = { viewModel.respondPermission("allow") },
                onDeny = { viewModel.respondPermission("deny") },
                onAllowAll = { viewModel.respondPermission("allowAll") }
            )
        }

        // 질문 다이얼로그
        pendingQuestion?.let { question ->
            QuestionDialog(
                question = question,
                onAnswer = { viewModel.respondQuestion(it) }
            )
        }

        // 컨트롤 바
        if (selectedDesk != null) {
            ClaudeControlBar(
                desk = selectedDesk!!,
                onStop = { viewModel.stopClaude() },
                onNewSession = { viewModel.newSession() }
            )
        }

        // 입력창
        ClaudeInputBar(
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

@Composable
fun DeskSelector(
    desks: List<DeskInfo>,
    selectedDesk: DeskInfo?,
    onSelectDesk: (DeskInfo) -> Unit
) {
    LazyRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(desks) { desk ->
            val isSelected = desk.deskId == selectedDesk?.deskId
            Surface(
                modifier = Modifier.clickable { onSelectDesk(desk) },
                shape = RoundedCornerShape(16.dp),
                color = if (isSelected) MaterialTheme.colorScheme.primaryContainer
                else MaterialTheme.colorScheme.surfaceVariant,
                tonalElevation = if (isSelected) 4.dp else 0.dp
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(desk.pcIcon, fontSize = 14.sp)
                    Column {
                        Text(
                            "${desk.pcName}/${desk.deskName}",
                            fontSize = 12.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Text(getStatusIcon(desk.status), fontSize = 10.sp)
                            Text(
                                desk.status,
                                fontSize = 10.sp,
                                color = getStatusColor(desk.status)
                            )
                        }
                    }
                }
            }
        }
        if (desks.isEmpty()) {
            item {
                Text(
                    "No desks available",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(8.dp)
                )
            }
        }
    }
}

@Composable
fun ClaudeMessageBubble(
    message: ClaudeMessage,
    pcIcon: String,
    isStreaming: Boolean = false
) {
    val isUser = message.isUser
    val bubbleColor = if (isUser) MaterialTheme.colorScheme.primaryContainer
    else MaterialTheme.colorScheme.surfaceVariant

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start
    ) {
        if (!isUser) {
            Text(pcIcon, fontSize = 20.sp, modifier = Modifier.padding(end = 8.dp))
        }

        Surface(
            shape = RoundedCornerShape(
                topStart = 16.dp,
                topEnd = 16.dp,
                bottomStart = if (isUser) 16.dp else 4.dp,
                bottomEnd = if (isUser) 4.dp else 16.dp
            ),
            color = bubbleColor,
            modifier = Modifier.widthIn(max = 300.dp)
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                // 툴 이벤트 표시
                message.event?.let { event ->
                    when (event) {
                        is ClaudeEvent.ToolStart -> {
                            ToolCallCard(
                                icon = "🔧",
                                title = event.toolName,
                                subtitle = formatToolInput(event.toolInput)
                            )
                        }
                        is ClaudeEvent.ToolComplete -> {
                            ToolCallCard(
                                icon = "✅",
                                title = "${event.toolName} completed",
                                subtitle = null
                            )
                        }
                        is ClaudeEvent.PermissionRequest -> {
                            ToolCallCard(
                                icon = "⚠️",
                                title = "Permission: ${event.toolName}",
                                subtitle = formatToolInput(event.toolInput)
                            )
                        }
                        is ClaudeEvent.Error -> {
                            Text(
                                "❌ ${event.error}",
                                color = Color(0xFFF14C4C)
                            )
                        }
                        else -> {
                            Text(message.content)
                        }
                    }
                } ?: run {
                    Text(message.content)
                }

                // 스트리밍 인디케이터
                if (isStreaming) {
                    Spacer(modifier = Modifier.height(4.dp))
                    LinearProgressIndicator(
                        modifier = Modifier.fillMaxWidth(),
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
        }

        if (isUser) {
            Text("📱", fontSize = 20.sp, modifier = Modifier.padding(start = 8.dp))
        }
    }
}

@Composable
fun ToolCallCard(icon: String, title: String, subtitle: String?) {
    Surface(
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 2.dp
    ) {
        Column(modifier = Modifier.padding(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(icon, fontSize = 16.sp)
                Spacer(modifier = Modifier.width(8.dp))
                Text(title, fontWeight = FontWeight.Medium, fontSize = 14.sp)
            }
            subtitle?.let {
                Text(
                    it,
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

fun formatToolInput(input: Map<String, Any?>): String {
    return input.entries.take(2).joinToString(", ") { (k, v) ->
        "$k: ${v.toString().take(30)}"
    }
}

@Composable
fun ClaudeControlBar(
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
            // 상태 표시
            Text(getStatusIcon(desk.status), fontSize = 16.sp)
            Text(
                desk.status.uppercase(),
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = getStatusColor(desk.status)
            )

            Spacer(modifier = Modifier.weight(1f))

            // Stop 버튼
            if (desk.status == "working" || desk.status == "permission") {
                FilledTonalButton(
                    onClick = onStop,
                    colors = ButtonDefaults.filledTonalButtonColors(
                        containerColor = Color(0xFFF14C4C).copy(alpha = 0.2f)
                    ),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
                ) {
                    Icon(Icons.Default.Stop, contentDescription = "Stop", modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Stop", fontSize = 12.sp)
                }
            }

            // New Session 버튼
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

@Composable
fun ClaudeInputBar(
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

@Composable
fun PermissionDialog(
    permission: ClaudeEvent.PermissionRequest,
    onAllow: () -> Unit,
    onDeny: () -> Unit,
    onAllowAll: () -> Unit
) {
    AlertDialog(
        onDismissRequest = { },
        icon = { Text("⚠️", fontSize = 32.sp) },
        title = { Text("Permission Required") },
        text = {
            Column {
                Text("Tool: ${permission.toolName}", fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant
                ) {
                    Text(
                        formatToolInput(permission.toolInput),
                        modifier = Modifier.padding(8.dp),
                        fontSize = 12.sp
                    )
                }
            }
        },
        confirmButton = {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TextButton(onClick = onDeny) {
                    Text("Deny", color = Color(0xFFF14C4C))
                }
                Button(onClick = onAllow) {
                    Text("Allow")
                }
                Button(onClick = onAllowAll) {
                    Text("Allow All")
                }
            }
        }
    )
}

@Composable
fun QuestionDialog(
    question: ClaudeEvent.AskQuestion,
    onAnswer: (String) -> Unit
) {
    var customAnswer by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = { },
        icon = { Text("❓", fontSize = 32.sp) },
        title = { Text("Question") },
        text = {
            Column {
                Text(question.question)
                Spacer(modifier = Modifier.height(16.dp))

                question.options.forEach { option ->
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onAnswer(option) },
                        shape = RoundedCornerShape(8.dp),
                        color = MaterialTheme.colorScheme.surfaceVariant
                    ) {
                        Text(
                            option,
                            modifier = Modifier.padding(12.dp)
                        )
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                }

                OutlinedTextField(
                    value = customAnswer,
                    onValueChange = { customAnswer = it },
                    label = { Text("Custom answer") },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                onClick = { onAnswer(customAnswer) },
                enabled = customAnswer.isNotBlank()
            ) {
                Text("Submit")
            }
        }
    )
}

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
                        progress = { downloadProgress / 100f },
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

// ============ Legacy Chat Screen (Phase 1) ============

@Composable
fun LegacyChatScreen(viewModel: MainViewModel) {
    val isConnected by viewModel.isConnected.collectAsState()
    val devices by viewModel.devices.collectAsState()
    val chatMessages by viewModel.chatMessages.collectAsState()

    var chatInput by remember { mutableStateOf("") }
    val chatListState = rememberLazyListState()

    LaunchedEffect(chatMessages.size) {
        if (chatMessages.isNotEmpty()) {
            chatListState.animateScrollToItem(chatMessages.size - 1)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        // Devices
        Text(
            text = "Connected Devices (${devices.size})",
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(8.dp))

        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(devices) { device ->
                val char = getCharacter(device.deviceId, device.deviceType)
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(char.icon, fontSize = 14.sp)
                        Text(char.name, fontSize = 13.sp)
                    }
                }
            }
            if (devices.isEmpty()) {
                item {
                    Text(
                        "No devices connected",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontSize = 13.sp
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Deploy button
        Button(
            onClick = { viewModel.requestDeploy() },
            enabled = isConnected && devices.any { it.deviceType == "pylon" },
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF569CD6)),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Deploy")
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
                    "No messages yet",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.align(Alignment.Center)
                )
            } else {
                LazyColumn(
                    state = chatListState,
                    modifier = Modifier.fillMaxSize()
                ) {
                    items(chatMessages) { message ->
                        val char = getCharacter(message.from, message.deviceType)
                        Row(
                            modifier = Modifier.padding(vertical = 4.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Text(message.time, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(char.icon, fontSize = 14.sp)
                            Text("${char.name}:", fontSize = 14.sp, color = Color(0xFF569CD6), fontWeight = FontWeight.Medium)
                            Text(message.message, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurface)
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

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
