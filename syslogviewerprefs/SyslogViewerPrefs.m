#import <Preferences/PSListController.h>

@interface SyslogViewerPrefsController : PSListController
@end

@implementation SyslogViewerPrefsController
- (id)specifiers {
    if(_specifiers == nil) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}
@end
