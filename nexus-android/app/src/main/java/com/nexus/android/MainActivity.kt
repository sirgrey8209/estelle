package com.nexus.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.nexus.android.ui.theme.NexusAndroidTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            NexusAndroidTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    NexusScreen()
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NexusScreen(viewModel: MainViewModel = viewModel()) {
    val isConnected by viewModel.isConnected.collectAsState()
    val messages by viewModel.messages.collectAsState()
    var inputText by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    // 자동 스크롤
    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(messages.size - 1)
        }
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
            Text(
                text = "Nexus",
                style = MaterialTheme.typography.headlineMedium
            )
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = if (isConnected) "🟢" else "🔴",
                    fontSize = 16.sp
                )
                Text(
                    text = if (isConnected) "Connected" else "Disconnected",
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Connect/Disconnect buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Button(
                onClick = { viewModel.connect() },
                enabled = !isConnected,
                modifier = Modifier.weight(1f)
            ) {
                Text("Connect")
            }
            Button(
                onClick = { viewModel.disconnect() },
                enabled = isConnected,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.error
                )
            ) {
                Text("Disconnect")
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Message input
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedTextField(
                value = inputText,
                onValueChange = { inputText = it },
                modifier = Modifier.weight(1f),
                placeholder = { Text("Enter message...") },
                singleLine = true
            )
            Button(
                onClick = {
                    if (inputText.isNotBlank()) {
                        viewModel.send(inputText)
                        inputText = ""
                    }
                },
                enabled = isConnected && inputText.isNotBlank()
            ) {
                Text("Send")
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Ping button
        Button(
            onClick = { viewModel.sendPing() },
            enabled = isConnected,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Ping")
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Logs
        Text(
            text = "Logs",
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
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize()
            ) {
                items(messages) { message ->
                    Text(
                        text = message,
                        fontSize = 12.sp,
                        fontFamily = FontFamily.Monospace,
                        color = when {
                            message.contains("Connected") -> Color(0xFF4EC9B0)
                            message.contains("Disconnected") || message.contains("error") -> Color(0xFFF14C4C)
                            message.contains("Sent") -> Color(0xFF569CD6)
                            message.contains("Received") -> Color(0xFFDCDCAA)
                            else -> MaterialTheme.colorScheme.onSurfaceVariant
                        },
                        modifier = Modifier.padding(vertical = 2.dp)
                    )
                }
            }
        }
    }
}
