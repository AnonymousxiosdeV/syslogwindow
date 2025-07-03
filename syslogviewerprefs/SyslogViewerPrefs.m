#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface SyslogViewerPrefs : PSListController
@end

@implementation SyslogViewerPrefs
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [NSMutableArray array];
        
        PSSpecifier *toggle = [PSSpecifier preferenceSpecifierNamed:@"Enable Window" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) type:PSSpecifierTypeToggleSwitch key:@"enabled"];
        [specifiers addObject:toggle];
        
        _specifiers = specifiers;
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.anonymousx.syslogviewer.plist"];
    return prefs[[specifier propertyForKey:@"key"]] ?: @(YES);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.anonymousx.syslogviewer.plist"] ?: [NSMutableDictionary dictionary];
    prefs[[specifier propertyForKey:@"key"]] = value;
    [prefs writeToFile:@"/var/mobile/Library/Preferences/com.anonymousx.syslogviewer.plist" atomically:YES];
    
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.anonymousx.syslogviewer.prefschanged"), NULL, NULL, YES);
}
@end