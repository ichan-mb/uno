#include <Uno-iOS/uWindowHost.h>
#include <uObjC.Foreign.h>
#include <Window.h>
@{Uno.Platform.iOSDisplay:includeDirective}

@implementation uWindowHost
{
    UIWindow *_primaryWindow;
#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0
    // Keyed by UISceneSession.persistentIdentifier: UISceneSession is not
    // known to conform to NSCopying, so sessions cannot be dictionary keys.
    NSMutableDictionary<NSString *, UIWindow *> *_windows;
    // -1 unknown, 0 no, 1 yes - whether UIApplicationSupportsMultipleScenes.
    int _multipleScenesEnabled;
    // Whether the primary window has been granted to a session already.
    BOOL _primaryGranted;
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
        _multipleScenesEnabled = -1;
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

- (BOOL)multipleScenesEnabled
{
    if (_multipleScenesEnabled == -1)
    {
        // UIApplicationSupportsMultipleScenes is nested inside the
        // UIApplicationSceneManifest dictionary in Info.plist; a top-level
        // lookup always returns nil.
        NSDictionary* manifest = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIApplicationSceneManifest"];
        BOOL enabled = manifest != nil &&
            [[manifest objectForKey:@"UIApplicationSupportsMultipleScenes"] boolValue];

        _multipleScenesEnabled = enabled ? 1 : 0;
    }

    return _multipleScenesEnabled == 1;
}

- (UIWindow *)provideWindowForSession:(UISceneSession *)session scene:(UIScene *)scene
{
    if (session == nil || session.persistentIdentifier == nil)
        return [self primaryWindow];

    UIWindow *window = _windows[session.persistentIdentifier];
    if (window != nil)
        return window;

    if (![self multipleScenesEnabled])
        return [self primaryWindow];

    // The first session keeps the primary window: it hosts the uno visual
    // tree. Additional sessions get a dedicated window sized from their
    // scene's coordinate space (deprecated in favor of effectiveGeometry in
    // iOS 26, but still correct for window creation).
    if (_windows.count > 0 || _primaryGranted)
    {
        CGRect bounds = CGRectZero;
        if ([scene isKindOfClass:[UIWindowScene class]])
        {
            UIWindowScene* windowScene = (UIWindowScene*)scene;
            bounds = windowScene.coordinateSpace.bounds;
        }

        window = [[uWindow alloc] initWithFrame:bounds];
        // Placeholder root so UIKit does not warn; real content per window
        // arrives with the Fuse window API in a later phase.
        window.rootViewController = [[UIViewController alloc] init];

        // Register the window with the uno runtime as its own display
        @{Uno.Platform.iOSDisplay.WrapSecondaryDisplay(ObjC.Object):call(window)};
    }
    else
    {
        window = [self primaryWindow];
        _primaryGranted = YES;
    }

    _windows[session.persistentIdentifier] = window;
    return window;
}

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

// Discards a session's window (application:didDiscardSceneSessions:). The
// window is unlinked and hidden; removing its iOSDisplay from
// Uno.Platform.Displays is deferred to the phase that owns per-window
// content, so a discarded session's window simply stops mattering.
- (void)destroySession:(UISceneSession *)session
{
    if (session == nil)
        return;

    UIWindow *window = _windows[session.persistentIdentifier];
    [_windows removeObjectForKey:session.persistentIdentifier];
    window.hidden = YES;

    if (window != nil)
        @{Uno.Platform.iOSDisplay.NotifyWindowDiscarded(ObjC.Object):call(window)};
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