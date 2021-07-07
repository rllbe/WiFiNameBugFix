ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WFLoggerFix
WFLoggerFix_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += wfloggerfixprefs
include $(THEOS_MAKE_PATH)/aggregate.mk