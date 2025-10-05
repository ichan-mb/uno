#include <uno.h>

#include <@{Uno.Action<byte[], bool>:include}>
#include <@{Uno.Byte:include}>
#include <@{Uno.Net.Http.HttpMessageHandlerRequest:include}>
#include <@{Uno.Net.Http.HttpResponseType:include}>
#include <@{Uno.String:include}>

#include <Foundation/Foundation.h>

#include "HttpRequest.h"

// Custom NSURLSessionDataDelegate for streaming support
@interface StreamingDelegate : NSObject <NSURLSessionDataDelegate>
@property(nonatomic, assign) Uno::Net::Http::iOS::HttpRequest *httpRequest;
@property(nonatomic, strong) NSURLSessionDataTask *dataTask;
- (instancetype)initWithHttpRequest:(Uno::Net::Http::iOS::HttpRequest *)request;
@end

@implementation StreamingDelegate

- (instancetype)initWithHttpRequest:
    (Uno::Net::Http::iOS::HttpRequest *)request {
  self = [super init];
  if (self) {
    _httpRequest = request;
    _dataTask = nil;
  }
  return self;
}

- (void)URLSession:(NSURLSession *)session
              dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:
         (void (^)(NSURLSessionResponseDisposition))completionHandler {

  if (_httpRequest) {
    Uno::Net::Http::iOS::HttpRequest::Private(_httpRequest)
        .ReceivedResponse((NSHTTPURLResponse *)response);
  }
  completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {

  if (_httpRequest) {
    Uno::Net::Http::iOS::HttpRequest::Private(_httpRequest).ReceivedData(data);
  }
}

- (void)URLSession:(NSURLSession *)session
                dataTask:(NSURLSessionDataTask *)dataTask
    didCompleteWithError:(NSError *)error {

  if (error) {
    NSLog(@"  - error description: %@", error.localizedDescription);
  }

  if (_httpRequest) {
    // Get the response from the data task
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)dataTask.response;
    Uno::Net::Http::iOS::HttpRequest::Private(_httpRequest)
        .Completed(nil, response, error);
  }
}

@end

namespace Uno {
namespace Net {
namespace Http {
namespace iOS {

namespace {

NSString *uString2NSString(uString *str) {
  if (str == nullptr)
    return nil;

  return [NSString stringWithCharacters:(const unichar *)str->_ptr
                                 length:str->_length];
}

uString *NSString2uString(NSString *str) {
  if (str == nil)
    return nullptr;

  NSUInteger length = str.length;

  uString *result = uString::New((int)length);
  [str getCharacters:(unichar *)result->_ptr range:(NSRange){0, length}];

  return result;
}

} // namespace

static NSURLCache *sharedCache = nil;
static NSURLSession *sharedSession = nil;

void SetupSharedCache(bool isCacheEnabled, size_t sizeInBytes) {
  sharedCache = nil;
  sharedSession = nil;

  if (isCacheEnabled && sizeInBytes == 0)
    return;

  if (isCacheEnabled) {
    sharedCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024
                                                diskCapacity:sizeInBytes
                                                    diskPath:@"UnoCache"];
  }

  NSURLSessionConfiguration *config =
      [NSURLSessionConfiguration defaultSessionConfiguration];
  config.URLCache = sharedCache;

  sharedSession = [NSURLSession sessionWithConfiguration:config];
}

void PurgeSharedCache() {
  NSURLCache *cache = sharedCache;
  if (!cache)
    cache = [NSURLCache sharedURLCache];

  [cache removeAllCachedResponses];
}

HttpRequest::Private::Private(const HttpRequest *r)
    : this_(const_cast<HttpRequest *>(r)) {}

NSMutableURLRequest *HttpRequest::Private::request() const {
  if (![this_->requestTaskOrResponse_
          isKindOfClass:[NSMutableURLRequest class]])
    return nil;
  return (NSMutableURLRequest *)this_->requestTaskOrResponse_;
}

NSURLSessionDataTask *HttpRequest::Private::task() const {
  if ([this_->requestTaskOrResponse_ isKindOfClass:[NSURLSessionDataTask class]]) {
    return (NSURLSessionDataTask *)this_->requestTaskOrResponse_;
  }

  // Check if it's a StreamingDelegate with a dataTask
  if ([this_->streamingDelegate_ isKindOfClass:[StreamingDelegate class]]) {
    StreamingDelegate *delegate = (StreamingDelegate *)this_->streamingDelegate_;
    return delegate.dataTask;
  }

  return nil;
}

NSHTTPURLResponse *HttpRequest::Private::response() const {
  if (![this_->requestTaskOrResponse_ isKindOfClass:[NSHTTPURLResponse class]])
    return nil;
  return (NSHTTPURLResponse *)this_->requestTaskOrResponse_;
}

void HttpRequest::Private::ReceivedData(NSData *data) {
  if (this_->responseType_ == @{Uno.Net.Http.HttpResponseType.Stream} &&
      this_->streamingDataCallback_ && data && data.length > 0) {
    uAutoReleasePool pool;

    // Validate data bounds
    NSUInteger dataLength = data.length;
    if (dataLength > INT_MAX) {
      return;
    }

    const void *dataBytes = data.bytes;
    if (!dataBytes) {
      return;
    }

    // Log first few bytes for debugging
    if (dataLength > 0) {
      const char *bytes = (const char *)dataBytes;
    }

    // Convert NSData to byte array with bounds checking
    uArray *dataArray = nullptr;
    try {
      dataArray = uArray::New(
          @{byte : typeof} -> Array(), (int)dataLength, dataBytes);

      if (dataArray) {
        // Only use event-based streaming mechanism to avoid duplicates
        // The callback will be invoked through the StreamingData event handler
        try {
          uAutoReleasePool pool;
          @{Uno.Net.Http.HttpMessageHandlerRequest:of(this_->unoRequest_).OnStreamingData(byte[], bool):call(dataArray, false)};
        } catch (const std::exception &e) {
          NSLog(@"❌ C++ Exception during streaming event: %s", e.what());
        } catch (...) {
          NSLog(@"❌ Unknown exception during streaming event");
        }
      }
    } catch (const std::exception &e) {
      NSLog(@"❌ C++ Exception during array creation: %s", e.what());
    } catch (...) {
      NSLog(@"❌ Unknown exception during array creation");
    }
  }
}

void HttpRequest::Private::ReceivedResponse(NSHTTPURLResponse *response) {
  this_->requestTaskOrResponse_ = response;
  uAutoReleasePool pool;
  @{Uno.Net.Http.HttpMessageHandlerRequest:of(this_->unoRequest_).OnHeadersReceived():call()};
}

void HttpRequest::Private::Completed(NSData *data, NSHTTPURLResponse *response,
                                     NSError *error) {
  this_->requestTaskOrResponse_ = response;

  uAutoReleasePool pool;

  if (data && data.length) {
    switch (this_->responseType_) {
    case @{Uno.Net.Http.HttpResponseType.String}: // String
      this_->responseContent_ =
          uString::Utf8((const char *)data.bytes, (int)data.length);
      break;

    case @{Uno.Net.Http.HttpResponseType.ByteArray}: // ByteArray
      this_->responseContent_ = uArray::New(
          @{byte : typeof} -> Array(), (int)data.length, data.bytes);
      break;

    case @{Uno.Net.Http.HttpResponseType.Stream}: // Stream
      // For streaming, data is already handled in ReceivedData callback
      // Don't process data here
      break;

    default:
      break;
    }
  }

  // Send stream completion signal for streaming responses
  // This must be outside the data check since streaming data is handled
  // incrementally
  if (this_->responseType_ == @{Uno.Net.Http.HttpResponseType.Stream} &&
      this_->streamingDataCallback_) {
    try {
      uArray *emptyArray = uArray::New(@{byte:typeof}->Array(), 0);
      if (emptyArray) {
        // Signal stream completion with empty data and isComplete=true
        try {
          uAutoReleasePool pool;
          @{Uno.Net.Http.HttpMessageHandlerRequest:of(this_->unoRequest_).OnStreamingData(byte[], bool):call(emptyArray, true)};
        } catch (const std::exception &e) {
          NSLog(@"❌ C++ Exception during stream completion event: %s", e.what());
        } catch (...) {
          NSLog(@"❌ Unknown exception during stream completion event");
        }
      }
    } catch (const std::exception &e) {
      NSLog(@"❌ C++ Exception creating empty array for stream completion: %s", e.what());
    } catch (...) {
      // Handle any exceptions during completion callback
      NSLog(@"❌ Unknown exception creating empty array for stream completion");
    }
  }

  if (error) {
    if (error.code == NSURLErrorTimedOut &&
        [error.domain isEqualToString:NSURLErrorDomain]) {
      @{Uno.Net.Http.HttpMessageHandlerRequest:of(this_->unoRequest_).OnTimeout():call()};
    } else {
      uString *message = NSString2uString(error.localizedDescription);
      @{Uno.Net.Http.HttpMessageHandlerRequest:of(this_->unoRequest_).OnError(string):call(message)};
    }
  } else {
    @{Uno.Net.Http.HttpMessageHandlerRequest:of(this_->unoRequest_).OnDone():call()};
  }
}

void HttpRequest::Private::Abort() {
  [task() cancel];

  uAutoReleasePool pool;
  @{Uno.Net.Http.HttpMessageHandlerRequest:of(this_->unoRequest_).OnAborted():call()};
}

HttpRequest::HttpRequest(@{Uno.Net.Http.HttpMessageHandlerRequest} unoRequest,
                         uString *method, uString *url)
    : unoRequest_(unoRequest), requestTaskOrResponse_(nil),
      responseType_(@{Uno.Net.Http.HttpResponseType.ByteArray}),
      streamingDataCallback_(nullptr), streamingBuffer_(nullptr), streamingDelegate_(nil) {
  NSMutableURLRequest *request = [[NSMutableURLRequest alloc]
      initWithURL:[NSURL URLWithString:uString2NSString(url)]];
  request.HTTPMethod = uString2NSString(method);

  requestTaskOrResponse_ = request;
}

void HttpRequest::SetTimeout(int ms) {
  Private(this).request().timeoutInterval = ms / 1000.0;
}

void HttpRequest::SetCacheEnabled(bool isCacheEnabled) {
  Private(this).request().cachePolicy =
      isCacheEnabled ? NSURLRequestUseProtocolCachePolicy
                     : NSURLRequestReloadIgnoringLocalCacheData;
}

void HttpRequest::SetHeader(uString *key, uString *value) {
  NSString *headerField = uString2NSString(key);
  NSString *headerContent = uString2NSString(value);

  if ([@"Range" caseInsensitiveCompare:headerField]) {
    // Caching is broken for HTTP Range requests
    SetCacheEnabled(false);
  }

  [Private(this).request() addValue:headerContent
                 forHTTPHeaderField:headerField];
}

void HttpRequest::SendAsync(uString *content) {
  uCString data(content);
  SendAsync(data.Ptr, data.Length);
}

void HttpRequest::SendAsync(const void *data, size_t length) {
  if (data && length) {
    Private(this).request().HTTPBody = [NSData dataWithBytes:data
                                                      length:length];
  }

  NSURLSession *session = sharedSession;
  if (!session)
    session = [NSURLSession sharedSession];

  if (responseType_ == @{Uno.Net.Http.HttpResponseType.Stream} &&
      streamingDataCallback_) {
    // Use delegate-based session for streaming
    NSURLSessionConfiguration *config =
        [NSURLSessionConfiguration defaultSessionConfiguration];
    if (sharedCache)
      config.URLCache = sharedCache;

    // Create a custom delegate class for streaming
    StreamingDelegate *delegate =
        [[StreamingDelegate alloc] initWithHttpRequest:this];

    // Keep a strong reference to the delegate to prevent deallocation
    streamingDelegate_ = delegate;

    NSURLSession *streamingSession =
        [NSURLSession sessionWithConfiguration:config
                                      delegate:delegate
                                 delegateQueue:[NSOperationQueue mainQueue]];

    NSURLSessionDataTask *task =
        [streamingSession dataTaskWithRequest:Private(this).request()];

    // Store the task in a different property to avoid overwriting the delegate reference
    delegate.dataTask = task;

    [task resume];

  } else {
    // Use completion handler for buffered responses
    NSURLSessionDataTask *task = [session
        dataTaskWithRequest:Private(this).request()
          completionHandler:^void(NSData *d, NSURLResponse *r, NSError *e) {
            dispatch_async(dispatch_get_main_queue(), ^{
              Private(this).Completed(d, (NSHTTPURLResponse *)r, e);
            });
          }];

    requestTaskOrResponse_ = task;
    [task resume];
  }
}

void HttpRequest::Abort() {
  // Cancel the task before aborting
  NSURLSessionDataTask *task = Private(this).task();
  if (task) {
    [task cancel];
  }
  Private(this).Abort();
}

int HttpRequest::GetResponseStatus() const {
  return (int)Private(this).response().statusCode;
}

uString *HttpRequest::GetResponseHeader(uString *key) const {
  NSString *value = [Private(this).response().allHeaderFields
      objectForKey:uString2NSString(key)];
  return NSString2uString(value);
}

uString *HttpRequest::GetResponseHeaders() const {
  NSDictionary *headers = Private(this).response().allHeaderFields;

  __block size_t resultLength = 0;
  [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj,
                                               BOOL *stop) {
    resultLength = resultLength + key.length + obj.length + 2;
  }];

  if (resultLength == 0)
    return nullptr;

  uString *result = uString::New((int)(resultLength - 1));
  __block char16_t *ptr = result->_ptr;
  char16_t *ptrEnd = result->_ptr + result->_length;

  [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj,
                                               BOOL *stop) {
    assert(ptrEnd > ptr);

    NSUInteger keyLength = key.length;
    assert(ptrEnd - ptr > keyLength);

    [key getCharacters:(unichar *)ptr range:(NSRange){0, keyLength}];
    ptr += keyLength;

    *ptr++ = (char16_t)':';

    NSUInteger objLength = obj.length;
    assert(ptrEnd - ptr >= objLength);

    [obj getCharacters:(unichar *)ptr range:(NSRange){0, objLength}];
    ptr += objLength;

    // NOTE: Overwrites terminating NULL on last iteration
    *ptr++ = (char16_t)'\n';
  }];

  assert(--ptr == ptrEnd);
  *ptr = '\0';

  return result;
}

uString *HttpRequest::GetResponseContentString() const {
  return uAs<uString *>((uObject *&)responseContent_, @{string : typeof});
}

uArray *HttpRequest::GetResponseContentByteArray() const {
  return uAs<uArray *>((uObject *&)responseContent_, @{byte[] : typeof});
}

void HttpRequest::SetResponseType(@{Uno.Net.Http.HttpResponseType} responseType) {
  responseType_ = responseType;
}

void HttpRequest::SetStreamingDataCallback(@{Uno.Action<byte[], bool>} callback) {
  streamingDataCallback_ = callback;
}

} // namespace iOS
} // namespace Http
} // namespace Net
} // namespace Uno
