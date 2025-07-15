#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <os/log.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <substrate.h>

@interface SyslogWindow : UIWindow
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, assign) BOOL isCapturing;
@property (nonatomic, assign) CGPoint lastPosition;
@property (nonatomic, assign) CGRect lastFrame;
@end

@implementation SyslogWindow
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelStatusBar + 2000;
        self.backgroundColor = [UIColor blackColor];
        self.alpha = 0.85;
        self.isCapturing = YES;
        self.lastPosition = self.center;
        self.lastFrame = self.frame;
        
        self.logView = [[UITextView alloc] initWithFrame:CGRectInset(self.bounds, 5, 30)];
        self.logView.editable = NO;
        self.logView.textColor = [UIColor whiteColor];
        self.logView.backgroundColor = [UIColor clearColor];
        self.logView.font = [UIFont systemFontOfSize:10];
        [self addSubview:self.logView];
        
        self.toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.toggleButton.frame = CGRectMake(10, 5, 80, 20);
        [self.toggleButton setTitle:@"Pause" forState:UIControlStateNormal];
        [self.toggleButton addTarget:self action:@selector(toggleCapture:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.toggleButton];

        self.clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.clearButton.frame = CGRectMake(self.bounds.size.width - 90, 5, 80, 20);
        [self.clearButton setTitle:@"Clear" forState:UIControlStateNormal];
        [self.clearButton addTarget:self action:@selector(clearLog) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.clearButton];
        
        self.userInteractionEnabled = YES;
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        
        UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
        [self addGestureRecognizer:pinch];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    CGPoint newCenter = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);

    // Keep the window within the screen bounds
    CGFloat halfWidth = self.frame.size.width / 2;
    CGFloat halfHeight = self.frame.size.height / 2;
    CGRect screenBounds = [UIScreen mainScreen].bounds;

    if (newCenter.x - halfWidth < 0) newCenter.x = halfWidth;
    if (newCenter.x + halfWidth > screenBounds.size.width) newCenter.x = screenBounds.size.width - halfWidth;
    if (newCenter.y - halfHeight < 0) newCenter.y = halfHeight;
    if (newCenter.y + halfHeight > screenBounds.size.height) newCenter.y = screenBounds.size.height - halfHeight;

    self.center = newCenter;
    [gesture setTranslation:CGPointZero inView:self.superview];

    if (gesture.state == UIGestureRecognizerStateEnded) {
        self.lastPosition = self.center;
    }
}

- (void)handlePinch:(UIPinchGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat scale = gesture.scale;
        CGRect newFrame = self.frame;

        CGFloat newWidth = newFrame.size.width * scale;
        CGFloat newHeight = newFrame.size.height * scale;

        // Get screen bounds
        CGRect screenBounds = [UIScreen mainScreen].bounds;

        // Apply constraints
        newWidth = MAX(200, MIN(newWidth, screenBounds.size.width));
        newHeight = MAX(200, MIN(newHeight, screenBounds.size.height));

        newFrame.size.width = newWidth;
        newFrame.size.height = newHeight;

        self.frame = newFrame;
        self.logView.frame = CGRectInset(self.bounds, 5, 30);
        self.clearButton.frame = CGRectMake(self.bounds.size.width - 90, 5, 80, 20);
        [gesture setScale:1.0];
    }
    if (gesture.state == UIGestureRecognizerStateEnded) {
        self.lastFrame = self.frame;
    }
}

- (void)toggleCapture:(UIButton *)sender {
    self.isCapturing = !self.isCapturing;
    [sender setTitle:self.isCapturing ? @"Pause" : @"Resume" forState:UIControlStateNormal];
}

- (void)appendLog:(NSString *)log {
    if (!self.isCapturing) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logView.text = [NSString stringWithFormat:@"%@\n%@", self.logView.text ?: @"", log];
        [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length, 0)];
    });
}

- (void)clearLog {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logView.text = @"";
    });
}
@end

static SyslogWindow *syslogWindow = nil;
static BOOL isWindowEnabled = YES;
static os_log_t custom_log;

static void loadPreferences() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/com.anonymousx.syslogviewer.plist"];
    isWindowEnabled = prefs[@"enabled"] ? [prefs[@"enabled"] boolValue] : YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (isWindowEnabled && !syslogWindow) {
            syslogWindow = [[SyslogWindow alloc] initWithFrame:CGRectMake(50, 50, 320, 480)];
            [syslogWindow makeKeyAndVisible];
        } else if (!isWindowEnabled && syslogWindow) {
            [syslogWindow clearLog];
            syslogWindow.hidden = YES;
            syslogWindow = nil;
        }
    });
}

static void start_log_capture() {
    void *handle = dlopen("/usr/lib/liboslog.dylib", RTLD_LAZY);
    if (handle) {
        // Define the block type
        typedef void (^os_log_callback_t)(os_log_type_t type, const char *message, void *ctx);

        // Get the function pointer
        void (*os_log_add_callback)(os_log_t, os_log_callback_t, void *) = dlsym(handle, "os_log_add_callback");

        if (os_log_add_callback) {
            custom_log = os_log_create("com.anonymousx.syslogviewer", "default");

            // Define the callback block
            os_log_callback_t callback = ^(os_log_type_t type, const char *message, void *ctx) {
                if (isWindowEnabled && syslogWindow) {
                    [syslogWindow appendLog:[NSString stringWithUTF8String:message]];
                }
            };

            os_log_add_callback(custom_log, callback, NULL);
        }
        dlclose(handle);
    }
}

%ctor {
    loadPreferences();
    start_log_capture();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPreferences, CFSTR("com.anonymousx.syslogviewer.prefschanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}