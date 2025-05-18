
build:
	xcodebuild -scheme receipt-scanner -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

test:
	xcodebuild -scheme receipt-scanner -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test
