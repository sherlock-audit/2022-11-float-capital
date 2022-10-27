fuzz:
	# fuzz -c scribble-config.yaml arm
	yarn compile
	ganache --deterministic &> /dev/null &
	source .env
  forge script ./contracts/scripts/Arctic.s.sol:MyScript --rpc-url $GANACHE_RPC_URL --private-key $GANACHE_DETERMINISTIC_KEY -vv
	# fuzz -c scribble-config.yaml run
	# pkill -f ganache
	# fuzz -c scribble-config.yaml disarm

clean:
	rm -rf ./build
	test .scribble-arming.meta.json && fuzz disarm
