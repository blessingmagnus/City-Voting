;; Community-Driven Urban Planning Smart Contract
;; This contract enables residents to propose and vote on local infrastructure projects

;; Error constants
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-PROJECT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-PROJECT-STATUS (err u102))
(define-constant ERR-VOTING-PERIOD-EXPIRED (err u103))
(define-constant ERR-VOTING-PERIOD-ACTIVE (err u104))
(define-constant ERR-ALREADY-VOTED (err u105))
(define-constant ERR-INSUFFICIENT-FUNDS (err u106))
(define-constant ERR-INVALID-AMOUNT (err u107))
(define-constant ERR-NOT-ELIGIBLE-VOTER (err u108))
(define-constant ERR-INVALID-VOTING-PERIOD (err u109))
(define-constant ERR-PROJECT-ALREADY-EXECUTED (err u110))
(define-constant ERR-QUORUM-NOT-MET (err u111))

;; Status constants for project states
(define-constant STATUS-PROPOSED u0)
(define-constant STATUS-VOTING u1)
(define-constant STATUS-APPROVED u2)
(define-constant STATUS-REJECTED u3)
(define-constant STATUS-EXECUTED u4)

;; Validation constants
(define-constant MIN-VOTING-PERIOD u144) ;; Minimum 144 blocks (approximately 24 hours)
(define-constant MAX-VOTING-PERIOD u1008) ;; Maximum 1008 blocks (approximately 1 week)
(define-constant MIN-PROPOSAL-AMOUNT u1000000) ;; Minimum 1 STX in microSTX
(define-constant QUORUM-PERCENTAGE u20) ;; 20% quorum requirement

;; Contract owner and administrative functions
(define-data-var contract-owner principal tx-sender)
(define-data-var next-project-id uint u1)
(define-data-var total-registered-voters uint u0)
(define-data-var voting-token-required uint u1000000) ;; 1 STX worth of tokens required to vote

;; Data structures for projects
(define-map projects
  uint ;; project-id
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    budget: uint,
    voting-start: uint,
    voting-end: uint,
    votes-for: uint,
    votes-against: uint,
    total-voters: uint,
    status: uint,
    created-at: uint
  }
)

;; Track individual votes to prevent double voting
(define-map project-votes
  {project-id: uint, voter: principal}
  {vote: bool, voted-at: uint}
)

;; Registered voters with their stake/weight
(define-map registered-voters
  principal
  {
    stake: uint,
    registration-date: uint,
    is-active: bool
  }
)

;; Project funding contributions
(define-map project-contributions
  {project-id: uint, contributor: principal}
  uint
)

;; Helper function to check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Helper function to get current block height
(define-private (get-current-block)
  block-height
)

;; Helper function to check if voter is eligible
(define-private (is-eligible-voter (voter principal))
  (match (map-get? registered-voters voter)
    voter-data (and 
      (get is-active voter-data)
      (>= (get stake voter-data) (var-get voting-token-required))
    )
    false
  )
)

;; Helper function to calculate quorum requirement
(define-private (calculate-quorum)
  (/ (* (var-get total-registered-voters) QUORUM-PERCENTAGE) u100)
)

;; Register as a voter with required stake
(define-public (register-voter (stake-amount uint))
  (begin
    (asserts! (>= stake-amount (var-get voting-token-required)) ERR-INSUFFICIENT-FUNDS)
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    (map-set registered-voters tx-sender {
      stake: stake-amount,
      registration-date: (get-current-block),
      is-active: true
    })
    (var-set total-registered-voters (+ (var-get total-registered-voters) u1))
    (ok true)
  )
)

;; Update voter stake
(define-public (update-voter-stake (additional-stake uint))
  (let ((current-voter (unwrap! (map-get? registered-voters tx-sender) ERR-NOT-ELIGIBLE-VOTER)))
    (asserts! (> additional-stake u0) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? additional-stake tx-sender (as-contract tx-sender)))
    (map-set registered-voters tx-sender 
      (merge current-voter {stake: (+ (get stake current-voter) additional-stake)})
    )
    (ok true)
  )
)

;; Deactivate voter (admin only)
(define-public (deactivate-voter (voter principal))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (match (map-get? registered-voters voter)
      voter-data (begin
        (map-set registered-voters voter (merge voter-data {is-active: false}))
        (var-set total-registered-voters (- (var-get total-registered-voters) u1))
        (ok true)
      )
      ERR-NOT-ELIGIBLE-VOTER
    )
  )
)

;; Propose a new infrastructure project
(define-public (propose-project 
  (title (string-ascii 100)) 
  (description (string-ascii 500)) 
  (budget uint)
  (voting-period uint)
)
  (let ((project-id (var-get next-project-id))
        (current-block (get-current-block)))
    (asserts! (is-eligible-voter tx-sender) ERR-NOT-ELIGIBLE-VOTER)
    (asserts! (>= budget MIN-PROPOSAL-AMOUNT) ERR-INVALID-AMOUNT)
    (asserts! (and (>= voting-period MIN-VOTING-PERIOD) (<= voting-period MAX-VOTING-PERIOD)) ERR-INVALID-VOTING-PERIOD)
    
    (map-set projects project-id {
      proposer: tx-sender,
      title: title,
      description: description,
      budget: budget,
      voting-start: u0,
      voting-end: u0,
      votes-for: u0,
      votes-against: u0,
      total-voters: u0,
      status: STATUS-PROPOSED,
      created-at: current-block
    })
    
    (var-set next-project-id (+ project-id u1))
    (ok project-id)
  )
)

;; Start voting period for a project (admin only)
(define-public (start-voting (project-id uint) (voting-period uint))
  (let ((project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND))
        (current-block (get-current-block)))
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get status project) STATUS-PROPOSED) ERR-INVALID-PROJECT-STATUS)
    (asserts! (and (>= voting-period MIN-VOTING-PERIOD) (<= voting-period MAX-VOTING-PERIOD)) ERR-INVALID-VOTING-PERIOD)
    
    (map-set projects project-id 
      (merge project {
        voting-start: current-block,
        voting-end: (+ current-block voting-period),
        status: STATUS-VOTING
      })
    )
    (ok true)
  )
)

;; Cast vote on a project
(define-public (vote-on-project (project-id uint) (vote-for bool))
  (let ((project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND))
        (current-block (get-current-block))
        (vote-key {project-id: project-id, voter: tx-sender}))
    
    (asserts! (is-eligible-voter tx-sender) ERR-NOT-ELIGIBLE-VOTER)
    (asserts! (is-eq (get status project) STATUS-VOTING) ERR-INVALID-PROJECT-STATUS)
    (asserts! (<= current-block (get voting-end project)) ERR-VOTING-PERIOD-EXPIRED)
    (asserts! (>= current-block (get voting-start project)) ERR-VOTING-PERIOD-EXPIRED)
    (asserts! (is-none (map-get? project-votes vote-key)) ERR-ALREADY-VOTED)
    
    ;; Record the vote
    (map-set project-votes vote-key {
      vote: vote-for,
      voted-at: current-block
    })
    
    ;; Update project vote counts
    (if vote-for
      (map-set projects project-id 
        (merge project {
          votes-for: (+ (get votes-for project) u1),
          total-voters: (+ (get total-voters project) u1)
        })
      )
      (map-set projects project-id 
        (merge project {
          votes-against: (+ (get votes-against project) u1),
          total-voters: (+ (get total-voters project) u1)
        })
      )
    )
    (ok true)
  )
)

;; Finalize voting and determine project outcome
(define-public (finalize-voting (project-id uint))
  (let ((project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND))
        (current-block (get-current-block))
        (required-quorum (calculate-quorum)))
    
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get status project) STATUS-VOTING) ERR-INVALID-PROJECT-STATUS)
    (asserts! (> current-block (get voting-end project)) ERR-VOTING-PERIOD-ACTIVE)
    (asserts! (>= (get total-voters project) required-quorum) ERR-QUORUM-NOT-MET)
    
    (let ((new-status (if (> (get votes-for project) (get votes-against project))
                        STATUS-APPROVED
                        STATUS-REJECTED)))
      (map-set projects project-id (merge project {status: new-status}))
      (ok new-status)
    )
  )
)

;; Contribute funds to an approved project
(define-public (contribute-to-project (project-id uint) (amount uint))
  (let ((project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND))
        (contribution-key {project-id: project-id, contributor: tx-sender}))
    
    (asserts! (is-eq (get status project) STATUS-APPROVED) ERR-INVALID-PROJECT-STATUS)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (match (map-get? project-contributions contribution-key)
      existing-contribution 
        (map-set project-contributions contribution-key (+ existing-contribution amount))
      (map-set project-contributions contribution-key amount)
    )
    (ok true)
  )
)

;; Execute approved project (admin only)
(define-public (execute-project (project-id uint) (recipient principal))
  (let ((project (unwrap! (map-get? projects project-id) ERR-PROJECT-NOT-FOUND)))
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq (get status project) STATUS-APPROVED) ERR-INVALID-PROJECT-STATUS)
    
    (try! (as-contract (stx-transfer? (get budget project) tx-sender recipient)))
    
    (map-set projects project-id (merge project {status: STATUS-EXECUTED}))
    (ok true)
  )
)

;; Read-only functions for querying project data

;; Get project details
(define-read-only (get-project (project-id uint))
  (map-get? projects project-id)
)

;; Get vote for specific project and voter
(define-read-only (get-vote (project-id uint) (voter principal))
  (map-get? project-votes {project-id: project-id, voter: voter})
)

;; Get voter information
(define-read-only (get-voter-info (voter principal))
  (map-get? registered-voters voter)
)

;; Get project contribution by contributor
(define-read-only (get-project-contribution (project-id uint) (contributor principal))
  (default-to u0 (map-get? project-contributions {project-id: project-id, contributor: contributor}))
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-projects: (- (var-get next-project-id) u1),
    total-voters: (var-get total-registered-voters),
    voting-token-required: (var-get voting-token-required),
    contract-owner: (var-get contract-owner)
  }
)

;; Check if voting period is active for a project
(define-read-only (is-voting-active (project-id uint))
  (match (map-get? projects project-id)
    project (let ((current-block (get-current-block)))
      (and 
        (is-eq (get status project) STATUS-VOTING)
        (>= current-block (get voting-start project))
        (<= current-block (get voting-end project))
      )
    )
    false
  )
)

;; Get voting results for a project
(define-read-only (get-voting-results (project-id uint))
  (match (map-get? projects project-id)
    project (some {
      votes-for: (get votes-for project),
      votes-against: (get votes-against project),
      total-voters: (get total-voters project),
      quorum-met: (>= (get total-voters project) (calculate-quorum)),
      status: (get status project)
    })
    none
  )
)

;; Administrative functions

;; Update contract owner (current owner only)
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Update voting token requirement (admin only)
(define-public (set-voting-token-requirement (new-amount uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> new-amount u0) ERR-INVALID-AMOUNT)
    (var-set voting-token-required new-amount)
    (ok true)
  )
)