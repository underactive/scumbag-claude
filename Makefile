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
	@cp $(RELEASE_DIR)/$(EXECUTABLE) "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/MacOS/"
	@cp Info.plist "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/"
	@cp Sources/ClaudeTmpMonitor/Resources/AppIcon.icns "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/Resources/"
	@cp Sources/ClaudeTmpMonitor/Resources/MenuBarIcon.png "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/Resources/"
	@cp Sources/ClaudeTmpMonitor/Resources/MenuBarIcon@2x.png "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/Resources/"
	@echo "Built: $(RELEASE_DIR)/$(BUNDLE_NAME)"

sign: bundle
	@if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then \
		IDENTITY=$$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/'); \
		echo "Signing with: $$IDENTITY"; \
		codesign --force --options runtime --sign "$$IDENTITY" "$(RELEASE_DIR)/$(BUNDLE_NAME)"; \
		codesign --verify --deep --strict "$(RELEASE_DIR)/$(BUNDLE_NAME)"; \
		echo "Signed and verified: $(RELEASE_DIR)/$(BUNDLE_NAME)"; \
	else \
		echo "Warning: No Developer ID certificate found, skipping code signing"; \
	fi

install: sign
	@echo "Installing to /Applications..."
	@cp -R "$(RELEASE_DIR)/$(BUNDLE_NAME)" /Applications/
	@echo "Installed: /Applications/$(BUNDLE_NAME)"

clean:
	swift package clean
	rm -rf "$(RELEASE_DIR)/$(BUNDLE_NAME)"
