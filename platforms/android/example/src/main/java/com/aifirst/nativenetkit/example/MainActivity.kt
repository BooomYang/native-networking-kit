package com.aifirst.nativenetkit.example

import android.app.Activity
import android.os.Bundle
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import com.aifirst.nativenetkit.NativeNetClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class MainActivity : Activity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val client = NativeNetClient()

    private lateinit var urlInput: EditText
    private lateinit var resultText: TextView
    private lateinit var button: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        urlInput = EditText(this).apply {
            setText("https://example.com")
            setSingleLine(true)
        }
        button = Button(this).apply {
            text = "GET"
            setOnClickListener { fetch() }
        }
        resultText = TextView(this).apply {
            text = "Ready"
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 32, 32, 32)
            addView(urlInput, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            addView(button, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            addView(resultText, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        }

        setContentView(layout)
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private fun fetch() {
        val url = urlInput.text.toString()
        button.isEnabled = false
        resultText.text = "Requesting..."

        scope.launch {
            try {
                val response = client.get(url)
                resultText.text = "Status: ${response.statusCode}\nBytes: ${response.body.size}\nElapsed: ${response.elapsedMilliseconds ?: -1} ms"
            } catch (error: Throwable) {
                resultText.text = "Error: ${error.message ?: error::class.java.simpleName}"
            } finally {
                button.isEnabled = true
            }
        }
    }
}
