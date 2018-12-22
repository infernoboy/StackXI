ARCHS = arm64
TARGET = iphone:clang
THEOS_DEVICE_IP = 0
THEOS_DEVICE_PORT = 2222
export TARGET ARCHS THEOS_DEVICE_IP THEOS_DEVICE_PORT

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += Tweak Prefs

include $(THEOS_MAKE_PATH)/aggregate.mk
