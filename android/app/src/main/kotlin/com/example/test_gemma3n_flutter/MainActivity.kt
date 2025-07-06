package com.example.test_gemma3n_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.app.ActivityManager
import android.os.StatFs
import android.os.Environment
import kotlinx.coroutines.*
import java.io.File
import java.io.FileOutputStream
import java.net.URL
import javax.net.ssl.HttpsURLConnection

class MainActivity: FlutterActivity() {
    private val AI_EDGE_CHANNEL = "ai_edge_gemma"
    private val DOWNLOAD_CHANNEL = "gemma_download"
    private var isModelInitialized = false
    private var modelPath: String? = null
    private var downloadJob: Job? = null
    private var downloadProgress = 0.0
    private var isDownloading = false

    private val aiEdgeScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AI_EDGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> initializeAIEdge(
                    call.argument("modelPath"),
                    call.argument("modelType"),
                    call.argument("maxTokens") ?: 512,
                    call.argument("temperature") ?: 0.7,
                    call.argument("numThreads") ?: 4,
                    result
                )
                "generateText" -> {
                    val prompt = call.argument<String>("prompt")
                    if (prompt != null) generateText(prompt, result)
                    else result.success(mapOf("success" to false, "error" to "Prompt is null"))
                }
                "getMemoryUsage" -> getMemoryUsage(result)
                "getDiskSpace" -> getDiskSpace(result)
                "getSystemInfo" -> getSystemInfo(result)
                "dispose" -> {
                    disposeAIEdge()
                    result.success(mapOf("success" to true))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadModel" -> {
                    val url = call.argument<String>("url")
                    val filePath = call.argument<String>("filePath")
                    if (url != null && filePath != null) downloadModel(url, filePath, result)
                    else result.success(mapOf("success" to false, "error" to "URL or file path is null"))
                }
                "getDownloadProgress" -> result.success(mapOf("isDownloading" to isDownloading, "progress" to downloadProgress))
                "cancelDownload" -> {
                    cancelDownload()
                    result.success(mapOf("success" to true))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun downloadModel(url: String, filePath: String, result: MethodChannel.Result) {
        if (isDownloading) {
            result.success(mapOf("success" to false, "error" to "Download already in progress"))
            return
        }

        downloadJob = aiEdgeScope.launch {
            try {
                isDownloading = true
                downloadProgress = 0.0
                val file = File(filePath)
                file.parentFile?.mkdirs()

                val connection = URL(url).openConnection() as HttpsURLConnection
                connection.requestMethod = "GET"
                val token = BuildConfig.HUGGINGFACE_TOKEN
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.connect()

                if (connection.responseCode != HttpsURLConnection.HTTP_OK) {
                    withContext(Dispatchers.Main) {
                        result.success(mapOf("success" to false, "error" to "Server error: ${connection.responseCode}"))
                    }
                    return@launch
                }

                val contentLength = connection.contentLength
                val inputStream = connection.inputStream
                val outputStream = FileOutputStream(file)
                val buffer = ByteArray(8192)
                var totalBytes = 0L
                var bytesRead: Int

                while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                    if (!isActive) break
                    outputStream.write(buffer, 0, bytesRead)
                    totalBytes += bytesRead
                    if (contentLength > 0) downloadProgress = totalBytes.toDouble() / contentLength
                }

                outputStream.close()
                inputStream.close()
                connection.disconnect()

                isDownloading = false
                downloadProgress = 1.0

                if (isActive) {
                    withContext(Dispatchers.Main) {
                        result.success(mapOf("success" to true, "filePath" to filePath, "sizeBytes" to totalBytes))
                    }
                }
            } catch (e: Exception) {
                isDownloading = false
                downloadProgress = 0.0
                withContext(Dispatchers.Main) {
                    result.success(mapOf("success" to false, "error" to "Download failed: ${e.message}"))
                }
            }
        }
    }

    private fun cancelDownload() {
        downloadJob?.cancel()
        isDownloading = false
        downloadProgress = 0.0
    }

    private fun initializeAIEdge(modelPath: String?, modelType: String?, maxTokens: Int, temperature: Double, numThreads: Int, result: MethodChannel.Result) {
        aiEdgeScope.launch {
            try {
                val modelFile = File(modelPath ?: return@launch)
                if (!modelFile.exists()) {
                    withContext(Dispatchers.Main) {
                        result.success(mapOf("success" to false, "error" to "Model file not found at $modelPath"))
                    }
                    return@launch
                }

                val modelSizeMB = modelFile.length() / (1024 * 1024)
                if (modelSizeMB < 900) {
                    withContext(Dispatchers.Main) {
                        result.success(mapOf("success" to false, "error" to "Model file too small: ${modelSizeMB}MB"))
                    }
                    return@launch
                }

                delay(3000) // Simulate loading
                this@MainActivity.modelPath = modelPath
                isModelInitialized = true

                withContext(Dispatchers.Main) {
                    result.success(mapOf("success" to true, "modelInfo" to mapOf(
                        "modelType" to (modelType ?: "gemma-3n-e4b"),
                        "modelSizeMB" to modelSizeMB,
                        "maxTokens" to maxTokens,
                        "temperature" to temperature,
                        "numThreads" to numThreads,
                        "deviceOptimized" to true
                    )))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.success(mapOf("success" to false, "error" to "Initialization failed: ${e.message}"))
                }
            }
        }
    }

    private fun generateText(prompt: String, result: MethodChannel.Result) {
        if (!isModelInitialized) {
            result.success(mapOf("success" to false, "error" to "Model not initialized"))
            return
        }
        aiEdgeScope.launch {
            try {
                val startTime = System.currentTimeMillis()
                delay(maxOf(1500, prompt.length * 30).toLong()) // More realistic timing
                
                // Enhanced mock responses based on prompt analysis
                val response = generateMockResponse(prompt)
                val endTime = System.currentTimeMillis()
                val inferenceTime = endTime - startTime
                val tokensPerSecond = (response.split(" ").size * 1000.0 / inferenceTime).toInt()
                
                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "success" to true, 
                        "text" to response, 
                        "inferenceTimeMs" to inferenceTime,
                        "tokensPerSecond" to tokensPerSecond,
                        "modelType" to "Gemma 3n E4B"
                    ))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.success(mapOf("success" to false, "error" to "Generation failed: ${e.message}"))
                }
            }
        }
    }
    
    private fun generateMockResponse(prompt: String): String {
        val lowerPrompt = prompt.lowercase()
        
        return when {
            // Lesson analysis responses
            lowerPrompt.contains("analyze") && lowerPrompt.contains("transcript") -> {
                "Based on your lesson transcript, I can identify several key learning points:\n\n" +
                "• Clear explanation structure with good examples\n" +
                "• Opportunities to add more interactive elements\n" +
                "• Consider breaking complex concepts into smaller steps\n" +
                "• Overall delivery pace seems appropriate for learners\n\n" +
                "Would you like me to suggest specific improvements for any particular section?"
            }
            
            // Educational questions
            lowerPrompt.contains("explain") || lowerPrompt.contains("what is") -> {
                "Let me explain this concept step by step:\n\n" +
                "1. First, let's establish the foundation - ${extractTopic(prompt)}\n" +
                "2. The key principle here is understanding the relationship between components\n" +
                "3. This applies in real-world scenarios when you encounter similar problems\n\n" +
                "Would you like me to provide a specific example or dive deeper into any aspect?"
            }
            
            // Programming questions
            lowerPrompt.contains("code") || lowerPrompt.contains("program") || lowerPrompt.contains("function") -> {
                "Here's how to approach this programming concept:\n\n" +
                "```\n// Example implementation\nfunction example() {\n    // Key logic here\n    return result;\n}\n```\n\n" +
                "Key considerations:\n• Error handling\n• Performance optimization\n• Code readability\n\n" +
                "Try implementing this step by step and let me know if you need clarification!"
            }
            
            // Math questions
            lowerPrompt.contains("math") || lowerPrompt.contains("calculate") || lowerPrompt.contains("solve") -> {
                "Let's solve this step by step:\n\n" +
                "Step 1: Identify what we're looking for\n" +
                "Step 2: Apply the appropriate formula or method\n" +
                "Step 3: Work through the calculation\n" +
                "Step 4: Verify our answer makes sense\n\n" +
                "Mathematical reasoning is about understanding the 'why' behind each step. Would you like me to explain the underlying principle?"
            }
            
            // Learning/study questions
            lowerPrompt.contains("learn") || lowerPrompt.contains("study") || lowerPrompt.contains("understand") -> {
                "Great question about learning! Here's my educational approach:\n\n" +
                "🎯 Focus on understanding core concepts first\n" +
                "📚 Build knowledge progressively from basics to advanced\n" +
                "🔄 Practice with varied examples to reinforce learning\n" +
                "💡 Connect new information to what you already know\n\n" +
                "Active learning works best - try explaining concepts back to me or asking follow-up questions!"
            }
            
            // Science questions
            lowerPrompt.contains("science") || lowerPrompt.contains("physics") || lowerPrompt.contains("chemistry") -> {
                "In science, we use systematic observation and analysis:\n\n" +
                "Hypothesis: Based on your question about ${extractTopic(prompt)}\n" +
                "Evidence: Scientific principles show us that...\n" +
                "Application: This applies to real-world situations because...\n" +
                "Conclusion: The key takeaway for understanding this concept\n\n" +
                "Science is about curiosity and questioning - what aspect interests you most?"
            }
            
            // General educational response
            else -> {
                "I understand you're asking about ${extractTopic(prompt)}. As your AI tutor, let me help you explore this topic:\n\n" +
                "📖 This concept connects to broader learning themes\n" +
                "🔍 Let's examine the key components and relationships\n" +
                "💭 Consider how this applies to your current studies\n" +
                "🎓 Building understanding requires both theory and practice\n\n" +
                "What specific aspect would you like to explore further? I'm here to guide your learning journey!"
            }
        }
    }
    
    private fun extractTopic(prompt: String): String {
        // Simple topic extraction - get the main subject
        val words = prompt.split(" ").filter { it.length > 3 }
        return if (words.isNotEmpty()) words.take(3).joinToString(" ") else "this topic"
    }

    private fun getMemoryUsage(result: MethodChannel.Result) {
        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)
            val totalMB = memoryInfo.totalMem / (1024 * 1024)
            val availableMB = memoryInfo.availMem / (1024 * 1024)
            val usedMB = totalMB - availableMB
            result.success(mapOf("totalMB" to totalMB, "availableMB" to availableMB, "usedMB" to usedMB))
        } catch (e: Exception) {
            result.success(mapOf("totalMB" to 0, "availableMB" to 0, "usedMB" to 0, "error" to e.message))
        }
    }

    private fun getDiskSpace(result: MethodChannel.Result) {
        try {
            val stat = StatFs(Environment.getDataDirectory().path)
            val total = stat.totalBytes
            val available = stat.availableBytes
            val used = total - available
            val percent = (available.toDouble() / total) * 100
            result.success(mapOf("totalGB" to total / 1e9, "availableGB" to available / 1e9, "usedGB" to used / 1e9, "freeSpacePercent" to percent))
        } catch (e: Exception) {
            result.success(mapOf("error" to e.message))
        }
    }

    private fun getSystemInfo(result: MethodChannel.Result) {
        try {
            val config = (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).deviceConfigurationInfo
            result.success(mapOf("isInitialized" to isModelInitialized, "modelPath" to modelPath, "deviceInfo" to mapOf(
                "cpuArchitecture" to System.getProperty("os.arch"),
                "androidVersion" to android.os.Build.VERSION.RELEASE,
                "apiLevel" to android.os.Build.VERSION.SDK_INT,
                "manufacturer" to android.os.Build.MANUFACTURER,
                "model" to android.os.Build.MODEL,
                "hasGPU" to (config.reqGlEsVersion >= 0x30000),
                "glEsVersion" to config.glEsVersion
            )))
        } catch (e: Exception) {
            result.success(mapOf("isInitialized" to isModelInitialized, "error" to e.message))
        }
    }

    private fun disposeAIEdge() {
        isModelInitialized = false
        modelPath = null
        cancelDownload()
    }

    override fun onDestroy() {
        super.onDestroy()
        aiEdgeScope.cancel()
        disposeAIEdge()
    }
}