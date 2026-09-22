# Command Line Tools ship Swift Testing, but SwiftPM only finds it when Xcode is selected.
CLT := /Library/Developer/CommandLineTools/Library/Developer
ifeq ($(shell xcode-select -p),/Library/Developer/CommandLineTools)
TEST_FLAGS := -Xswiftc -F -Xswiftc $(CLT)/Frameworks -Xlinker -rpath -Xlinker $(CLT)/Frameworks -Xlinker -rpath -Xlinker $(CLT)/usr/lib
endif

test:
	swift test $(TEST_FLAGS) $(ARGS)

.PHONY: test
