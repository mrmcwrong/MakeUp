package com.example.flutter_test_1

import android.os.Build
import android.os.Bundle
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		preferHighestRefreshRate()
	}

	override fun onResume() {
		super.onResume()
		// Re-assert preferred mode in case the window/display changed while paused.
		preferHighestRefreshRate()
	}

	private fun preferHighestRefreshRate() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
			return
		}

		val currentDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
			display
		} else {
			@Suppress("DEPRECATION")
			windowManager.defaultDisplay
		} ?: return
		val supportedModes = currentDisplay.supportedModes
		if (supportedModes.isEmpty()) {
			return
		}

		val bestMode = supportedModes.maxByOrNull { it.refreshRate } ?: return

		val params = window.attributes
		if (params.preferredDisplayModeId != bestMode.modeId) {
			params.preferredDisplayModeId = bestMode.modeId
			window.attributes = params
		}

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
			window.setFrameRate(
				bestMode.refreshRate,
				Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
			)
		}
	}
}
