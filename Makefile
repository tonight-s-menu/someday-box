.DEFAULT_GOAL := help

.PHONY: help test check xcode-test

help:
	@echo "make test       Run pure-domain Swift Testing tests"
	@echo "make check      Run all checks available on this machine"
	@echo "make xcode-test Run iOS unit and UI tests with a full Xcode installation"

test:
	swift run someday-box-domain-checks

check: test
	@if xcodebuild -version >/dev/null 2>&1; then \
		$(MAKE) xcode-test; \
	else \
		echo "Skipping iOS build: full Xcode is not selected (Command Line Tools are insufficient)."; \
	fi

xcode-test:
	xcodebuild test -project SomedayBox.xcodeproj -scheme SomedayBox -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
