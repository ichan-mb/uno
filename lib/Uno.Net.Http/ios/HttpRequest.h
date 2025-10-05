#pragma once
#include <uno.h>

#ifdef __OBJC__
@class NSObject;
@class NSData;
@class NSHTTPURLResponse;
@class NSError;
@class NSMutableURLRequest;
@class NSURLSessionDataTask;
#else
struct NSObject;
struct NSData;
struct NSHTTPURLResponse;
struct NSError;
struct NSMutableURLRequest;
struct NSURLSessionDataTask;
#endif

@{Uno.Net.Http.HttpMessageHandlerRequest : forwardDeclaration}
@{Uno.Net.Http.HttpResponseType : forwardDeclaration}
@{Uno.Action<byte[], bool> : forwardDeclaration}

namespace Uno {
  namespace Net {
  namespace Http {
  namespace iOS {

  void SetupSharedCache(bool isCacheEnabled = true, size_t sizeInBytes = 0);
  void PurgeSharedCache();

  struct HttpRequest {
    struct Private;

    HttpRequest(@{Uno.Net.Http.HttpMessageHandlerRequest} unoRequest,
                uString *method, uString *url);

    void SetTimeout(int ms);
    void SetCacheEnabled(bool isCacheEnabled);
    void SetHeader(uString *key, uString *value);

    void SendAsync(uString *content);
    void SendAsync(const void *data, size_t length);

    void Abort();

    int GetResponseStatus() const;
    uString *GetResponseHeader(uString *key) const;
    uString *GetResponseHeaders() const;
    uString *GetResponseContentString() const;
    uArray *GetResponseContentByteArray() const;

    // Streaming support
    void SetResponseType(@{Uno.Net.Http.HttpResponseType} responseType);
    void SetStreamingDataCallback(@{Uno.Action<byte[], bool>} callback);

    struct Private {
      Private(const HttpRequest *r);

      NSMutableURLRequest *request() const;
      NSURLSessionDataTask *task() const;
      NSHTTPURLResponse *response() const;

      void ReceivedData(NSData *data);
      void ReceivedResponse(NSHTTPURLResponse *response);
      void Completed(NSData *data, NSHTTPURLResponse *response, NSError *error);
      void Abort();

      HttpRequest *this_;
    };

  private:
    HttpRequest(HttpRequest const &);
    void operator=(HttpRequest);

    @{Uno.Net.Http.HttpMessageHandlerRequest} unoRequest_;

    NSObject *requestTaskOrResponse_;
    uStrong<uObject *> responseContent_;

    // Streaming support
    @{Uno.Net.Http.HttpResponseType} responseType_;
    uStrong<@{Uno.Action<byte[], bool>}> streamingDataCallback_;
    uStrong<uObject *> streamingBuffer_;
    NSObject *streamingDelegate_;
  };

  } // namespace iOS
  } // namespace Http
  } // namespace Net
} // namespace Uno::Net::Http::Implementation::iOS
