
build:
	xcodebuild -scheme receipt-scanner -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

test:
	xcodebuild -scheme receipt-scanner -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test

download_model:
	# from your repo root
	chmod +x apple-ml-fastvlm/app/get_pretrained_mlx_model.sh
	apple-ml-fastvlm/app/get_pretrained_mlx_model.sh --model 0.5b --dest receipt-scanner/Resources/FastVLM/model
