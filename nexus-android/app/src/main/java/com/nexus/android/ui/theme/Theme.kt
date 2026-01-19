package com.nexus.android.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val DarkColorScheme = darkColorScheme(
    primary = Color(0xFF0078D4),
    secondary = Color(0xFF404040),
    tertiary = Color(0xFF4EC9B0),
    background = Color(0xFF1E1E1E),
    surface = Color(0xFF2D2D2D),
    surfaceVariant = Color(0xFF2D2D2D),
    onPrimary = Color.White,
    onSecondary = Color.White,
    onTertiary = Color.White,
    onBackground = Color(0xFFE0E0E0),
    onSurface = Color(0xFFE0E0E0),
    onSurfaceVariant = Color(0xFFA0A0A0),
)

private val LightColorScheme = lightColorScheme(
    primary = Color(0xFF0078D4),
    secondary = Color(0xFFE0E0E0),
    tertiary = Color(0xFF4EC9B0),
    background = Color(0xFFFFFBFE),
    surface = Color(0xFFFFFBFE),
    onPrimary = Color.White,
    onSecondary = Color(0xFF1E1E1E),
    onTertiary = Color.White,
    onBackground = Color(0xFF1E1E1E),
    onSurface = Color(0xFF1E1E1E),
)

@Composable
fun NexusAndroidTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    val view = LocalView.current

    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.background.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        content = content
    )
}
