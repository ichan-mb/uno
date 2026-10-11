using Uno;
using Uno.Graphics;
using Uno.Collections;
using Uno.Compiler.ExportTargetInterop;
using Uno.Platform.iOS;

namespace Uno.Platform
{
    [Require("source.include", "Uno-iOS/AppDelegate.h")]
    [Require("source.include", "Window.h")]
    [Require("source.include", "Uno-iOS/Context.h")]
    [Require("source.include", "@{Uno.Platform.iOSDisplay:include}")]
    public extern(iOS) class iOSDisplay : Uno.Platform.Display
    {
        ObjC.Object _displayLink = null;
        ObjC.Object _handle = null;

        public Rect Frame
        {
            get { return GetFrame(); }
        }

        public event EventHandler FrameChanged;

        void OnFrameChanged()
        {
            EventHandler handler = FrameChanged;
            if (handler != null)
                handler(null, EventArgs.Empty);
        }

        iOSDisplay(ObjC.Object handle)
        {
            _handle = handle;
            assert _handle != null;
            if defined(!LIBRARY)
                extern(_handle.Handle, this) "[((UIWindow*)$0) uSetDisplay:$1]";
        }

        ~iOSDisplay()
        {
            Destroy(_handle, _displayLink);
        }

        Rect GetFrame()
        {
            return Support.CGRectToUnoRect(
            Support.Pre_iOS8_HandleDeviceOrientation_Rect(
                extern<Uno.Platform.iOS.uCGRect>(_handle.Handle)"((UIWindow*)$0).frame", null),
                Density);
        }

        protected override float GetDensity()
        {
            return (float)GetDensityOfScreenFromWindow(_handle);
        }


        [Foreign(Language.ObjC)]
        static void Destroy(ObjC.Object handle, ObjC.Object displayLink)
        @{
            [displayLink invalidate];
        @}

        [Foreign(Language.ObjC)]
        extern(!LIBRARY)
        static internal Display WrapMainDisplay()
        @{
            uWindow* window = (uWindow*)[[uContext sharedContext] window];
            window.rootViewController = (UIViewController*)[[UIApplication sharedApplication] delegate];
            [window makeKeyAndVisible];
            return @{iOSDisplay(ObjC.Object):new(window)};
        @}

        [Foreign(Language.ObjC)]
        extern(LIBRARY)
        static internal Display WrapMainDisplay()
        @{
            CGRect screenBounds = [UIScreen mainScreen].bounds;
            UIWindow* window = [[uContext sharedContext] window];
            if (window == nil)
            {
                NSException* windowNilException = [NSException
                    exceptionWithName:@"Failed to initialize main Display"
                    reason:@"uContext.window is nil"
                    userInfo: nil];
                @throw windowNilException;
            }
            return @{iOSDisplay(ObjC.Object):new(window)};
        @}

        // Wraps an additional UIWindow (one granted by the window host to a
        // scene session when multiple scenes are enabled) in its own
        // iOSDisplay and registers it in Uno.Platform.Displays. Called from
        // the window host the first time a session is granted its own window.
        [Foreign(Language.ObjC)]
        static Display _createForWindow(ObjC.Object windowHandle)
        @{
            UIWindow* window = (UIWindow*)windowHandle;
            return @{iOSDisplay(ObjC.Object):new(window)};
        @}

        		static internal iOSDisplay WrapSecondaryDisplay(ObjC.Object windowHandle)
        		{
        			var display = (iOSDisplay)_createForWindow(windowHandle);
        			Displays.All.Add(display);
        			Displays.OnSecondaryDisplayAdded(display);
        			return display;
        		}

        		// Called by the window host when a scene session's window is discarded
        		// (for example the user closed the window).
        		static internal void NotifyWindowDiscarded(ObjC.Object window)
        		{
        			Displays.OnSecondaryDisplayDiscarded(window);
        		}

        // The UIWindow this display wraps (null for desktop displays).
        public ObjC.Object Window
        {
            get { return _handle; }
        }

        [Foreign(Language.ObjC)]
        static double GetDensityOfScreenFromWindow(ObjC.Object window)
        @{
            UIWindow* _window = (UIWindow*)window;
            // A window that is not attached to a scene yet has no screen; its
            // density would read as 0 and produce invalid layout geometry.
            UIScreen* screen = _window.screen;
            if (screen == nil)
                screen = [UIScreen mainScreen];
            return @{GetDensityOfScreen(ObjC.Object):call(screen)};
        @}

        [Foreign(Language.ObjC)]
        static double GetDensityOfScreen(ObjC.Object screen)
        @{
            UIScreen *uiScreen = (UIScreen*)screen;
            return (@{double})[uiScreen respondsToSelector:@selector(nativeScale)] ?
                [uiScreen nativeScale] :
                [uiScreen scale];
        @}

        //------------------------------------------------------------

        [Foreign(Language.ObjC)]
        protected override void SetTicksPerSecond(uint fps)
        @{
            CADisplayLink* displayLink = @{iOSDisplay:of(_this)._displayLink:get()};

            CFTimeInterval duration = displayLink.duration;
            if (duration == 0)
            {
                // Assume 60 fps
                duration = 1./60.;
            }

            unsigned actualFps;
            NSInteger frameInterval;

            if (fps == 0)
            {
                // Platform default
                actualFps = 0;
                frameInterval = 1;
            }
            else if (duration * fps > 0.5)
            {
                actualFps = 1. / duration;
                frameInterval = 1;
            }
            else
            {
                frameInterval = 1. / (duration * fps);
                actualFps = 1. / (duration * frameInterval);
            }

            displayLink.frameInterval = frameInterval;
            @{iOSDisplay:of(_this)._ticksPerSecond:set(actualFps)};
        @}

        [Foreign(Language.ObjC)]
        protected override void EnableTicks()
        @{
            CADisplayLink* displayLink = @{iOSDisplay:of(_this)._displayLink};
            UIWindow* window = (UIWindow*)@{iOSDisplay:of(_this)._handle};

            if (!displayLink)
            {
                uDisplayTickNotifier *notifier = [[uDisplayTickNotifier alloc] init];

                // A window granted a scene later than ticks start has no screen
                // yet; fall back to the main screen so the app's runloop ticks.
                UIScreen* tickScreen = window.screen;
                if (tickScreen == nil)
                    tickScreen = [UIScreen mainScreen];

                displayLink = [tickScreen displayLinkWithTarget:notifier selector:@selector(uOnDisplayTick:) ];

                [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
                [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:UITrackingRunLoopMode];

                @{iOSDisplay:of(_this)._displayLink:set(displayLink)};

                @{iOSDisplay:of(_this).SetTicksPerSecond(uint):call(@{iOSDisplay:of(_this)._ticksPerSecond})};
            }

            displayLink.paused = NO;
        @}

        [Foreign(Language.ObjC)]
        protected override void DisableTicks()
        @{
            CADisplayLink* displayLink = @{iOSDisplay:of(_this)._displayLink};
            displayLink.paused = YES;
        @}
    }
}
