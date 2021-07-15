#include "WFLFRootListController.h"

@implementation WFLFRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] retain];
	}

	return _specifiers;
}

- (void)wifidNotify {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), CFSTR("in.net.mario.tweak.wfloggerfixprefs"), NULL, NULL, true);
}

@end
