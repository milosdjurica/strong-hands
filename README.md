# Sepolia address

https://sepolia.etherscan.io/address/0x9230b96720a66913aa69d076dd94105a81f82a40#code

# Installation

```sh

git clone https://github.com/milosdjurica/strong-hands
cd strong-hands
forge build

```

# Testing

### Run all tests (except Fork tests)

`forge test`

### Unit tests

`forge test --mc Unit`

### Fuzz tests

`forge test --mc Fuzz`

### Fork tests

```sh
source .env
# Run all Fork tests on Mainnet fork
forge test --fork-url $MAINNET_RPC_URL --mc Fork
# Run specific test on Mainnet fork
forge test --fork-url $MAINNET_RPC_URL --mt TestName

```

# Coverage

```sh
source .env
forge coverage --fork-url $MAINNET_RPC_URL --mc Fork
```

![Coverage image][Coverage-image-url]

# Deploying

```sh
source .env
forge script script/StrongHandsDeploy.s.sol:StrongHandsDeploy --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify

```

[Coverage-image-url]: https://github.com/milosdjurica/strong-hands/blob/main/public/coverage.png

