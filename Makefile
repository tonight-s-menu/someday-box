SIMULATOR_DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro,OS=latest
BLENDER_BIN ?= /Applications/Blender.app/Contents/MacOS/Blender
DEVELOPER_DIR ?= $(shell /usr/bin/xcode-select -p)

.DEFAULT_GOAL := help

.PHONY: help audit test check ci-check xcode-test share-package-audit core-box-toolchain-audit core-box-pipeline-tests core-box-export-stage core-box-repro-check

help:
	@echo "make test       Run deterministic pure-domain checks"
	@echo "make audit      Run the static local-only source and configuration audit"
	@echo "make check      Run all checks available on this machine"
	@echo "make ci-check   Require and run the complete Xcode test gate"
	@echo "make xcode-test Run iOS unit and UI tests with a full Xcode installation"
	@echo "make share-package-audit ARCHIVE_PATH=/absolute/path/to/archive.xcarchive"
	@echo "make core-box-toolchain-audit Verify pinned Core Box tool provenance against the live machine"
	@echo "make core-box-pipeline-tests  Run the Core Box asset contract unit tests"
	@echo "make core-box-export-stage OUTPUT_ROOT=/absolute/path EXPORT_PROFILE=pipeline-spike-v1"
	@echo "make core-box-repro-check CHECKED_OUT_ASSETS=/absolute/path EXPORT_PROFILE=pipeline-spike-v1"
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

core-box-export-stage:
	@test -n "$(OUTPUT_ROOT)" || { echo "OUTPUT_ROOT is required." >&2; exit 64; }
	@test -n "$(EXPORT_PROFILE)" || { echo "EXPORT_PROFILE is required." >&2; exit 64; }
	./scripts/core-box-export.sh --output "$(OUTPUT_ROOT)" --profile "$(EXPORT_PROFILE)"
	/usr/bin/usdchecker --arkit --strict "$(OUTPUT_ROOT)/stage/full/CoreBoxCharacterFull.usda"
	/usr/bin/usdchecker --arkit --strict "$(OUTPUT_ROOT)/stage/lite/CoreBoxCharacterLite.usda"

core-box-repro-check:
	@test -n "$(CHECKED_OUT_ASSETS)" || { echo "CHECKED_OUT_ASSETS is required." >&2; exit 64; }
	@test -n "$(EXPORT_PROFILE)" || { echo "EXPORT_PROFILE is required." >&2; exit 64; }
	./scripts/core-box-repro-check.sh --checked-out-assets "$(CHECKED_OUT_ASSETS)" --profile "$(EXPORT_PROFILE)"
