using Uno;
using Uno.Collections;
using Uno.Text;
using Uno.Net.Http;
using Uno.Threading;

namespace Uno.Net.Http.Android.Test
{
    public class AndroidStreamingTest
    {
        static HttpMessageHandler _httpMessageHandler;
        static bool _testRunning = false;

        public static void Initialize()
        {
            _httpMessageHandler = new HttpMessageHandler();
            debug_log("Android Streaming Test initialized");
        }

        // Test 1: Basic Android streaming functionality
        public static void TestBasicAndroidStreaming()
        {
            if (_httpMessageHandler == null)
                Initialize();

            debug_log("=== Android Basic Streaming Test ===");

            var testUrl = "https://httpbin.org/stream/10";
            var request = _httpMessageHandler.CreateRequest("GET", testUrl);

            // Configure for Android streaming
            request.HttpResponseType = HttpResponseType.Stream;
            request.SetHeader("Accept", "application/json");
            request.SetHeader("User-Agent", "Android-Uno-Test/1.0");

            var chunksReceived = 0;
            var totalBytes = 0;
            var receivedData = new List<byte[]>();

            request.SetStreamingDataCallback((data, isComplete) =>
            {
                if (isComplete)
                {
                    debug_log("Android streaming test completed");
                    debug_log("Total chunks received: " + chunksReceived);
                    debug_log("Total bytes received: " + totalBytes);

                    // Verify we received data
                    if (chunksReceived > 0 && totalBytes > 0)
                    {
                        debug_log("✓ Android basic streaming test PASSED");
                    }
                    else
                    {
                        debug_log("✗ Android basic streaming test FAILED - No data received");
                    }
                    return;
                }

                chunksReceived++;
                totalBytes += data.Length;
                receivedData.Add(data);

                debug_log("Android chunk " + chunksReceived + ": " + data.Length + " bytes");

                // Process chunk content
                var chunkText = Encoding.UTF8.GetString(data);
                if (chunkText.Contains("{") && chunkText.Contains("}"))
                {
                    debug_log("Android received JSON chunk: " + chunkText.Substring(0, Math.Min(100, chunkText.Length)));
                }
            });

            request.StateChanged += (req) =>
            {
                debug_log("Android test state: " + req.State);
                if (req.State == HttpRequestState.HeadersReceived)
                {
                    var status = req.GetResponseStatus();
                    var contentType = req.GetResponseHeader("Content-Type");
                    debug_log("Android response status: " + status);
                    debug_log("Android content type: " + contentType);
                }
            };

            request.Error += (req, error) =>
            {
                debug_log("✗ Android streaming test ERROR: " + error);
            };

            _testRunning = true;
            request.SendAsync();
        }

        // Test 2: Android SSE streaming test
        public static void TestAndroidSSEStreaming()
        {
            if (_httpMessageHandler == null)
                Initialize();

            debug_log("=== Android SSE Streaming Test ===");

            var sseUrl = "https://httpbin.org/stream/5";
            var request = _httpMessageHandler.CreateRequest("GET", sseUrl);

            // Configure for Android SSE streaming
            request.HttpResponseType = HttpResponseType.Stream;
            request.SetHeader("Accept", "text/event-stream");
            request.SetHeader("Cache-Control", "no-cache");
            request.SetHeader("Connection", "keep-alive");
            request.SetHeader("User-Agent", "Android-Uno-SSE-Test/1.0");

            var sseBuffer = new StringBuilder();
            var eventsReceived = 0;

            request.SetStreamingDataCallback((data, isComplete) =>
            {
                if (isComplete)
                {
                    debug_log("Android SSE test completed");
                    debug_log("Total events processed: " + eventsReceived);

                    // Process any remaining buffer
                    if (sseBuffer.Length > 0)
                    {
                        ProcessAndroidSSEData(sseBuffer.ToString(), ref eventsReceived);
                    }

                    if (eventsReceived > 0)
                    {
                        debug_log("✓ Android SSE streaming test PASSED");
                    }
                    else
                    {
                        debug_log("✗ Android SSE streaming test FAILED - No events received");
                    }
                    return;
                }

                var chunk = Encoding.UTF8.GetString(data);
                sseBuffer.Append(chunk);

                // Process complete SSE messages
                ProcessAndroidSSEData(sseBuffer.ToString(), ref eventsReceived);

                // Clear processed data from buffer
                var content = sseBuffer.ToString();
                var lastEventEnd = content.LastIndexOf("\n\n");
                if (lastEventEnd != -1)
                {
                    sseBuffer.Clear();
                    sseBuffer.Append(content.Substring(lastEventEnd + 2));
                }
            });

            request.Error += (req, error) =>
            {
                debug_log("✗ Android SSE test ERROR: " + error);
            };

            request.SendAsync();
        }

        // Test 3: Android large file streaming test
        public static void TestAndroidLargeFileStreaming()
        {
            if (_httpMessageHandler == null)
                Initialize();

            debug_log("=== Android Large File Streaming Test ===");

            var fileUrl = "https://httpbin.org/bytes/50000"; // 50KB test file
            var request = _httpMessageHandler.CreateRequest("GET", fileUrl);

            // Configure for Android file streaming
            request.HttpResponseType = HttpResponseType.Stream;
            request.SetHeader("Accept", "*/*");
            request.SetHeader("Accept-Encoding", "identity");
            request.SetHeader("User-Agent", "Android-Uno-FileTest/1.0");

            var totalDownloaded = 0L;
            var expectedSize = 0L;
            var chunks = 0;

            request.SetStreamingDataCallback((data, isComplete) =>
            {
                if (isComplete)
                {
                    debug_log("Android file streaming completed");
                    debug_log("Downloaded: " + totalDownloaded + " bytes in " + chunks + " chunks");
                    debug_log("Expected: " + expectedSize + " bytes");

                    if (totalDownloaded > 0 && (expectedSize == 0 || totalDownloaded == expectedSize))
                    {
                        debug_log("✓ Android file streaming test PASSED");
                    }
                    else
                    {
                        debug_log("✗ Android file streaming test FAILED - Size mismatch");
                    }
                    return;
                }

                chunks++;
                totalDownloaded += data.Length;

                debug_log("Android file chunk " + chunks + ": " + data.Length + " bytes (total: " + totalDownloaded + ")");

                // Simulate writing to Android file system
                ProcessAndroidFileChunk(data, chunks);
            });

            request.StateChanged += (req) =>
            {
                if (req.State == HttpRequestState.HeadersReceived)
                {
                    var contentLengthHeader = req.GetResponseHeader("Content-Length");
                    if (!string.IsNullOrEmpty(contentLengthHeader))
                    {
                        long.TryParse(contentLengthHeader, out expectedSize);
                        debug_log("Android expected file size: " + expectedSize + " bytes");
                    }
                }
            };

            request.Progress += (req, current, total, hasTotal) =>
            {
                debug_log("Android download progress: " + current + "/" + (hasTotal ? total.ToString() : "unknown"));
            };

            request.Error += (req, error) =>
            {
                debug_log("✗ Android file streaming test ERROR: " + error);
            };

            request.SendAsync();
        }

        // Test 4: Android streaming vs buffered comparison
        public static void TestAndroidStreamingVsBuffered()
        {
            if (_httpMessageHandler == null)
                Initialize();

            debug_log("=== Android Streaming vs Buffered Comparison ===");

            var testUrl = "https://httpbin.org/json";

            // Test buffered approach first
            TestAndroidBufferedRequest(testUrl, () =>
            {
                // Then test streaming approach
                TestAndroidStreamingRequest(testUrl);
            });
        }

        // Test 5: Android error handling test
        public static void TestAndroidErrorHandling()
        {
            if (_httpMessageHandler == null)
                Initialize();

            debug_log("=== Android Error Handling Test ===");

            var badUrl = "https://httpbin.org/status/500";
            var request = _httpMessageHandler.CreateRequest("GET", badUrl);

            request.HttpResponseType = HttpResponseType.Stream;
            request.SetHeader("User-Agent", "Android-Uno-ErrorTest/1.0");

            var errorHandled = false;

            request.SetStreamingDataCallback((data, isComplete) =>
            {
                if (isComplete)
                {
                    debug_log("Android error test completed unexpectedly");
                    return;
                }

                debug_log("Android error test received data: " + data.Length + " bytes");
            });

            request.StateChanged += (req) =>
            {
                if (req.State == HttpRequestState.HeadersReceived)
                {
                    var status = req.GetResponseStatus();
                    debug_log("Android error test status: " + status);

                    if (status >= 400)
                    {
                        debug_log("✓ Android error handling test PASSED - Error status detected");
                        errorHandled = true;
                    }
                }
            };

            request.Error += (req, error) =>
            {
                debug_log("Android error test caught error: " + error);
                debug_log("✓ Android error handling test PASSED - Error caught");
                errorHandled = true;
            };

            request.Done += (req) =>
            {
                if (!errorHandled)
                {
                    debug_log("✗ Android error handling test FAILED - No error detected");
                }
            };

            request.SendAsync();
        }

        // Helper method for buffered request testing
        private static void TestAndroidBufferedRequest(string url, Action onComplete)
        {
            debug_log("--- Testing Android Buffered Approach ---");

            var request = _httpMessageHandler.CreateRequest("GET", url);
            request.HttpResponseType = HttpResponseType.String;

            var startTime = DateTime.Now.Ticks;

            request.Done += (req) =>
            {
                var endTime = DateTime.Now.Ticks;
                var content = req.GetResponseContentString();

                debug_log("Android buffered completed in " + ((endTime - startTime) / 10000) + "ms");
                debug_log("Android buffered content length: " + content.Length);
                debug_log("Android buffered content preview: " + content.Substring(0, Math.Min(100, content.Length)));

                onComplete();
            };

            request.Error += (req, error) =>
            {
                debug_log("Android buffered error: " + error);
                onComplete();
            };

            request.SendAsync();
        }

        // Helper method for streaming request testing
        private static void TestAndroidStreamingRequest(string url)
        {
            debug_log("--- Testing Android Streaming Approach ---");

            var request = _httpMessageHandler.CreateRequest("GET", url);
            request.HttpResponseType = HttpResponseType.Stream;

            var startTime = DateTime.Now.Ticks;
            var firstChunkTime = 0L;
            var content = new StringBuilder();
            var chunks = 0;

            request.SetStreamingDataCallback((data, isComplete) =>
            {
                if (isComplete)
                {
                    var endTime = DateTime.Now.Ticks;
                    debug_log("Android streaming completed in " + ((endTime - startTime) / 10000) + "ms");
                    debug_log("Android streaming first chunk in " + ((firstChunkTime - startTime) / 10000) + "ms");
                    debug_log("Android streaming total chunks: " + chunks);
                    debug_log("Android streaming content length: " + content.Length);
                    debug_log("Android streaming content preview: " + content.ToString().Substring(0, Math.Min(100, content.Length)));

                    // Compare with buffered approach
                    debug_log("✓ Android streaming vs buffered comparison completed");
                    return;
                }

                chunks++;
                if (firstChunkTime == 0)
                {
                    firstChunkTime = DateTime.Now.Ticks;
                }

                var chunkText = Encoding.UTF8.GetString(data);
                content.Append(chunkText);

                debug_log("Android streaming chunk " + chunks + ": " + data.Length + " bytes");
            });

            request.Error += (req, error) =>
            {
                debug_log("Android streaming error: " + error);
            };

            request.SendAsync();
        }

        // Helper method to process SSE data
        private static void ProcessAndroidSSEData(string data, ref int eventsReceived)
        {
            if (string.IsNullOrWhiteSpace(data))
                return;

            var events = data.Split(new string[] { "\n\n" }, StringSplitOptions.RemoveEmptyEntries);

            foreach (var eventData in events)
            {
                if (eventData.Contains("data:"))
                {
                    eventsReceived++;
                    debug_log("Android SSE event " + eventsReceived + ": " + eventData.Substring(0, Math.Min(50, eventData.Length)));
                }
            }
        }

        // Helper method to process file chunks
        private static void ProcessAndroidFileChunk(byte[] data, int chunkNumber)
        {
            // Simulate Android file processing
            debug_log("Android processing file chunk " + chunkNumber + " (" + data.Length + " bytes)");

            // In real implementation, would write to Android file system
            // using Android.OS.Environment.getExternalStorageDirectory() etc.
        }

        // Run all Android streaming tests
        public static void RunAllAndroidTests()
        {
            debug_log("Starting comprehensive Android streaming tests...");

            // Test basic streaming
            TestBasicAndroidStreaming();

            // Wait a bit between tests
            var timer1 = Timer.Create(3000, false, () =>
            {
                TestAndroidSSEStreaming();

                var timer2 = Timer.Create(3000, false, () =>
                {
                    TestAndroidLargeFileStreaming();

                    var timer3 = Timer.Create(3000, false, () =>
                    {
                        TestAndroidStreamingVsBuffered();

                        var timer4 = Timer.Create(5000, false, () =>
                        {
                            TestAndroidErrorHandling();

                            var timer5 = Timer.Create(3000, false, () =>
                            {
                                debug_log("All Android streaming tests completed!");
                            });
                        });
                    });
                });
            });
        }

        // Quick test for development
        public static void QuickAndroidTest()
        {
            debug_log("Running quick Android streaming test...");
            TestBasicAndroidStreaming();
        }

        public static bool IsTestRunning
        {
            get { return _testRunning; }
        }

        public static void StopTests()
        {
            _testRunning = false;
            debug_log("Android streaming tests stopped");
        }
    }
}
