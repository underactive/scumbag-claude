APP_NAME = Scumbag Claude
BUNDLE_NAME = Scumbag Claude.app
EXECUTABLE = ClaudeTmpMonitor
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release

.PHONY: build run bundle sign clean

build:
	swift build -c release

run: build
	$(RELEASE_DIR)/$(EXECUTABLE)

bundle: build
	@echo "Creating app bundle..."
	@mkdir -p "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/MacOS"
	@mkdir -p "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/Resources"
	@mkdir -p "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/Frameworks"
	@cp $(RELEASE_DIR)/$(EXECUTABLE) "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/MacOS/"
	@cp Info.plist "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/"
	@cp Sources/ClaudeTmpMonitor/Resources/AppIcon.icns "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/Resources/"
	@cp Sources/ClaudeTmpMonitor/Resources/MenuBarIcon.png "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/Resources/"
	@cp Sources/ClaudeTmpMonitor/Resources/MenuBarIcon@2x.png "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/Resources/"
	@SPARKLE_FW=$$(find $(BUILD_DIR) -path "*/release/Sparkle.framework" -type d | head -1); \
		if [ -n "$$SPARKLE_FW" ]; then \
			cp -R "$$SPARKLE_FW" "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/Frameworks/"; \
		else \
			echo "Error: Sparkle.framework not found in build artifacts" && exit 1; \
		fi
	@install_name_tool -add_rpath @executable_path/../Frameworks \
		"$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/MacOS/$(EXECUTABLE)" 2>/dev/null || true
	@echo "Built: $(RELEASE_DIR)/$(BUNDLE_NAME)"

sign: bundle
	@if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then \
		IDENTITY=$$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/'); \
		echo "Signing with: $$IDENTITY"; \
		FWPATH="$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/Frameworks/Sparkle.framework"; \
		codesign --force --options runtime --preserve-metadata=entitlements --sign "$$IDENTITY" "$$FWPATH/Versions/B/XPCServices/Downloader.xpc"; \
		codesign --force --options runtime --preserve-metadata=entitlements --sign "$$IDENTITY" "$$FWPATH/Versions/B/XPCServices/Installer.xpc"; \
		codesign --force --options runtime --preserve-metadata=entitlements --sign "$$IDENTITY" "$$FWPATH/Versions/B/Updater.app"; \
		codesign --force --options runtime --preserve-metadata=entitlements --sign "$$IDENTITY" "$$FWPATH/Versions/B/Autoupdate"; \
		codesign --force --options runtime --sign "$$IDENTITY" "$$FWPATH"; \
		codesign --force --options runtime --sign "$$IDENTITY" "$(RELEASE_DIR)/$(BUNDLE_NAME)"; \
		codesign --verify --deep --strict "$(RELEASE_DIR)/$(BUNDLE_NAME)"; \
		echo "Signed and verified: $(RELEASE_DIR)/$(BUNDLE_NAME)"; \
	else \
		echo "Warning: No Developer ID certificate found, skipping code signing"; \
	fi

install: sign
	@echo "Installing to /Applications..."
	@pkill -x "$(EXECUTABLE)" 2>/dev/null || true
	@sleep 0.5
	@rm -rf "/Applications/$(BUNDLE_NAME)"
	@cp -R "$(RELEASE_DIR)/$(BUNDLE_NAME)" /Applications/
	@echo "Installed: /Applications/$(BUNDLE_NAME)"

clean:
	swift package clean
	rm -rf "$(RELEASE_DIR)/$(BUNDLE_NAME)"
