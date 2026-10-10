#pragma once
#ifdef __OBJC__
#include <UIKit/UIKit.h>

// Owns the windows displayed by the app. Groundwork for multiple windows:
// the primary window is created lazily on first use (same timing and size as
// the window uAppDelegate used to create in init), and scene-to-window
// bookkeeping is registered here instead of being spread over the scene
// delegate. A later phase will create and attach a dedicated window per
// UISceneSession, which is what multiple-window support (iPad multitasking,
// dual-screen devices) needs; until then exactly one window exists and each
// scene session is associated with it.

@interface uWindowHost : NSObject

+ (instancetype)sharedHost;

// The primary uno window; created on first use.
- (UIWindow *)primaryWindow;

#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0

// Associates a window with a scene session and attaches it to the scene
// (sets window.windowScene and makes the window key and visible).
- (void)attachWindow:(UIWindow *)window toSession:(UISceneSession *)session scene:(UIScene *)scene;

// Drops the association for a session. The window itself is kept: a
// disconnected scene may be reconnected by UIKit with its saved state.
- (void)detachSession:(UISceneSession *)session;

// The window associated with a session, if any.
- (UIWindow *)windowForSession:(UISceneSession *)session;

// Identifiers of the sessions that currently have a window registered.
- (NSSet<NSString *> *)windowSessionIdentifiers;

#endif

@end

#endif