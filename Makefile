APP_NAME = Scumbag Claude
BUNDLE_NAME = Scumbag Claude.app
EXECUTABLE = ClaudeTmpMonitor
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release

.PHONY: build run bundle clean

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
	@# Copy SPM resource bundle next to executable (where resource_bundle_accessor.swift looks first)
	@cp -R $(RELEASE_DIR)/ClaudeTmpMonitor_ClaudeTmpMonitor.bundle "$(RELEASE_DIR)/$(BUNDLE_NAME)/Contents/MacOS/" 2>/dev/null || true
	@echo "Built: $(RELEASE_DIR)/$(BUNDLE_NAME)"

install: bundle
	@echo "Installing to /Applications..."
	@cp -R "$(RELEASE_DIR)/$(BUNDLE_NAME)" /Applications/
	@echo "Installed: /Applications/$(BUNDLE_NAME)"

clean:
	swift package clean
	rm -rf "$(RELEASE_DIR)/$(BUNDLE_NAME)"
