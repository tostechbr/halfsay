# Command Line Tools ship Swift Testing, but SwiftPM only finds it when Xcode is selected.
CLT := /Library/Developer/CommandLineTools/Library/Developer
ifeq ($(shell xcode-select -p),/Library/Developer/CommandLineTools)
TEST_FLAGS := -Xswiftc -F -Xswiftc $(CLT)/Frameworks -Xlinker -rpath -Xlinker $(CLT)/Frameworks -Xlinker -rpath -Xlinker $(CLT)/usr/lib
endif
APP := build/partway.app

test:
	swift test $(TEST_FLAGS) $(ARGS)

# A real .app gets its own Microphone, Speech and Accessibility permissions instead of borrowing your terminal's.
# Ad-hoc signed: macOS may ask for them again after a rebuild.
app:
	swift build -c release --product partway
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp .build/release/partway $(APP)/Contents/MacOS/partway
	cp Sources/partway/Info.plist $(APP)/Contents/Info.plist
	cp Sources/partway/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	codesign --force --sign - $(APP)
	@echo "built $(APP): open it, then press ⌥Space"

# docs/icon.svg is the source. Chrome draws it (SVG filters included), sips and iconutil make the app icon and the README image.
CHROME := /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
icon:
	mkdir -p build && rm -rf build/AppIcon.iconset && mkdir build/AppIcon.iconset
	"$(CHROME)" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --default-background-color=00000000 \
		--window-size=1024,1024 --screenshot="$(CURDIR)/build/icon-1024.png" "file://$(CURDIR)/docs/icon.svg" 2>/dev/null
	for size in 16 32 128 256 512; do \
		sips -z $$size $$size build/icon-1024.png --out build/AppIcon.iconset/icon_$${size}x$${size}.png >/dev/null; \
		sips -z $$((size * 2)) $$((size * 2)) build/icon-1024.png --out build/AppIcon.iconset/icon_$${size}x$${size}@2x.png >/dev/null; \
	done
	iconutil -c icns build/AppIcon.iconset -o Sources/partway/AppIcon.icns
	sips -z 256 256 build/icon-1024.png --out docs/icon.png >/dev/null

# An app opened from Finder gets no shell environment, so the key lives in a private file.
key:
	@test -f .env || { echo "no .env here with TYPESAFE_API_KEY=..."; exit 1; }
	@mkdir -p ~/.config/partway
	@sed -n -e 's/^export TYPESAFE_API_KEY=//p' -e 's/^TYPESAFE_API_KEY=//p' .env | head -1 > ~/.config/partway/api-key
	@chmod 600 ~/.config/partway/api-key
	@test -s ~/.config/partway/api-key && echo "key saved to ~/.config/partway/api-key"

.PHONY: test app icon key
