#pragma once
#ifdef __OBJC__
#include <UIKit/UIKit.h>

// Owns the windows displayed by the app. Behavior depends on the
// UIApplicationSupportsMultipleScenes value declared in the Info.plist:
//
// - false (default): exactly one window exists - the primary one - created
//   lazily on first use, and every scene session is associated with it. This
//   is the behavior apps have always had.
// - true (iPad multitasking): the first session to connect keeps the primary
//   window, so the app keeps its content; every additional session is granted
//   its own UIWindow created from the session scene's coordinate space and
//   wrapped in its own iOSDisplay (registered in Uno.Platform.Displays).
//   The extra windows have no content yet (a placeholder root view controller
//   keeps UIKit quiet); hosting a visual tree per window lands with the
//   Fuse-window API in a later phase.

@interface uWindowHost : NSObject

+ (instancetype)sharedHost;

// The primary uno window; created on first use.
- (UIWindow *)primaryWindow;

#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0

// Whether the Info.plist enables multiple scenes (iPad multitasking).
- (BOOL)multipleScenesEnabled;

// Returns the window for a session: the primary window for the first session
// (in both modes) or when multiple scenes are disabled; a dedicated window
// created once per additional session when multiple scenes are enabled.
// Idempotent: a session that has already been granted a window gets it back
// (this is also how reconnected sessions reuse their window).
- (UIWindow *)provideWindowForSession:(UISceneSession *)session scene:(UIScene *)scene;

// Associates a window with a scene session and attaches it to the scene
// (sets window.windowScene and makes the window key and visible).
- (void)attachWindow:(UIWindow *)window toSession:(UISceneSession *)session scene:(UIScene *)scene;

// Drops the association for a session. The window itself is kept: a
// disconnected scene may be reconnected by UIKit with its saved state.
- (void)detachSession:(UISceneSession *)session;

// Discards a session's window (application:didDiscardSceneSessions):
// unlinks and hides it.
- (void)destroySession:(UISceneSession *)session;

// The window associated with a session, if any.
- (UIWindow *)windowForSession:(UISceneSession *)session;

// Identifiers of the sessions that currently have a window registered.
- (NSSet<NSString *> *)windowSessionIdentifiers;

#endif

@end

#endif