# Contracts

## Addresses

### Arbitrum One

- Bazaar `0x76d8b9e38D9BAa56aB62fd832ECf0eEd79d7e7E9`
- Escrow `0xd6c042Fd42e5dC900BE869F5df2e1a21C3C48214`

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
pnpm exec hardhat run ./scripts/deploy.ts --network arbitrum
```

## Verify

```
pnpm exec hardhat verify CONTRACT_ADDRESS --network arbitrum
```

## Audit

Audit completed February 2023 by [Bernd Artmüller](https://github.com/berndartmueller) ([@berndartmueller](https://twitter.com/berndartmueller)).
Original audit report available [here](https://github.com/berndartmueller/audits/blob/main/audits/Bazaar/2023-02_Bazaar_Audit_Report.md).