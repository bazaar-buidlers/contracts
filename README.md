# Contracts

## Addresses

### Arbitrum Goerli

- Bazaar `0x4e67A42C43FEAe4AD066e0bdf373ae9076263d97`
- Escrow `0x0cA79643715dBfC9e0D094a4D18Ad618189F1C58`

## Development

### Build

```
pnpm install
pnpm run compile
```

### Deploy

```
hardhat run ./scripts/deploy.ts --network arbitrum-goerli
```

### Verify

```
pnpm exec hardhat verify CONTRACT_ADDRESS --network arbitrum-goerli
```

## Audit

Audit completed February 2023 by [Bernd Artmüller](https://github.com/berndartmueller) ([@berndartmueller](https://twitter.com/berndartmueller)).
Original audit report available [here](https://github.com/berndartmueller/audits/blob/main/audits/Bazaar/2023-02_Bazaar_Audit_Report.md).
