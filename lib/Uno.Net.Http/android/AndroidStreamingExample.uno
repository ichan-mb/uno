using Uno;
using Uno.Collections;
using Uno.Text;
using Uno.Net.Http;
using Uno.Net.Http.Examples;

namespace Uno.Net.Http.Android.Examples
{
    public class AndroidStreamingExample
    {
        static HttpMessageHandler _httpMessageHandler;

        public static void Initialize()
        {
            _httpMessageHandler = new HttpMessageHandler();
        }

        // Example 1: Android-specific Server-Sent Events with AsyncTask streaming
        public static void StreamSSEEventsAndroid(string url, Action<string> onEventReceived, Action<string> onError)
        {
            if (_httpMessageHandler == null)
                Initialize();

            var request = _httpMessageHandler.CreateRequest("GET", url);

            // Configure for Android streaming using AsyncTask
            request.HttpResponseType = HttpResponseType.Stream;
            request.SetHeader("Accept", "text/event-stream");
            request.SetHeader("Cache-Control", "no-cache");
            request.SetHeader("Connection", "keep-alive");
            request.SetHeader("User-Agent", "Android-Uno-SSE/1.0");

            var buffer = new StringBuilder();

            // Set up Android streaming callback using AsyncTask data chunks
            request.SetStreamingDataCallback((data, isComplete) =>
            {
                if (isComplete)
                {
                    debug_log("Android SSE stream completed");
                    // Process any remaining buffer data
                    if (buffer.Length > 0)
                    {
                        ProcessAndroidSSEEvent(buffer.ToString(), onEventReceived);
                        buffer.Clear();
                    }
                    return;
                }

                // Convert bytes to string and process SSE data
                var chunk = Encoding.UTF8.GetString(data);
                buffer.Append(chunk);

                // Process complete SSE messages optimized for Android
                ProcessAndroidSSEBuffer(buffer, onEventReceived);
            });

            // Android-specific event handling
            request.StateChanged += (req) =>
            {
                debug_log("Android SSE State: " + req.State);
                if (req.State == HttpRequestState.HeadersReceived)
                {
                    var status = req.GetResponseStatus();
                    var contentType = req.GetResponseHeader("Content-Type");
                    var server = req.GetResponseHeader("Server");

                    if (status != 200)
                    {
                        onError("Android SSE failed with status: " + status);
                        return;
                    }

                    if (!contentType.Contains("text/event-stream"))
                    {
                        onError("Android SSE invalid content type: " + contentType);
                        return;
                    }

                    debug_log("Android SSE connection established with server: " + server);
                }
            };

            request.Progress += (req, current, total, hasTotal) =>
            {
                debug_log("Android SSE progress: " + current + " bytes received");
            };

            request.Error += (req, errorMessage) =>
            {
                onError("Android SSE error: " + errorMessage);
                debug_log("Android network state may have changed, consider reconnection");
            };

            request.SendAsync();
        }

        // Example 2: Android optimized large file download with AsyncTask
        public static void StreamLargeFileAndroid(string url, string localFilePath,
            Action<long, long> onProgress, Action<string> onError, Action onComplete)
        {
            if (_httpMessageHandler == null)
                Initialize();

            var request = _httpMessageHandler.CreateRequest("GET", url);
            request.HttpResponseType = HttpResponseType.Stream;

            // Set Android-optimized headers for file download
            request.SetHeader("Accept", "*/*");
            request.SetHeader("Accept-Encoding", "identity"); // Disable compression for streaming
            request.SetHeader("User-Agent", "Android-Uno-Downloader/1.0");
            request.SetTimeout(30000); // 30 second timeout for mobile networks

            var totalDownloaded = 0L;
            var expectedSize = 0L;
            var lastProgressTime = 0L;

            // Use Android AsyncTask-based streaming for efficient processing
            request.SetStreamingDataCallback((data, isComplete) =>
            {
                if (isComplete)
                {
                    debug_log("Android file download completed: " + totalDownloaded + " bytes");
                    onComplete();
                    return;
                }

                try
                {
                    // Simulate writing to Android file system
                    // In real implementation, would use Android file APIs
                    totalDownloaded += data.Length;

                    // Throttle progress updates for better performance on Android
                    var currentTime = DateTime.Now.Ticks / 10000; // Convert to milliseconds
                    if (currentTime - lastProgressTime > 500) // Update every 500ms
                    {
                        debug_log("Android downloaded chunk: " + data.Length + " bytes, total: " + totalDownloaded);
                        onProgress(totalDownloaded, expectedSize);
                        lastProgressTime = currentTime;
                    }
                }
                catch (Exception ex)
                {
                    onError("Android file processing error: " + ex.Message);
                }
            });

            request.StateChanged += (req) =>
            {
                if (req.State == HttpRequestState.HeadersReceived)
                {
                    var contentLengthHeader = req.GetResponseHeader("Content-Length");
                    var contentEncoding = req.GetResponseHeader("Content-Encoding");

                    if (!string.IsNullOrEmpty(contentLengthHeader))
                    {
                        long.TryParse(contentLengthHeader, out expectedSize);
                        debug_log("Android expected file size: " + expectedSize + " bytes");
                    }

                    if (!string.IsNullOrEmpty(contentEncoding))
                    {
                        debug_log("Android content encoding: " + contentEncoding);
                    }
                }
            };

            request.Error += (req, errorMessage) =>
            {
                onError("Android download failed: " + errorMessage);
            };

            request.SendAsync();
        }

        // Example 3: Android-specific JSON streaming with AsyncTask optimization
        public static void StreamJSONObjectsAndroid(string url, Action<string> onObjectReceived, Action<string> onError)
        {
            if (_httpMessageHandler == null)
                Initialize();

            var request = _httpMessageHandler.CreateRequest("GET", url);
            request.HttpResponseType = HttpResponseType.Stream;
            request.SetHeader("Accept", "application/json");
            request.SetHeader("User-Agent", "Android-Uno-JSONStream/1.0");

            var jsonBuffer = new StringBuilder();
            var braceCount = 0;
            var inString = false;
            var escapeNext = false;
            var objectStart = 0;
            var processedObjects = 0;

            request.SetStreamingDataCallback((data, isComplete) =>
            {
                if (isComplete)
                {
                    debug_log("Android JSON streaming completed. Processed " + processedObjects + " objects");
                    return;
                }

                var chunk = Encoding.UTF8.GetString(data);
                jsonBuffer.Append(chunk);

                // Efficient JSON object parsing optimized for Android AsyncTask
                var content = jsonBuffer.ToString();
                var processed = ParseAndroidJSONObjects(content, ref braceCount, ref inString,
                    ref escapeNext, ref objectStart, onObjectReceived, ref processedObjects);

                // Keep unprocessed data in buffer (memory management for Android)
                if (processed > 0)
                {
                    jsonBuffer.Clear();
                    if (processed < content.Length)
                    {
                        jsonBuffer.Append(content.Substring(processed));
                    }
                    objectStart = 0;
                }

                // Android memory management - clear large buffers periodically
                if (jsonBuffer.Length > 100000) // 100KB threshold
                {
                    debug_log("Android JSON buffer getting large, consider processing strategy");
                }
            });

            request.Error += (req, errorMessage) =>
            {
                onError("Android JSON streaming error: " + errorMessage);
            };

            request.SendAsync();
        }

        // Example 4: Android background streaming with AsyncTask lifecycle management
        public static void BackgroundStreamAndroid(string url, Action<string> onProgress, Action<string> onComplete)
        {
            if (_httpMessageHandler == null)
                Initialize();

            var request = _httpMessageHandler.CreateRequest("GET", url);
            request.HttpResponseType = HttpResponseType.Stream;

            // Configure for Android background operation
            request.SetHeader("User-Agent", "Android-Uno-Background/1.0");
            request.SetHeader("Keep-Alive", "timeout=30, max=100");

            var downloadedChunks = 0;
            var totalBytes = 0L;

            request.SetStreamingDataCallback((data, isComplete) =>
            {
                if (isComplete)
                {
                    onComplete("Android background streaming completed: " + downloadedChunks +
                              " chunks, " + totalBytes + " bytes total");
                    return;
                }

                downloadedChunks++;
                totalBytes += data.Length;

                // Process data chunk with Android AsyncTask efficiency in mind
                onProgress("Android background chunk " + downloadedChunks +
                          " (" + data.Length + " bytes) - Total: " + totalBytes);

                // Simulate Android background processing
                ProcessAndroidDataChunkInBackground(data);
            });

            request.StateChanged += (req) =>
            {
                debug_log("Android background streaming state: " + req.State);

                // Monitor Android network state changes
                if (req.State == HttpRequestState.HeadersReceived)
                {
                    var connectionType = req.GetResponseHeader("Connection");
                    debug_log("Android connection type: " + connectionType);
                }
            };

            request.SendAsync();
        }

        // Example 5: Android network-aware streaming with connection monitoring
        public static void NetworkAwareStreamingAndroid(string url, Action<string> onData, Action<string> onNetworkChange)
        {
            if (_httpMessageHandler == null)
                Initialize();

            var request = _httpMessageHandler.CreateRequest("GET", url);
            request.HttpResponseType = HttpResponseType.Stream;

            // Android network optimization headers
            request.SetHeader("Connection", "keep-alive");
            request.SetHeader("Accept-Encoding", "identity");
            request.SetTimeout(15000); // Shorter timeout for mobile

            var networkChangeDetected = false;

            request.SetStreamingDataCallback((data, isComplete) =>
            {
                if (isComplete)
                {
                    if (networkChangeDetected)
                    {
                        onNetworkChange("Stream completed after network change");
                    }
                    return;
                }

                var dataStr = Encoding.UTF8.GetString(data);
                onData("Android received: " + data.Length + " bytes");

                // Simulate Android network quality monitoring
                if (data.Length < 100) // Small chunks might indicate poor connection
                {
                    debug_log("Android detected small chunk size, possible network degradation");
                }
            });

            request.Error += (req, errorMessage) =>
            {
                if (errorMessage.Contains("network") || errorMessage.Contains("connection"))
                {
                    networkChangeDetected = true;
                    onNetworkChange("Android network error: " + errorMessage);
                }
            };

            request.SendAsync();
        }

        // Helper methods for Android-specific processing
        private static void ProcessAndroidSSEBuffer(StringBuilder buffer, Action<string> onEventReceived)
        {
            var content = buffer.ToString();
            var eventEnd = content.IndexOf("\n\n");

            while (eventEnd != -1)
            {
                var eventData = content.Substring(0, eventEnd);
                ProcessAndroidSSEEvent(eventData, onEventReceived);

                content = content.Substring(eventEnd + 2);
                eventEnd = content.IndexOf("\n\n");
            }

            // Keep remaining incomplete data (Android memory efficient)
            buffer.Clear();
            buffer.Append(content);
        }

        private static void ProcessAndroidSSEEvent(string eventData, Action<string> onEventReceived)
        {
            if (string.IsNullOrWhiteSpace(eventData))
                return;

            var lines = eventData.Split('\n');
            var data = new StringBuilder();

            foreach (var line in lines)
            {
                var trimmed = line.Trim();
                if (trimmed.StartsWith("data:"))
                {
                    var eventContent = trimmed.Substring(5).Trim();
                    if (data.Length > 0)
                        data.AppendLine();
                    data.Append(eventContent);
                }
                else if (trimmed.StartsWith("event:"))
                {
                    debug_log("Android SSE event type: " + trimmed.Substring(6).Trim());
                }
                else if (trimmed.StartsWith("id:"))
                {
                    debug_log("Android SSE event ID: " + trimmed.Substring(3).Trim());
                }
                else if (trimmed.StartsWith("retry:"))
                {
                    debug_log("Android SSE retry interval: " + trimmed.Substring(6).Trim());
                }
            }

            if (data.Length > 0)
            {
                onEventReceived(data.ToString());
            }
        }

        private static int ParseAndroidJSONObjects(string content, ref int braceCount, ref bool inString,
            ref bool escapeNext, ref int objectStart, Action<string> onObjectReceived, ref int processedObjects)
        {
            var processed = 0;

            for (int i = objectStart; i < content.Length; i++)
            {
                var c = content[i];

                if (escapeNext)
                {
                    escapeNext = false;
                    continue;
                }

                if (c == '\\')
                {
                    escapeNext = true;
                    continue;
                }

                if (c == '"')
                {
                    inString = !inString;
                    continue;
                }

                if (!inString)
                {
                    if (c == '{')
                    {
                        if (braceCount == 0)
                            objectStart = i;
                        braceCount++;
                    }
                    else if (c == '}')
                    {
                        braceCount--;
                        if (braceCount == 0)
                        {
                            // Complete JSON object found
                            var jsonObject = content.Substring(objectStart, i - objectStart + 1);
                            onObjectReceived(jsonObject);
                            processed = i + 1;
                            objectStart = 0;
                            processedObjects++;
                        }
                    }
                }
            }

            return processed;
        }

        private static void ProcessAndroidDataChunkInBackground(byte[] data)
        {
            // Android-specific background processing using AsyncTask paradigm
            // Could integrate with Android background services, WorkManager, etc.
            debug_log("Android background processing " + data.Length + " bytes via AsyncTask");
        }

        // Android-specific utility methods
        public static void ConfigureForAndroidOptimalStreaming(HttpMessageHandlerRequest request)
        {
            // Set Android-specific headers for optimal streaming performance
            request.SetHeader("Accept-Encoding", "identity"); // Disable compression for streaming
            request.SetHeader("Connection", "keep-alive");
            request.SetHeader("Keep-Alive", "timeout=30, max=1000");
            request.SetTimeout(30000); // 30 second timeout suitable for mobile networks

            // Android User-Agent with device info would be ideal
            request.SetHeader("User-Agent", "Android-Uno-Stream/1.0 (Mobile)");
        }

        public static void ConfigureForAndroidLowBandwidth(HttpMessageHandlerRequest request)
        {
            // Configuration optimized for Android devices on slow networks
            request.SetHeader("Accept-Encoding", "identity");
            request.SetTimeout(60000); // Longer timeout for slow connections
            request.SetHeader("Cache-Control", "no-cache"); // Avoid stale cache on poor connections
        }

        public static void ConfigureForAndroidWiFiOptimal(HttpMessageHandlerRequest request)
        {
            // Configuration optimized for Android devices on WiFi
            request.SetTimeout(15000); // Shorter timeout for good connections
            request.SetHeader("Accept-Encoding", "gzip, deflate"); // Allow compression on good connections
        }

        public static void RunAndroidStreamingExamples()
        {
            debug_log("Starting Android-specific streaming examples with AsyncTask support...");

            // Example usage:
            /*
            StreamSSEEventsAndroid("https://api.example.com/events",
                eventData => debug_log("Android SSE received: " + eventData),
                error => debug_log("Android SSE error: " + error));

            StreamLargeFileAndroid("https://example.com/largefile.zip", "/sdcard/download/file.zip",
                (current, total) => debug_log("Android progress: " + current + "/" + total),
                error => debug_log("Android download error: " + error),
                () => debug_log("Android download complete"));

            StreamJSONObjectsAndroid("https://api.example.com/stream",
                jsonObj => debug_log("Android JSON object: " + jsonObj),
                error => debug_log("Android JSON error: " + error));

            BackgroundStreamAndroid("https://example.com/data.json",
                progress => debug_log("Android background: " + progress),
                result => debug_log("Android result: " + result));

            NetworkAwareStreamingAndroid("https://api.example.com/realtime",
                data => debug_log("Android data: " + data),
                networkChange => debug_log("Android network: " + networkChange));
            */
        }
    }
}
