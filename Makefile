ARCHS = arm64
TARGET = iphone:clang:latest:15.6
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SyslogViewer
SyslogViewer_FILES = Tweak.xm
SyslogViewer_FRAMEWORKS = UIKit Foundation
SyslogViewer_PRIVATE_FRAMEWORKS = Preferences
SyslogViewer_LIBRARIES = substrate
SyslogViewer_CFLAGS = -fobjc-arc -I$(THEOS)/sdks/iPhoneOS15.6.sdk/usr/include

include $(THEOS)/makefiles/tweak.mk

SUBPROJECTS += syslogviewerprefs
include $(THEOS)/makefiles/aggregate.mk