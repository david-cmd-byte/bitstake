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

;; User Voting Records (prevents double voting)
(define-map VotingRecords
  {
    voter: principal,
    proposal-id: uint,
  }
  {
    vote-cast: bool,
    voting-power-used: uint,
  }
)

;; Tier System Configuration
(define-map TierConfiguration
  uint
  {
    minimum-stake: uint,
    reward-multiplier: uint,
    governance-weight: uint,
    features-unlocked: uint,
  }
)

;; PUBLIC FUNCTIONS

;; ----------------------------- Contract Initialization -------------------------
(define-public (initialize-protocol)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)

    ;; Initialize tier system
    (map-set TierConfiguration u1 {
      minimum-stake: u1000000,
      reward-multiplier: u100,
      governance-weight: u1,
      features-unlocked: u1,
    })
    (map-set TierConfiguration u2 {
      minimum-stake: u5000000,
      reward-multiplier: u125,
      governance-weight: u2,
      features-unlocked: u3,
    })
    (map-set TierConfiguration u3 {
      minimum-stake: u10000000,
      reward-multiplier: u150,
      governance-weight: u3,
      features-unlocked: u7,
    })
    (map-set TierConfiguration u4 {
      minimum-stake: u25000000,
      reward-multiplier: u200,
      governance-weight: u5,
      features-unlocked: u15,
    })

    (print {
      event: "protocol-initialized",
      timestamp: stacks-block-height,
    })
    (ok true)
  )
)

;; ------------------------------- Staking Operations ---------------------------
(define-public (stake-stx
    (amount uint)
    (lock-months uint)
  )
  (let (
      (existing-position (map-get? StakingPositions tx-sender))
      (lock-blocks (blocks-from-months lock-months))
      (tier-info (calculate-tier-level amount))
      (lock-multiplier (calculate-lock-multiplier lock-months))
      (final-multiplier (* (get reward-multiplier tier-info) lock-multiplier))
    )
    ;; Validations
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (>= amount (var-get minimum-stake)) ERR-MINIMUM-NOT-MET)
    (asserts! (is-valid-lock-period lock-months) ERR-INVALID-AMOUNT)
    (asserts! (is-none existing-position) ERR-INVALID-AMOUNT)

    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    ;; Create staking position
    (map-set StakingPositions tx-sender {
      stx-amount: amount,
      stake-height: stacks-block-height,
      last-claim-height: stacks-block-height,
      lock-duration: lock-blocks,
      cooldown-initiated: none,
      accumulated-rewards: u0,
      tier-level: (get tier-level tier-info),
      reward-multiplier: (/ final-multiplier u100),
    })

    ;; Update global state
    (var-set total-stx-locked (+ (var-get total-stx-locked) amount))

    (print {
      event: "stx-staked",
      user: tx-sender,
      amount: amount,
      tier: (get tier-level tier-info),
      lock-period: lock-months,
    })
    (ok true)
  )
)

(define-public (claim-rewards)
  (let (
      (position (unwrap! (map-get? StakingPositions tx-sender) ERR-NO-POSITION))
      (blocks-elapsed (- stacks-block-height (get last-claim-height position)))
      (rewards (calculate-staking-rewards position blocks-elapsed))
    )
    (asserts! (> rewards u0) ERR-INVALID-AMOUNT)

    ;; Mint rewards to user
    (try! (ft-mint? BITSTAKE rewards tx-sender))

    ;; Update position
    (map-set StakingPositions tx-sender
      (merge position {
        last-claim-height: stacks-block-height,
        accumulated-rewards: (+ (get accumulated-rewards position) rewards),
      })
    )

    (print {
      event: "rewards-claimed",
      user: tx-sender,
      amount: rewards,
    })
    (ok rewards)
  )
)

(define-public (initiate-unstaking)
  (let (
      (position (unwrap! (map-get? StakingPositions tx-sender) ERR-NO-POSITION))
      (lock-end (+ (get stake-height position) (get lock-duration position)))
    )
    (asserts! (>= stacks-block-height lock-end) ERR-COOLDOWN-ACTIVE)
    (asserts! (is-none (get cooldown-initiated position)) ERR-COOLDOWN-ACTIVE)

    ;; Automatically claim any pending rewards
    (try! (claim-rewards))

    ;; Start cooldown period
    (map-set StakingPositions tx-sender
      (merge position { cooldown-initiated: (some stacks-block-height) })
    )

    (print {
      event: "unstaking-initiated",
      user: tx-sender,
    })
    (ok true)
  )
)