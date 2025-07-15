#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface SyslogViewerPrefs : PSListController
@end

@implementation SyslogViewerPrefs
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *path = [NSString stringWithFormat:@"/var/jb/var/mobile/Library/Preferences/%@.plist", [specifier.properties objectForKey:@"defaults"]];
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:path];
    return prefs[[specifier propertyForKey:@"key"]] ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *path = [NSString stringWithFormat:@"/var/jb/var/mobile/Library/Preferences/%@.plist", [specifier.properties objectForKey:@"defaults"]];
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
    [prefs setObject:value forKey:[specifier propertyForKey:@"key"]];
    [prefs writeToFile:path atomically:YES];
    
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)[specifier.properties objectForKey:@"PostNotification"], NULL, NULL, YES);
}
@end