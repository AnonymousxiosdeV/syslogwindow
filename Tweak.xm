#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <LoggingSupport/OSLog.h>
#import <Preferences/PSSpecifier.h>
#import <substrate.h>

@interface SyslogWindow : UIWindow
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, assign) BOOL isCapturing;
@end

@implementation SyslogWindow
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelStatusBar + 1000;
        self.backgroundColor = [UIColor blackColor];
        self.alpha = 0.9;
        self.isCapturing = YES;
        
        self.logView = [[UITextView alloc] initWithFrame:CGRectInset(self.bounds, 0, 30)];
        self.logView.editable = NO;
        self.logView.textColor = [UIColor whiteColor];
        self.logView.backgroundColor = [UIColor clearColor];
        self.logView.font = [UIFont systemFontOfSize:12];
        [self addSubview:self.logView];
        
        self.toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.toggleButton.frame = CGRectMake(10, 5, 80, 20);
        [self.toggleButton setTitle:@"Pause" forState:UIControlStateNormal];
        [self.toggleButton addTarget:self action:@selector(toggleCapture:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.toggleButton];
        
        self.userInteractionEnabled = YES;
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        
        UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
        [self addGestureRecognizer:pinch];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self];
}

- (void)handlePinch:(UIPinchGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat scale = gesture.scale;
        CGRect newFrame = self.frame;
        newFrame.size.width = MAX(200, newFrame.size.width * scale);
        newFrame.size.height = MAX(200, newFrame.size.height * scale);
        self.frame = newFrame;
        self.logView.frame = CGRectInset(self.bounds, 0, 30);
        [gesture setScale:1.0];
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

static void loadPreferences() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/com.anonymousx.syslogviewer.plist"];
    isWindowEnabled = prefs[@"enabled"] ? [prefs[@"enabled"] boolValue] : YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (isWindowEnabled && !syslogWindow) {
            syslogWindow = [[SyslogWindow alloc] initWithFrame:CGRectMake(50, 50, 300, 400)];
            [syslogWindow makeKeyAndVisible];
        } else if (!isWindowEnabled && syslogWindow) {
            [syslogWindow clearLog];
            syslogWindow.hidden = YES;
            syslogWindow = nil;
        }
    });
}

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    loadPreferences();
}
%end

%hookf(void, os_log_impl, void *bundle, void *category, uint8_t type, const char *format, va_list args) {
    %orig;
    if (!isWindowEnabled) return;
    char buffer[1024];
    vsnprintf(buffer, sizeof(buffer), format, args);
    NSString *logMessage = @(buffer);
    [syslogWindow appendLog:logMessage];
}

%ctor {
    %init;
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPreferences, CFSTR("com.anonymousx.syslogviewer.prefschanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}