# Contracts

## Addresses

### Arbitrum Goerli

- Bazaar `0x4B36Ab67E5Ac6d82a2AAd29071aB6B1b0E61592D`
- Escrow `0x30Aa3aaCD9F2336052cC4ec44DC79ba06299b0bB`

## Build

```
pnpm install
pnpm run compile
```

## Deploy

```
pnpm exec hardhat run ./scripts/deploy.ts --network arbitrum-goerli
```

## Verify

```
pnpm exec hardhat verify CONTRACT_ADDRESS --network arbitrum-goerli
```

## Audit

Audit completed February 2023 by [Bernd Artmüller](https://github.com/berndartmueller) ([@berndartmueller](https://twitter.com/berndartmueller)).
Original audit report available [here](https://github.com/berndartmueller/audits/blob/main/audits/Bazaar/2023-02_Bazaar_Audit_Report.md).