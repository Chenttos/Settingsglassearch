export TARGET ?= iphone:clang:latest:15.0
export ARCHS ?= arm64 arm64e
export THEOS_PACKAGE_SCHEME ?= rootless

INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SettingsGlassSearch

SettingsGlassSearch_FILES = Tweak.x SGSSearchBarView.m $(wildcard Glass/*.m)
SettingsGlassSearch_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
SettingsGlassSearch_FRAMEWORKS = UIKit QuartzCore CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk
