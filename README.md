# BitStake Protocol

## Decentralized Staking Infrastructure for Bitcoin Layer 2

[![Stacks](https://img.shields.io/badge/Stacks-2.1-blue.svg)](https://www.stacks.co/)
[![Clarity](https://img.shields.io/badge/Clarity-2.0-orange.svg)](https://clarity-lang.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

BitStake Protocol is a sophisticated DeFi infrastructure that transforms STX tokens into yield-generating assets through secure staking mechanisms. Built on the Stacks blockchain, it enables Bitcoin Layer 2 participants to earn rewards while maintaining decentralized governance and unlocking premium features through a tiered reward system.

## 🚀 Features

### Core Functionality

- **STX Staking**: Stake STX tokens to earn BITSTAKE rewards
- **Tiered Rewards**: Progressive reward multipliers based on stake amount
- **Lock-up Periods**: Additional yield bonuses for longer commitment periods
- **Governance Participation**: Democratic proposal system for protocol decisions
- **Institutional Security**: Multi-layered security controls and cooldown periods

### Advanced Features

- **Dynamic Yield Calculation**: Real-time reward computation based on staking duration
- **Voting Power**: Stake-weighted governance participation
- **Proposal Creation**: Community-driven protocol improvements
- **Emergency Controls**: Administrative pause/resume functionality
- **Transparent Analytics**: On-chain protocol statistics

## 📊 Tier System

| Tier | Minimum Stake | Reward Multiplier | Governance Weight | Features Unlocked |
|------|---------------|-------------------|-------------------|-------------------|
| 1    | 1 STX         | 1.00x             | 1x                | Basic             |
| 2    | 5 STX         | 1.25x             | 2x                | Enhanced          |
| 3    | 10 STX        | 1.50x             | 3x                | Premium           |
| 4    | 25 STX        | 2.00x             | 5x                | Elite             |

## 🔒 Lock-up Periods & Bonuses

| Period    | Bonus Multiplier | Description |
|-----------|------------------|-------------|
| 0 months  | 1.00x           | No lock-up  |
| 3 months  | 1.25x           | 25% bonus   |
| 6 months  | 1.50x           | 50% bonus   |
| 12 months | 1.75x           | 75% bonus   |
| 24 months | 1.75x           | 75% bonus   |

## 🛠 Getting Started

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) for smart contract development
- [Node.js](https://nodejs.org/) for testing infrastructure
- [Stacks Wallet](https://www.hiro.so/wallet) for mainnet interaction

### Installation

```bash
# Clone the repository
git clone https://github.com/david-cmd-byte/bitstake.git
cd bitstake

# Install dependencies
npm install

# Check contract syntax
clarinet check

# Run tests
npm test
```

### Development Setup

```bash
# Format contracts
clarinet fmt --in-place

# Start development console
clarinet console

# Deploy to devnet
clarinet deploy --devnet
```

## 📋 Contract Interface

### Public Functions

#### Staking Operations

```clarity
;; Stake STX tokens with optional lock period
(stake-stx (amount uint) (lock-months uint))

;; Claim accumulated rewards
(claim-rewards)

;; Initiate unstaking process
(initiate-unstaking)

;; Complete unstaking after cooldown
(complete-unstaking)
```

#### Governance Functions

```clarity
;; Create governance proposal
(create-proposal (title (string-utf8 128)) (description (string-utf8 512)) (voting-duration uint))

;; Vote on proposal
(vote-on-proposal (proposal-id uint) (support bool))
```

#### Administrative Functions

```clarity
;; Emergency pause/resume
(pause-contract)
(resume-contract)

;; Update yield parameters
(update-yield-parameters (base-rate uint) (bonus-rate uint))
```

### Read-Only Functions

```clarity
;; Get user's staking position
(get-staking-position (user principal))

;; Get proposal details
(get-proposal (proposal-id uint))

;; Get protocol statistics
(get-protocol-stats)

;; Calculate pending rewards
(calculate-pending-rewards (user principal))

;; Get user's voting power
(get-user-voting-power (user principal))
```

## 🏗 Architecture

### Token Economics

- **Base Yield**: 5.00% annual rate
- **Tier Bonus**: Up to 100% additional yield for elite tier
- **Lock Bonus**: Up to 75% additional yield for 12+ month locks
- **Minimum Stake**: 1 STX (1,000,000 microSTX)

### Security Features

- **Cooldown Period**: 24-hour delay for unstaking completion
- **Access Control**: Owner-only administrative functions
- **Circuit Breaker**: Emergency pause functionality
- **Input Validation**: Comprehensive parameter checking

### Governance Model

- **Proposal Threshold**: Minimum 1 STX voting power to create proposals
- **Quorum Requirement**: 20% of total staked STX
- **Voting Duration**: 1-30 days (144-4320 blocks)
- **Weighted Voting**: Stake amount × tier governance weight

## 🧪 Testing

The protocol includes comprehensive test coverage:

```bash
# Run all tests
npm test

# Run specific test files
npm test -- bitstake.test.ts

# Generate coverage report
npm run test:coverage
```

### Test Categories

- **Staking Operations**: Deposit, rewards, unstaking flows
- **Governance**: Proposal creation, voting, execution
- **Security**: Access controls, pause functionality, edge cases
- **Economics**: Reward calculations, tier system, lock bonuses

## 🚀 Deployment

### Testnet Deployment

```bash
# Deploy to Stacks testnet
clarinet deploy --testnet

# Verify deployment
clarinet call-read-only bitstake get-protocol-stats --testnet
```

### Mainnet Deployment

```bash
# Deploy to Stacks mainnet
clarinet deploy --mainnet

# Initialize protocol
clarinet call initialize-protocol --mainnet
```

## 📈 Usage Examples

### Basic Staking

```javascript
// Stake 10 STX for 6 months
await contractCall({
  contractAddress: BITSTAKE_ADDRESS,
  contractName: 'bitstake',
  functionName: 'stake-stx',
  functionArgs: [uintCV(10000000), uintCV(6)], // 10 STX, 6 months
});
```

### Governance Participation

```javascript
// Create a proposal
await contractCall({
  contractAddress: BITSTAKE_ADDRESS,
  contractName: 'bitstake',
  functionName: 'create-proposal',
  functionArgs: [
    stringUtf8CV("Increase Base Yield"),
    stringUtf8CV("Proposal to increase base yield rate to 6%"),
    uintCV(2160) // 15 days voting period
  ],
});
```

## 🔐 Security Considerations

- **Smart Contract Audits**: Recommended before mainnet deployment
- **Key Management**: Secure storage of contract owner keys
- **Upgradability**: Consider proxy patterns for future upgrades
- **Oracle Integration**: External price feeds for enhanced features

## 🤝 Contributing

We welcome contributions to the BitStake Protocol! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎯 Roadmap

### Phase 1: Core Protocol ✅

- [x] STX staking mechanism
- [x] Tiered reward system
- [x] Basic governance

### Phase 2: Enhanced Features 🚧

- [ ] Liquid staking derivatives
- [ ] Cross-chain integrations
- [ ] Advanced governance features

### Phase 3: Ecosystem Expansion 🔮

- [ ] Institutional features
- [ ] Protocol partnerships
- [ ] Mobile applications
