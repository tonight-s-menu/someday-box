SIMULATOR_DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro,OS=latest
BLENDER_BIN ?= /Applications/Blender.app/Contents/MacOS/Blender
DEVELOPER_DIR ?= $(shell /usr/bin/xcode-select -p)

.DEFAULT_GOAL := help

.PHONY: help audit test check ci-check xcode-test share-package-audit core-box-toolchain-audit core-box-pipeline-tests

help:
	@echo "make test       Run deterministic pure-domain checks"
	@echo "make audit      Run the static local-only source and configuration audit"
	@echo "make check      Run all checks available on this machine"
	@echo "make ci-check   Require and run the complete Xcode test gate"
	@echo "make xcode-test Run iOS unit and UI tests with a full Xcode installation"
	@echo "make share-package-audit ARCHIVE_PATH=/absolute/path/to/archive.xcarchive"
	@echo "make core-box-toolchain-audit Verify pinned Core Box tool provenance against the live machine"
	@echo "make core-box-pipeline-tests  Run the Core Box asset contract unit tests"
	@echo "Override the simulator with SIMULATOR_DESTINATION='platform=iOS Simulator,...'"

audit:
	./scripts/audit-local-only.sh
	./scripts/audit-build-structure.sh
	./scripts/audit-core-box-assets.sh
	./scripts/audit-core-box-release.sh

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

share-package-audit:
	@test -n "$(ARCHIVE_PATH)" || { echo "ARCHIVE_PATH is required." >&2; exit 64; }
	./scripts/audit-share-package.sh "$(ARCHIVE_PATH)"

core-box-toolchain-audit:
	env -i DEVELOPER_DIR="$(DEVELOPER_DIR)" TZ=UTC LC_ALL=C LANG=C PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -B scripts/core_box_toolchain.py --source-root "$(CURDIR)" --scope full --blender "$(BLENDER_BIN)"

core-box-pipeline-tests:
	PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 -B -m unittest discover -s scripts/tests -p 'test_core_box_*.py' -v
