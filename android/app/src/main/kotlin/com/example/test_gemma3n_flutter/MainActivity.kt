package com.example.test_gemma3n_flutter

import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import kotlin.random.Random

class MainActivity : FlutterActivity() {
    private val mainScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    companion object {
        private const val TAG = "MainActivity"
        private const val AI_EDGE_CHANNEL = "ai_edge_gemma"
        private const val GEMMA_DOWNLOAD_CHANNEL = "gemma_download"
        private const val REQUEST_PERMISSIONS = 1001

        // Model configuration
        private const val MODEL_FILENAME = "gemma-3n-E4B-it-int4.litertlm"
        private const val MODEL_URL = "https://huggingface.co/google/gemma-3n-E4B-it-litert-lm-preview/resolve/main/gemma-3n-E4B-it-int4.litertlm"
        
        // HuggingFace authentication - Add your token here
        private const val HUGGINGFACE_TOKEN = "your_huggingface_token_here"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Permission handling moved to Flutter side using permission_handler
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // AI Edge Gemma Channel - Real LiteRT-LM Integration
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AI_EDGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> handleInitialize(call, result)
                    "generateText" -> handleGenerateText(call, result)
                    "getMemoryUsage" -> handleGetMemoryUsage(result)
                    "getDiskSpace" -> handleGetDiskSpace(result)
                    "getSystemInfo" -> handleGetSystemInfo(result)
                    "dispose" -> handleDispose(result)
                    else -> result.notImplemented()
                }
            }

        // Gemma Download Channel - Model Management
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GEMMA_DOWNLOAD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isModelDownloaded" -> handleIsModelDownloaded(result)
                    "downloadModel" -> handleDownloadModel(result)
                    "getDownloadProgress" -> handleGetDownloadProgress(result)
                    "cancelDownload" -> handleCancelDownload(result)
                    else -> result.notImplemented()
                }
            }
    }


    // ==================== AI EDGE GEMMA METHODS ====================

    private fun handleInitialize(call: MethodCall, result: Result) {
        mainScope.launch {
            try {
                Log.i(TAG, "🚀 Initializing Gemma 3n E4B with LiteRT-LM...")

                // Get model path (default or from Flutter)
                // Use Flutter's getApplicationDocumentsDirectory() path which maps to app_flutter
                val modelPath = call.argument<String>("modelPath")
                    ?: "${applicationContext.filesDir.parent}/app_flutter/$MODEL_FILENAME"

                // Get optional parameters
                val useGPU = call.argument<Boolean>("useGPU") ?: false
                val maxTokens = call.argument<Int>("maxTokens") ?: 2048

                Log.i(TAG, "Model path: $modelPath")
                Log.i(TAG, "Use GPU: $useGPU")
                Log.i(TAG, "Max tokens: $maxTokens")

                // Initialize model with LiteRT-LM
                val success = GemmaLiteRunner.initModel(
                    context = applicationContext,
                    modelPath = modelPath,
                    useGPU = useGPU,
                    maxTokens = maxTokens
                )

                if (success) {
                    Log.i(TAG, "✅ Gemma 3n model initialized successfully")
                    result.success(mapOf(
                        "success" to true,
                        "message" to "Gemma 3n E4B model initialized with LiteRT-LM",
                        "modelPath" to modelPath,
                        "backend" to if (useGPU) "GPU" else "CPU"
                    ))
                } else {
                    Log.e(TAG, "❌ Failed to initialize Gemma 3n model")
                    result.error("INIT_ERROR", "Failed to initialize Gemma 3n model", null)
                }

            } catch (e: Exception) {
                Log.e(TAG, "❌ Exception during model initialization", e)
                result.error("INIT_EXCEPTION", "Model initialization failed: ${e.message}", null)
            }
        }
    }

    private fun handleGenerateText(call: MethodCall, result: Result) {
        mainScope.launch {
            try {
                val prompt = call.argument<String>("prompt") ?: call.arguments as? String ?: ""
                val temperature = call.argument<Double>("temperature") ?: 0.8
                val topK = call.argument<Int>("topK") ?: 40
                val topP = call.argument<Double>("topP") ?: 0.95

                if (prompt.isBlank()) {
                    result.error("EMPTY_PROMPT", "Prompt cannot be empty", null)
                    return@launch
                }

                Log.i(TAG, "🤖 Generating text with Gemma 3n...")
                Log.d(TAG, "Prompt: ${prompt.take(100)}...")
                Log.d(TAG, "Parameters - Temperature: $temperature, TopK: $topK, TopP: $topP")

                // Generate text using LiteRT-LM
                val generatedText = GemmaLiteRunner.generateText(
                    prompt = prompt,
                    temperature = temperature,
                    topK = topK,
                    topP = topP
                )

                Log.i(TAG, "✅ Text generation completed (${generatedText.length} chars)")
                Log.d(TAG, "Generated: ${generatedText.take(100)}...")

                result.success(generatedText)

            } catch (e: Exception) {
                Log.e(TAG, "❌ Text generation failed", e)
                result.error("GENERATION_ERROR", "Text generation failed: ${e.message}", null)
            }
        }
    }

    private fun handleGetMemoryUsage(result: Result) {
        try {
            val memoryInfo = GemmaLiteRunner.getMemoryUsage()
            result.success(memoryInfo)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting memory usage", e)
            result.error("MEMORY_ERROR", "Failed to get memory usage: ${e.message}", null)
        }
    }

    private fun handleGetDiskSpace(result: Result) {
        try {
            val filesDir = applicationContext.filesDir
            val totalSpace = filesDir.totalSpace / (1024 * 1024) // MB
            val freeSpace = filesDir.freeSpace / (1024 * 1024) // MB
            val usedSpace = totalSpace - freeSpace

            val diskInfo = mapOf(
                "totalSpaceMB" to totalSpace,
                "freeSpaceMB" to freeSpace,
                "usedSpaceMB" to usedSpace
            )

            result.success(diskInfo)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting disk space", e)
            result.error("DISK_ERROR", "Failed to get disk space: ${e.message}", null)
        }
    }

    private fun handleGetSystemInfo(result: Result) {
        try {
            val systemInfo = mapOf(
                "deviceModel" to Build.MODEL,
                "deviceManufacturer" to Build.MANUFACTURER,
                "androidVersion" to Build.VERSION.RELEASE,
                "apiLevel" to Build.VERSION.SDK_INT,
                "cpuArchitecture" to Build.SUPPORTED_ABIS.joinToString(","),
                "timestamp" to SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date()),
                "modelReady" to GemmaLiteRunner.isModelReady()
            )

            result.success(systemInfo)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting system info", e)
            result.error("SYSTEM_ERROR", "Failed to get system info: ${e.message}", null)
        }
    }

    private fun handleDispose(result: Result) {
        try {
            GemmaLiteRunner.dispose()
            Log.i(TAG, "🗑️ Gemma model disposed")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error disposing model", e)
            result.error("DISPOSE_ERROR", "Failed to dispose model: ${e.message}", null)
        }
    }

    // ==================== MODEL DOWNLOAD METHODS ====================

    private fun handleIsModelDownloaded(result: Result) {
        try {
            val modelPath = "${applicationContext.filesDir.parent}/app_flutter/$MODEL_FILENAME"
            val modelFile = File(modelPath)
            val isDownloaded = modelFile.exists() && modelFile.length() > 1_000_000_000L // > 1GB

            Log.i(TAG, "Model downloaded check: $isDownloaded (${modelFile.length()} bytes)")

            result.success(mapOf(
                "isDownloaded" to isDownloaded,
                "filePath" to modelPath,
                "fileSize" to modelFile.length()
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Error checking model download status", e)
            result.error("CHECK_ERROR", "Failed to check model status: ${e.message}", null)
        }
    }

    private fun handleDownloadModel(result: Result) {
        mainScope.launch {
            try {
                val modelPath = "${applicationContext.filesDir.parent}/app_flutter/$MODEL_FILENAME"
                val modelFile = File(modelPath)
                
                // Check if already downloaded
                if (modelFile.exists() && modelFile.length() > 1_000_000_000L) {
                    Log.i(TAG, "Model already downloaded")
                    result.success(mapOf(
                        "success" to true,
                        "message" to "Model already downloaded",
                        "filePath" to modelPath
                    ))
                    return@launch
                }
                
                Log.i(TAG, "📥 Starting model download from HuggingFace...")
                
                // Create directory if it doesn't exist
                modelFile.parentFile?.mkdirs()
                
                // Download the model file
                val downloadSuccess = downloadFileFromUrl(MODEL_URL, modelPath)
                
                if (downloadSuccess) {
                    Log.i(TAG, "✅ Model download completed successfully")
                    result.success(mapOf(
                        "success" to true,
                        "message" to "Model download completed",
                        "filePath" to modelPath
                    ))
                } else {
                    Log.e(TAG, "❌ Model download failed")
                    result.error("DOWNLOAD_ERROR", "Model download failed", null)
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "❌ Exception during model download", e)
                result.error("DOWNLOAD_EXCEPTION", "Download failed: ${e.message}", null)
            }
        }
    }

    private fun handleGetDownloadProgress(result: Result) {
        // Mock progress response
        val progress = Random.nextInt(0, 101)
        result.success(mapOf(
            "progress" to progress,
            "downloadedBytes" to (progress * 42_000_000L), // Mock bytes
            "totalBytes" to 4_200_000_000L // ~4.2GB
        ))
    }

    private fun handleCancelDownload(result: Result) {
        Log.i(TAG, "❌ Download cancelled (mock)")
        result.success(true)
    }

    private suspend fun downloadFileFromUrl(urlString: String, outputPath: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                Log.i(TAG, "Starting download from: $urlString")
                Log.i(TAG, "Output path: $outputPath")
                
                val url = URL(urlString)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 30000
                connection.readTimeout = 30000
                connection.setRequestProperty("User-Agent", "Mozilla/5.0 (Android)")
                
                // Add HuggingFace authentication if token is provided
                if (HUGGINGFACE_TOKEN != "YOUR_HUGGINGFACE_TOKEN_HERE") {
                    connection.setRequestProperty("Authorization", "Bearer $HUGGINGFACE_TOKEN")
                }
                
                connection.connect()
                
                if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                    val contentLength = connection.contentLength
                    Log.i(TAG, "Content length: $contentLength bytes")
                    
                    val inputStream = connection.inputStream
                    val outputFile = File(outputPath)
                    val outputStream = FileOutputStream(outputFile)
                    
                    val buffer = ByteArray(8192)
                    var totalBytesRead = 0L
                    var bytesRead: Int
                    
                    while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                        outputStream.write(buffer, 0, bytesRead)
                        totalBytesRead += bytesRead
                        
                        if (contentLength > 0) {
                            val progress = (totalBytesRead * 100 / contentLength.toLong()).toInt()
                            if (totalBytesRead % (contentLength.toLong() / 10) == 0L) {
                                Log.i(TAG, "Download progress: $progress%")
                            }
                        }
                    }
                    
                    outputStream.close()
                    inputStream.close()
                    connection.disconnect()
                    
                    Log.i(TAG, "Download completed: $totalBytesRead bytes")
                    true
                } else {
                    Log.e(TAG, "HTTP error: ${connection.responseCode}")
                    false
                }
            } catch (e: Exception) {
                Log.e(TAG, "Download error: ${e.message}", e)
                false
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up resources
        GemmaLiteRunner.dispose()
        mainScope.cancel()
    }
}