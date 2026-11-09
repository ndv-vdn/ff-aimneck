ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = FreeFire

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = aimneckff
aimneckff_FILES = Tweak.xm
aimneckff_FRAMEWORKS = Foundation UIKit
aimneckff_LIBRARIES = substrate
aimneckff_CFLAGS = -fobjc-arc -O2
aimneckff_LDFLAGS = -undefined dynamic_lookup

include $(THEOS)/makefiles/tweak.mk
