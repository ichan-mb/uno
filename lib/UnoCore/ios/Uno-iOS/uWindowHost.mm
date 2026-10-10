#include <Uno-iOS/uWindowHost.h>
#include <Window.h>

@implementation uWindowHost
{
    UIWindow *_primaryWindow;
#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0
    // Keyed by UISceneSession.persistentIdentifier: UISceneSession is not
    // known to conform to NSCopying, so sessions cannot be dictionary keys.
    NSMutableDictionary<NSString *, UIWindow *> *_windows;
#endif
}

+ (instancetype)sharedHost
{
    static uWindowHost *host = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        host = [[uWindowHost alloc] init];
    });
    return host;
}

- (instancetype)init
{
    if (self = [super init])
    {
#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0
        _windows = [NSMutableDictionary new];
#endif
    }
    return self;
}

- (UIWindow *)primaryWindow
{
    if (_primaryWindow == nil)
        _primaryWindow = [[uWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    return _primaryWindow;
}

#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0

- (void)attachWindow:(UIWindow *)window toSession:(UISceneSession *)session scene:(UIScene *)scene
{
    if (window == nil || session == nil || session.persistentIdentifier == nil || scene == nil)
        return;

    _windows[session.persistentIdentifier] = window;

    if ([scene isKindOfClass:[UIWindowScene class]])
    {
        if (@available(iOS 13.0, *))
        {
            window.windowScene = (UIWindowScene *)scene;
        }
    }
    [window makeKeyAndVisible];
}

- (void)detachSession:(UISceneSession *)session
{
    if (session == nil || session.persistentIdentifier == nil)
        return;

    [_windows removeObjectForKey:session.persistentIdentifier];
}

- (UIWindow *)windowForSession:(UISceneSession *)session
{
    if (session == nil)
        return nil;

    return _windows[session.persistentIdentifier];
}

- (NSSet<NSString *> *)windowSessionIdentifiers
{
    return [NSSet setWithArray:_windows.allKeys];
}

#endif

@end