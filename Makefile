SIMULATOR_DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro,OS=latest

.DEFAULT_GOAL := help

.PHONY: help audit test check ci-check xcode-test

help:
	@echo "make test       Run deterministic pure-domain checks"
	@echo "make audit      Run the static local-only source and configuration audit"
	@echo "make check      Run all checks available on this machine"
	@echo "make ci-check   Require and run the complete Xcode test gate"
	@echo "make xcode-test Run iOS unit and UI tests with a full Xcode installation"
	@echo "Override the simulator with SIMULATOR_DESTINATION='platform=iOS Simulator,...'"

audit:
	./scripts/audit-local-only.sh

test:
	swift run someday-box-domain-checks

check: audit test
	@if xcodebuild -version >/dev/null 2>&1; then \
		$(MAKE) xcode-test; \
	else \
		echo "Skipping iOS build: full Xcode is not selected (Command Line Tools are insufficient)."; \
	fi

ci-check: audit test
	@xcodebuild -version >/dev/null 2>&1 || { echo "Full Xcode is required for ci-check." >&2; exit 1; }
	$(MAKE) xcode-test

xcode-test:
	xcodebuild test -project SomedayBox.xcodeproj -scheme SomedayBox -destination "$(SIMULATOR_DESTINATION)"
