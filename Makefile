# Variables
APP_NAME = MacroTracker
PROJECT_NAME = MacroTracker.xcodeproj
SCHEME_NAME = MacroTracker
UI_TEST_SCHEME = MacroTrackerUITests
BUILD_DIR = $(PWD)/build

# Simulators (Change these if you want to test on specific devices)
DESTINATION_IOS = 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest'

# Default target
default: build

# -------------------------------------------------------------------------
# COMMANDS
# -------------------------------------------------------------------------

.PHONY: build install clean test test-ui fmt lint code2prompt

# 1. Build the App (Verifies compilation)
build:
	xcodebuild \
		-project $(PROJECT_NAME) \
		-scheme $(SCHEME_NAME) \
		-destination 'generic/platform=iOS' \
		-configuration Debug \
		build \
		CONFIGURATION_BUILD_DIR=$(BUILD_DIR) \
		-allowProvisioningUpdates \
		ENABLE_USER_SCRIPT_SANDBOXING=NO

# 2. Install on connected device (use: xcrun devicectl list devices to find device ID)
install:
	@echo "📱 Finding device and installing..."
	@DEVICE_ID=$$(xcrun devicectl list devices 2>/dev/null | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' | head -n 1); \
	if [ -z "$$DEVICE_ID" ]; then \
		echo "❌ Error: No connected device found!"; \
		exit 1; \
	fi; \
	echo "🚀 Installing to device: $$DEVICE_ID"; \
	xcrun devicectl device install app --device $$DEVICE_ID $(BUILD_DIR)/$(APP_NAME).app

# 3. Run Unit Tests (Fast logic checks)
test:
	xcodebuild test \
		-project $(PROJECT_NAME) \
		-scheme $(SCHEME_NAME) \
		-destination $(DESTINATION_IOS) \
		-quiet

# 4. Run UI Tests (Slower, full app automation)
test-ui:
	xcodebuild test \
		-project $(PROJECT_NAME) \
		-scheme $(UI_TEST_SCHEME) \
		-destination $(DESTINATION_IOS) \
		-quiet

# 5. Clean Build Artifacts (Fixes weird Xcode caching issues)
clean:
	xcodebuild clean \
		-project $(PROJECT_NAME) \
		-scheme $(SCHEME_NAME)
	rm -rf ~/Library/Developer/Xcode/DerivedData/$(APP_NAME)-*

# 6. Format Code
fmt:
	xcrun swift format format -i --recursive .

# 7. Lint Code (Requires: brew install swiftlint)
lint:
	swiftlint

code2prompt:
	code2prompt . \
		--template project.hbs \
		--include "*.swift,*.plist,*.json,*.entitlements" \
		--exclude "**/DerivedData/**,**/Pods/**,**/Carthage/**,**/.build/**,**/fastlane/**,**/*.xcodeproj/**,**/*.xcworkspace/**,**.md**,**.hbs**" \
		--output-file project_context.md
