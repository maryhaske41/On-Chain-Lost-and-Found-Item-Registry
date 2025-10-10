(define-constant ERR_ITEM_NOT_FOUND (err u300))
(define-constant ERR_ALREADY_WITNESSED (err u301))
(define-constant ERR_INVALID_WITNESS (err u302))
(define-constant ERR_SELF_WITNESS (err u303))
(define-constant MIN_WITNESSES_FOR_AUTO_VERIFY u3)

(define-map item-witnesses
  {item-id: uint, witness: principal}
  {
    statement: (string-ascii 256),
    credibility-score: uint,
    timestamp: uint,
    verified: bool
  }
)

(define-map witness-counts uint uint)

(define-map witness-credibility
  principal
  {
    total-correct: uint,
    total-incorrect: uint,
    score: uint
  }
)

(define-private (get-witness-cred (witness principal))
  (default-to 
    {total-correct: u0, total-incorrect: u0, score: u50}
    (map-get? witness-credibility witness)
  )
)

(define-private (calculate-witness-score (correct uint) (incorrect uint))
  (let ((total (+ correct incorrect)))
    (if (is-eq total u0)
      u50
      (/ (* correct u100) total)
    )
  )
)

(define-public (add-witness-statement (item-id uint) (statement (string-ascii 256)))
  (let ((item (unwrap! (contract-call? .On-Chain-Lost-and-Found-Item-Registry get-item item-id) ERR_ITEM_NOT_FOUND))
        (witness-key {item-id: item-id, witness: tx-sender})
        (current-count (default-to u0 (map-get? witness-counts item-id)))
        (witness-cred (get-witness-cred tx-sender)))
    (asserts! (is-none (map-get? item-witnesses witness-key)) ERR_ALREADY_WITNESSED)
    (asserts! (not (is-eq tx-sender (get owner item))) ERR_SELF_WITNESS)
    (map-set item-witnesses witness-key {
      statement: statement,
      credibility-score: (get score witness-cred),
      timestamp: stacks-block-height,
      verified: false
    })
    (map-set witness-counts item-id (+ current-count u1))
    (ok true)
  )
)

(define-public (verify-witness (item-id uint) (witness principal) (is-correct bool))
  (let ((item (unwrap! (contract-call? .On-Chain-Lost-and-Found-Item-Registry get-item item-id) ERR_ITEM_NOT_FOUND))
        (witness-key {item-id: item-id, witness: witness})
        (witness-data (unwrap! (map-get? item-witnesses witness-key) ERR_INVALID_WITNESS))
        (witness-cred (get-witness-cred witness)))
    (asserts! (is-eq tx-sender (get owner item)) ERR_INVALID_WITNESS)
    (map-set item-witnesses witness-key (merge witness-data {verified: true}))
    (map-set witness-credibility witness {
      total-correct: (if is-correct (+ (get total-correct witness-cred) u1) (get total-correct witness-cred)),
      total-incorrect: (if is-correct (get total-incorrect witness-cred) (+ (get total-incorrect witness-cred) u1)),
      score: (calculate-witness-score 
               (if is-correct (+ (get total-correct witness-cred) u1) (get total-correct witness-cred))
               (if is-correct (get total-incorrect witness-cred) (+ (get total-incorrect witness-cred) u1)))
    })
    (ok true)
  )
)

(define-read-only (get-witness-statement (item-id uint) (witness principal))
  (map-get? item-witnesses {item-id: item-id, witness: witness})
)

(define-read-only (get-witness-count (item-id uint))
  (default-to u0 (map-get? witness-counts item-id))
)

(define-read-only (get-witness-credibility-score (witness principal))
  (get score (get-witness-cred witness))
)

(define-read-only (should-auto-verify (item-id uint))
  (>= (default-to u0 (map-get? witness-counts item-id)) MIN_WITNESSES_FOR_AUTO_VERIFY)
)
