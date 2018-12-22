ARCHS = arm64
TARGET = iphone:clang

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += Tweak Prefs

include $(THEOS_MAKE_PATH)/aggregate.mk
