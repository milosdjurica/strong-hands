# Unit tests ->

`forge test --mc Unit`

# Fuzz tests ->

`forge test --mc Fuzz`

# Fork tests ->

```sh
source .env
# Run all Fork tests on Sepolia fork
forge test --fork-url $SEPOLIA_RPC_URL --mc Fork
# Run specific test on Mainnet fork
forge test --fork-url $MAINNET_RPC_URL --mt TestName

```

