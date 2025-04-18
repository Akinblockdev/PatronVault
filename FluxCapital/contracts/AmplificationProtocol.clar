;; Error Codes
(define-constant ACCESS-DENIED (err u301))
(define-constant RECIPIENT-NOT-FOUND (err u302))
(define-constant INVALID-ZERO-VALUE (err u303))
(define-constant FUNDS-SHORTAGE (err u304))
(define-constant MAX-MATCH-EXCEEDED (err u305))
(define-constant CONTRACT-FROZEN (err u306))
(define-constant ENTITY-EXISTS (err u307))
(define-constant INVALID-MULTIPLIER (err u308))
(define-constant PATRON-RESTRICTED (err u309))
(define-constant GOVERNANCE-RESTRICTED (err u310))
(define-constant TIME-EXPIRED (err u311))
(define-constant LIVE-PROJECT-EXISTS (err u312))

;; State Variables
(define-data-var governance-steward principal tx-sender)
(define-data-var vault-locked bool false)
(define-data-var initiative-running bool false)
(define-data-var sunset-blockheight uint u0)
(define-data-var patron-entity principal tx-sender)
(define-data-var amplification-factor uint u100) ;; Represented as percentage (100 = 1:1)
(define-data-var patron-ceiling uint u0)
(define-data-var amplified-amount uint u0)
(define-data-var contribution-volume uint u0)

;; Ledger Storage
(define-map contributors principal uint)
(define-map recipients {entity-address: principal} {verified: bool, allocated-sum: uint})
(define-map treasury-allocations principal uint)

;; Internal Functions
(define-private (has-governance-rights)
  (is-eq tx-sender (var-get governance-steward)))

(define-private (is-patron)
  (is-eq tx-sender (var-get patron-entity)))

(define-private (is-vault-operational)
  (and 
    (var-get initiative-running)
    (not (var-get vault-locked))
    (<= block-height (var-get sunset-blockheight))))

(define-private (compute-amplification (contribution-value uint))
  (let
    (
      (amplified-value (/ (* contribution-value (var-get amplification-factor)) u100))
      (available-amplification (- (var-get patron-ceiling) (var-get amplified-amount)))
    )
    (if (> amplified-value available-amplification)
      available-amplification
      amplified-value)
  )
)

(define-private (is-recipient-verified (recipient principal))
  (default-to 
    false 
    (get verified (map-get? recipients {entity-address: recipient}))
  )
)

(define-private (credit-treasury (entity principal) (value uint))
  (let
    (
      (current-allocation (default-to u0 (map-get? treasury-allocations entity)))
    )
    (map-set treasury-allocations entity (+ current-allocation value))
  )
)

;; Public Functions

;; Admin Functions
(define-public (transfer-stewardship (new-steward principal))
  (begin
    (asserts! (has-governance-rights) ACCESS-DENIED)
    (ok (var-set governance-steward new-steward))
  )
)

(define-public (freeze-vault)
  (begin
    (asserts! (has-governance-rights) ACCESS-DENIED)
    (ok (var-set vault-locked true))
  )
)

(define-public (activate-vault)
  (begin
    (asserts! (has-governance-rights) ACCESS-DENIED)
    (ok (var-set vault-locked false))
  )
)

(define-public (whitelist-recipient (recipient principal))
  (begin
    (asserts! (has-governance-rights) ACCESS-DENIED)
    (asserts! (is-none (map-get? recipients {entity-address: recipient})) ENTITY-EXISTS)
    (map-set recipients {entity-address: recipient} {verified: true, allocated-sum: u0})
    (ok true)
  )
)

(define-public (delist-recipient (recipient principal))
  (begin
    (asserts! (has-governance-rights) ACCESS-DENIED)
    (asserts! (is-some (map-get? recipients {entity-address: recipient})) RECIPIENT-NOT-FOUND)
    (map-set recipients {entity-address: recipient} {verified: false, allocated-sum: u0})
    (ok true)
  )
)

;; Initiative Management Functions
(define-public (launch-initiative (patron principal) (multiplier uint) (ceiling uint) (expiration uint))
  (begin
    (asserts! (has-governance-rights) GOVERNANCE-RESTRICTED)
    (asserts! (not (var-get initiative-running)) LIVE-PROJECT-EXISTS)
    (asserts! (> multiplier u0) INVALID-MULTIPLIER)
    (asserts! (> ceiling u0) INVALID-ZERO-VALUE)
    (asserts! (> expiration block-height) TIME-EXPIRED)
    
    (var-set initiative-running true)
    (var-set patron-entity patron)
    (var-set amplification-factor multiplier)
    (var-set patron-ceiling ceiling)
    (var-set sunset-blockheight expiration)
    (var-set amplified-amount u0)
    (var-set contribution-volume u0)
    
    (ok true)
  )
)

(define-public (conclude-initiative)
  (begin
    (asserts! (or (has-governance-rights) (is-patron)) ACCESS-DENIED)
    (asserts! (var-get initiative-running) CONTRACT-FROZEN)
    
    (var-set initiative-running false)
    
    (ok true)
  )
)

;; Treasury Functions
(define-public (deposit-patron-funds (value uint))
  (begin
    (asserts! (is-patron) PATRON-RESTRICTED)
    (asserts! (> value u0) INVALID-ZERO-VALUE)
    
    (try! (stx-transfer? value tx-sender (as-contract tx-sender)))
    (credit-treasury (var-get patron-entity) value)
    
    (ok true)
  )
)

(define-public (contribute (value uint))
  (begin
    (asserts! (is-vault-operational) CONTRACT-FROZEN)
    (asserts! (> value u0) INVALID-ZERO-VALUE)
    
    (try! (stx-transfer? value tx-sender (as-contract tx-sender)))
    
    (let
      (
        (amplified-value (compute-amplification value))
        (contributor-total (default-to u0 (map-get? contributors tx-sender)))
      )
      
      ;; Record contribution
      (map-set contributors tx-sender (+ contributor-total value))
      
      ;; Update totals
      (var-set contribution-volume (+ (var-get contribution-volume) value))
      
      ;; Apply amplification if possible
      (if (and (> amplified-value u0) (<= (+ (var-get amplified-amount) amplified-value) (var-get patron-ceiling)))
        (begin
          (var-set amplified-amount (+ (var-get amplified-amount) amplified-value))
          (ok true)
        )
        (ok true)
      )
    )
  )
)

(define-public (disburse-funds (recipient principal) (value uint))
  (begin
    (asserts! (or (has-governance-rights) (is-patron)) ACCESS-DENIED)
    (asserts! (not (var-get vault-locked)) CONTRACT-FROZEN)
    (asserts! (is-recipient-verified recipient) RECIPIENT-NOT-FOUND)
    (asserts! (> value u0) INVALID-ZERO-VALUE)
    
    (let
      (
        (vault-balance (stx-get-balance (as-contract tx-sender)))
        (recipient-data (map-get? recipients {entity-address: recipient}))
      )
      
      (asserts! (>= vault-balance value) FUNDS-SHORTAGE)
      (asserts! (is-some recipient-data) RECIPIENT-NOT-FOUND)
      
      ;; Update recipient records using unwrap-panic since we already verified recipient exists
      (let
        ((data (unwrap-panic recipient-data)))
        (map-set recipients 
                {entity-address: recipient} 
                {verified: (get verified data), 
                 allocated-sum: (+ (get allocated-sum data) value)})
      )
      
      ;; Execute transfer
      (try! (as-contract (stx-transfer? value tx-sender recipient)))
      
      (ok true)
    )
  )
)

;; Query Functions
(define-read-only (fetch-contributor-record (contributor principal))
  (default-to u0 (map-get? contributors contributor))
)

(define-read-only (fetch-recipient-data (recipient principal))
  (map-get? recipients {entity-address: recipient})
)

(define-read-only (fetch-initiative-metrics)
  {
    steward: (var-get governance-steward),
    status: (var-get initiative-running),
    frozen: (var-get vault-locked),
    expiration: (var-get sunset-blockheight),
    patron: (var-get patron-entity),
    amplifier: (var-get amplification-factor),
    max-amplification: (var-get patron-ceiling),
    current-amplified: (var-get amplified-amount),
    total-contributions: (var-get contribution-volume),
    remaining-amplification: (- (var-get patron-ceiling) (var-get amplified-amount))
  }
)

(define-read-only (fetch-vault-balance)
  (stx-get-balance (as-contract tx-sender))
)