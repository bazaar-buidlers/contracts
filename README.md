# Contracts

## Addresses

### Arbitrum Goerli

- Bazaar `0xff2DfB52C63417CD1f5bAB91b2eFa8Cd50537A81`
- Escrow `0x33Dd073804C842075b679C159eBd8d12FDE8213B`

## Build

```
pnpm install
pnpm run compile
```

## Deploy

```
hardhat run ./scripts/deploy.ts --network arbitrum-goerli
```

## Verify

```
hardhat verify CONTRACT_ADDRESS --network arbitrum-goerli
```
