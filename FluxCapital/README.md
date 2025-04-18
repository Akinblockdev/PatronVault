# PatronVault: AmplificationProtocol

A smart contract implementation for the Stacks blockchain that enables patrons to amplify community contributions through a transparent, governance-controlled funding mechanism.

## Overview

AmplificationProtocol is a Clarity smart contract designed for fundraising initiatives where a patron entity wants to incentivize community participation by matching or amplifying contributions. The contract implements a secure treasury system that allows verified recipients to receive disbursements from the combined pool of funds.

## Key Features

- **Contribution Amplification**: Automatically multiplies contributions based on a configurable factor
- **Governance Controls**: Multi-layered permission system for secure fund management
- **Time-Bounded Initiatives**: Initiatives automatically expire after a set block height
- **Transparent Fund Tracking**: All contributions, amplifications, and disbursements are tracked on-chain
- **Recipient Verification**: Only pre-approved entities can receive disbursements

## Contract Architecture

### Core Components

1. **Governance Stewardship**: The entity responsible for overall contract management
2. **Treasury Vault**: Secure storage of all contributions and amplified funds
3. **Initiative Framework**: Time-bounded funding campaigns with configurable parameters
4. **Amplification System**: Automatically applies the multiplier to contributions
5. **Recipient Registry**: Whitelisting system for verified fund recipients

### Roles

- **Governance Steward**: Can create initiatives, whitelist recipients, and modify contract settings
- **Patron**: Provides amplification funds and can participate in disbursement decisions
- **Contributors**: Provide funds that trigger the amplification mechanism
- **Recipients**: Verified entities eligible to receive disbursed funds

## Getting Started

### Deployment

Deploy the contract to the Stacks blockchain with:

```bash
clarinet deploy --network mainnet
```

### Initialization

After deployment, the contract requires the following initialization steps:

1. The deployer automatically becomes the Governance Steward
2. The steward must launch an initiative with:
   - A designated patron
   - An amplification factor (e.g., 100 = 1:1 matching)
   - A ceiling (maximum amount that can be amplified)
   - An expiration block height

### Example Usage Flow

```clarity
;; 1. Launch a new initiative
(contract-call? .amplification-protocol launch-initiative 
  'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9 ;; patron address
  u100                                        ;; 1:1 matching (100%)
  u1000000000                                 ;; 1000 STX ceiling
  u775000)                                    ;; expires at block 775000

;; 2. Patron deposits amplification funds
(as-contract 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9
  (contract-call? .amplification-protocol deposit-patron-funds u1000000000))

;; 3. Whitelist a recipient
(contract-call? .amplification-protocol whitelist-recipient 
  'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE)

;; 4. Community member contributes
(contract-call? .amplification-protocol contribute u10000000) ;; 10 STX

;; 5. Disburse funds to recipient
(contract-call? .amplification-protocol disburse-funds
  'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE
  u20000000) ;; 20 STX (10 from contribution + 10 from amplification)
```

## Functions Reference

### Governance Functions

- `transfer-stewardship`: Transfer governance control to a new steward
- `freeze-vault`: Pause all contract operations (emergency)
- `activate-vault`: Resume contract operations
- `whitelist-recipient`: Register an approved recipient
- `delist-recipient`: Remove a recipient from the whitelist

### Initiative Management

- `launch-initiative`: Create a new funding initiative with specified parameters
- `conclude-initiative`: End an active initiative

### Treasury Functions

- `deposit-patron-funds`: Add patron funds for amplification
- `contribute`: Make a contribution that will be amplified
- `disburse-funds`: Send funds to a verified recipient

### Query Functions

- `fetch-contributor-record`: Get the total contribution amount for an address
- `fetch-recipient-data`: Get information about a recipient
- `fetch-initiative-metrics`: Get current status and statistics for the initiative
- `fetch-vault-balance`: Get the current balance of the contract

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| 301 | ACCESS-DENIED | The caller doesn't have permission for this action |
| 302 | RECIPIENT-NOT-FOUND | The specified recipient is not registered |
| 303 | INVALID-ZERO-VALUE | Amount must be greater than zero |
| 304 | FUNDS-SHORTAGE | Insufficient funds in the vault |
| 305 | MAX-MATCH-EXCEEDED | The amplification ceiling has been reached |
| 306 | CONTRACT-FROZEN | The vault is currently frozen |
| 307 | ENTITY-EXISTS | The entity is already registered |
| 308 | INVALID-MULTIPLIER | The amplification factor must be positive |
| 309 | PATRON-RESTRICTED | Function limited to the patron entity |
| 310 | GOVERNANCE-RESTRICTED | Function limited to the governance steward |
| 311 | TIME-EXPIRED | The deadline has passed |
| 312 | LIVE-PROJECT-EXISTS | An initiative is already active |

## Security Considerations

- All sensitive functions have proper authorization checks
- Funds can only be disbursed to pre-verified recipients
- Time-bound initiatives prevent indefinite fund locking
- Balance checks before transfers prevent over-disbursement
- Function-specific error codes for better debugging and transparency

## Development and Testing

This contract has been developed and tested using the Clarinet development environment.

To run the test suite:

```bash
clarinet test
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request