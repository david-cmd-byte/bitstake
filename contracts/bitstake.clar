;; Title: BitStake Protocol - Decentralized Staking Infrastructure for Bitcoin L2
;;
;; Summary: 
;; BitStake Protocol transforms STX into yield-generating assets through secure staking
;; mechanisms, enabling Bitcoin Layer 2 participants to earn rewards while maintaining
;; decentralized governance. Features tiered reward structures, democratic proposal
;; systems, and institutional-grade security controls.
;;
;; Description:
;; A sophisticated Clarity smart contract that bridges Bitcoin's security with DeFi
;; innovation. Users stake STX tokens to earn BITSTAKE rewards, participate in 
;; protocol governance, and unlock premium features through our tier system.
;; Built for the Stacks ecosystem with Bitcoin's principles of decentralization,
;; security, and financial sovereignty at its core.

;; TOKEN DEFINITION
(define-fungible-token BITSTAKE u0)

;; CONSTANTS & ERRORS
(define-constant CONTRACT-OWNER tx-sender)

;; Error Codes
(define-constant ERR-UNAUTHORIZED (err u1001))
(define-constant ERR-INVALID-AMOUNT (err u1002))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1003))
(define-constant ERR-COOLDOWN-ACTIVE (err u1004))
(define-constant ERR-NO-POSITION (err u1005))
(define-constant ERR-MINIMUM-NOT-MET (err u1006))
(define-constant ERR-CONTRACT-PAUSED (err u1007))
(define-constant ERR-INVALID-PROPOSAL (err u1008))
(define-constant ERR-VOTING-CLOSED (err u1009))

;; = STATE VARIABLES=
(define-data-var contract-paused bool false)
(define-data-var total-stx-locked uint u0)
(define-data-var proposal-counter uint u0)

;; Staking Configuration
(define-data-var base-yield-rate uint u500) ;; 5.00% annual base yield
(define-data-var tier-bonus-rate uint u100) ;; 1.00% tier bonus
(define-data-var minimum-stake uint u1000000) ;; 1 STX minimum
(define-data-var unstake-cooldown uint u1440) ;; 24 hours in blocks

;; == DATA MAPS==

;; User Staking Positions
(define-map StakingPositions
  principal
  {
    stx-amount: uint,
    stake-height: uint,
    last-claim-height: uint,
    lock-duration: uint,
    cooldown-initiated: (optional uint),
    accumulated-rewards: uint,
    tier-level: uint,
    reward-multiplier: uint,
  }
)

;; Governance Proposals
(define-map GovernanceProposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-utf8 128),
    description: (string-utf8 512),
    voting-start: uint,
    voting-end: uint,
    votes-for: uint,
    votes-against: uint,
    executed: bool,
    quorum-required: uint,
  }
)