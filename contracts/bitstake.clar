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

;; Contract Initialization
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

;; Staking Operations
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

(define-public (complete-unstaking)
  (let (
      (position (unwrap! (map-get? StakingPositions tx-sender) ERR-NO-POSITION))
      (cooldown-start (unwrap! (get cooldown-initiated position) ERR-COOLDOWN-ACTIVE))
      (cooldown-complete (>= (- stacks-block-height cooldown-start) (var-get unstake-cooldown)))
    )
    (asserts! cooldown-complete ERR-COOLDOWN-ACTIVE)

    ;; Return staked STX
    (try! (as-contract (stx-transfer? (get stx-amount position) tx-sender tx-sender)))

    ;; Update global state
    (var-set total-stx-locked
      (- (var-get total-stx-locked) (get stx-amount position))
    )

    ;; Remove position
    (map-delete StakingPositions tx-sender)

    (print {
      event: "unstaking-completed",
      user: tx-sender,
      amount: (get stx-amount position),
    })
    (ok true)
  )
)

;; Governance Functions
(define-public (create-proposal
    (title (string-utf8 128))
    (description (string-utf8 512))
    (voting-duration uint)
  )
  (let (
      (position (unwrap! (map-get? StakingPositions tx-sender) ERR-UNAUTHORIZED))
      (proposal-id (+ (var-get proposal-counter) u1))
      (voting-power (calculate-voting-power position))
    )
    (asserts! (>= voting-power u1000000) ERR-UNAUTHORIZED)
    (asserts! (and (>= (len title) u5) (<= (len title) u128))
      ERR-INVALID-PROPOSAL
    )
    (asserts! (and (>= (len description) u20) (<= (len description) u512))
      ERR-INVALID-PROPOSAL
    )
    (asserts! (and (>= voting-duration u144) (<= voting-duration u4320))
      ERR-INVALID-PROPOSAL
    )

    (map-set GovernanceProposals { proposal-id: proposal-id } {
      proposer: tx-sender,
      title: title,
      description: description,
      voting-start: stacks-block-height,
      voting-end: (+ stacks-block-height voting-duration),
      votes-for: u0,
      votes-against: u0,
      executed: false,
      quorum-required: (/ (var-get total-stx-locked) u5), ;; 20% quorum
    })

    (var-set proposal-counter proposal-id)
    (print {
      event: "proposal-created",
      id: proposal-id,
      proposer: tx-sender,
    })
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal
    (proposal-id uint)
    (support bool)
  )
  (let (
      (proposal (unwrap! (map-get? GovernanceProposals { proposal-id: proposal-id })
        ERR-INVALID-PROPOSAL
      ))
      (position (unwrap! (map-get? StakingPositions tx-sender) ERR-UNAUTHORIZED))
      (voting-power (calculate-voting-power position))
      (existing-vote (map-get? VotingRecords {
        voter: tx-sender,
        proposal-id: proposal-id,
      }))
    )
    (asserts! (< stacks-block-height (get voting-end proposal)) ERR-VOTING-CLOSED)
    (asserts! (is-none existing-vote) ERR-UNAUTHORIZED)

    ;; Record vote
    (map-set VotingRecords {
      voter: tx-sender,
      proposal-id: proposal-id,
    } {
      vote-cast: true,
      voting-power-used: voting-power,
    })

    ;; Update proposal vote counts
    (map-set GovernanceProposals { proposal-id: proposal-id }
      (merge proposal {
        votes-for: (if support
          (+ (get votes-for proposal) voting-power)
          (get votes-for proposal)
        ),
        votes-against: (if support
          (get votes-against proposal)
          (+ (get votes-against proposal) voting-power)
        ),
      })
    )

    (print {
      event: "vote-cast",
      proposal-id: proposal-id,
      voter: tx-sender,
      support: support,
    })
    (ok true)
  )
)

;; Administrative Functions --------------------------
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set contract-paused true)
    (print { event: "contract-paused" })
    (ok true)
  )
)

(define-public (resume-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set contract-paused false)
    (print { event: "contract-resumed" })
    (ok true)
  )
)

(define-public (update-yield-parameters
    (base-rate uint)
    (bonus-rate uint)
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (and (<= base-rate u2000) (<= bonus-rate u500)) ERR-INVALID-AMOUNT)
    (var-set base-yield-rate base-rate)
    (var-set tier-bonus-rate bonus-rate)
    (ok true)
  )
)

;; READ-ONLY FUNCTIONS

(define-read-only (get-staking-position (user principal))
  (map-get? StakingPositions user)
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? GovernanceProposals { proposal-id: proposal-id })
)

(define-read-only (get-protocol-stats)
  {
    total-stx-locked: (var-get total-stx-locked),
    proposal-count: (var-get proposal-counter),
    contract-paused: (var-get contract-paused),
    base-yield: (var-get base-yield-rate),
  }
)

(define-read-only (calculate-pending-rewards (user principal))
  (match (map-get? StakingPositions user)
    position (let ((blocks-elapsed (- stacks-block-height (get last-claim-height position))))
      (ok (calculate-staking-rewards position blocks-elapsed))
    )
    (err ERR-NO-POSITION)
  )
)

(define-read-only (get-user-voting-power (user principal))
  (match (map-get? StakingPositions user)
    position (ok (calculate-voting-power position))
    (err ERR-NO-POSITION)
  )
)

;; PRIVATE FUNCTIONS

(define-private (calculate-tier-level (stake-amount uint))
  (if (>= stake-amount u25000000)
    {
      tier-level: u4,
      reward-multiplier: u200,
    }
    (if (>= stake-amount u10000000)
      {
        tier-level: u3,
        reward-multiplier: u150,
      }
      (if (>= stake-amount u5000000)
        {
          tier-level: u2,
          reward-multiplier: u125,
        }
        {
          tier-level: u1,
          reward-multiplier: u100,
        }
      )
    )
  )
)

(define-private (calculate-lock-multiplier (lock-months uint))
  (if (>= lock-months u12) ;; 12+ months
    u175 ;; 75% bonus
    (if (>= lock-months u6) ;; 6+ months
      u150 ;; 50% bonus
      (if (>= lock-months u3) ;; 3+ months
        u125 ;; 25% bonus
        u100 ;; No bonus
      )
    )
  )
)

(define-private (calculate-staking-rewards
    (position {
      stx-amount: uint,
      stake-height: uint,
      last-claim-height: uint,
      lock-duration: uint,
      cooldown-initiated: (optional uint),
      accumulated-rewards: uint,
      tier-level: uint,
      reward-multiplier: uint,
    })
    (blocks uint)
  )
  (let (
      (base-rewards (/ (* (* (get stx-amount position) (var-get base-yield-rate)) blocks)
        u5256000
      )) ;; Blocks per year
      (multiplied-rewards (/ (* base-rewards (get reward-multiplier position)) u100))
    )
    multiplied-rewards
  )
)

(define-private (calculate-voting-power (position {
  stx-amount: uint,
  stake-height: uint,
  last-claim-height: uint,
  lock-duration: uint,
  cooldown-initiated: (optional uint),
  accumulated-rewards: uint,
  tier-level: uint,
  reward-multiplier: uint,
}))
  (let (
      (base-power (get stx-amount position))
      (tier-config (unwrap-panic (map-get? TierConfiguration (get tier-level position))))
      (governance-weight (get governance-weight tier-config))
    )
    (* base-power governance-weight)
  )
)

(define-private (blocks-from-months (months uint))
  (if (is-eq months u0)
    u0
    (* months u4320) ;; Approximate blocks per month
  )
)

(define-private (is-valid-lock-period (months uint))
  (or
    (is-eq months u0)
    (is-eq months u3)
    (is-eq months u6)
    (is-eq months u12)
    (is-eq months u24)
  )
)