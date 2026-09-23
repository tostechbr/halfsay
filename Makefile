# Command Line Tools ship Swift Testing, but SwiftPM only finds it when Xcode is selected.
CLT := /Library/Developer/CommandLineTools/Library/Developer
ifeq ($(shell xcode-select -p),/Library/Developer/CommandLineTools)
TEST_FLAGS := -Xswiftc -F -Xswiftc $(CLT)/Frameworks -Xlinker -rpath -Xlinker $(CLT)/Frameworks -Xlinker -rpath -Xlinker $(CLT)/usr/lib
endif
APP := build/halfsay.app

test:
	swift test $(TEST_FLAGS) $(ARGS)

# A real .app gets its own Microphone, Speech and Accessibility permissions instead of borrowing your terminal's.
# Ad-hoc signed: macOS may ask for them again after a rebuild.
app:
	swift build -c release --product halfsay
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/halfsay $(APP)/Contents/MacOS/halfsay
	cp Sources/halfsay/Info.plist $(APP)/Contents/Info.plist
	codesign --force --sign - $(APP)
	@echo "built $(APP): open it, then press ⌥Space"

# An app opened from Finder gets no shell environment, so the key lives in a private file.
key:
	@test -f .env || { echo "no .env here with TYPESAFE_API_KEY=..."; exit 1; }
	@mkdir -p ~/.config/halfsay
	@sed -n -e 's/^export TYPESAFE_API_KEY=//p' -e 's/^TYPESAFE_API_KEY=//p' .env | head -1 > ~/.config/halfsay/api-key
	@chmod 600 ~/.config/halfsay/api-key
	@test -s ~/.config/halfsay/api-key && echo "key saved to ~/.config/halfsay/api-key"

.PHONY: test app key
