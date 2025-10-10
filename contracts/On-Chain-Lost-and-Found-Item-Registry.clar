(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ITEM_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_CLAIMED (err u102))
(define-constant ERR_INVALID_STATUS (err u103))
(define-constant ERR_NOT_OWNER (err u104))
(define-constant ERR_DUPLICATE_ITEM (err u105))

(define-constant REPUTATION_SUCCESSFUL_CLAIM 10)
(define-constant REPUTATION_VERIFIED_SUBMISSION 5)
(define-constant REPUTATION_CANCELED_ITEM -3)
(define-constant REPUTATION_REJECTED_CLAIM -5)

(define-constant STATUS_LOST u1)
(define-constant STATUS_FOUND u2)
(define-constant STATUS_CLAIMED u3)
(define-constant STATUS_VERIFIED u4)

(define-data-var next-item-id uint u1)

(define-map items
  uint
  {
    owner: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    location: (string-ascii 128),
    status: uint,
    reward: uint,
    created-at: uint,
    claimed-by: (optional principal),
    verified: bool
  }
)

(define-map user-items principal (list 50 uint))

(define-read-only (get-item (item-id uint))
  (map-get? items item-id)
)

(define-read-only (get-user-items (user principal))
  (default-to (list) (map-get? user-items user))
)

(define-read-only (get-next-item-id)
  (var-get next-item-id)
)

(define-private (add-item-to-user (user principal) (item-id uint))
  (let ((current-items (default-to (list) (map-get? user-items user))))
    (ok (map-set user-items user (unwrap! (as-max-len? (append current-items item-id) u50) ERR_DUPLICATE_ITEM)))
  )
)

(define-public (submit-lost-item (title (string-ascii 64)) 
                                (description (string-ascii 256)) 
                                (location (string-ascii 128))
                                (reward uint))
  (let ((item-id (var-get next-item-id)))
    (map-set items item-id {
      owner: tx-sender,
      title: title,
      description: description,
      location: location,
      status: STATUS_LOST,
      reward: reward,
      created-at: stacks-block-height,
      claimed-by: none,
      verified: false
    })
    (try! (add-item-to-user tx-sender item-id))
    (var-set next-item-id (+ item-id u1))
    (ok item-id)
  )
)

(define-public (submit-found-item (title (string-ascii 64)) 
                                 (description (string-ascii 256)) 
                                 (location (string-ascii 128)))
  (let ((item-id (var-get next-item-id)))
    (map-set items item-id {
      owner: tx-sender,
      title: title,
      description: description,
      location: location,
      status: STATUS_FOUND,
      reward: u0,
      created-at: stacks-block-height,
      claimed-by: none,
      verified: false
    })
    (try! (add-item-to-user tx-sender item-id))
    (var-set next-item-id (+ item-id u1))
    (ok item-id)
  )
)

(define-public (claim-item (item-id uint))
  (let ((item (unwrap! (map-get? items item-id) ERR_ITEM_NOT_FOUND)))
    (asserts! (or (is-eq (get status item) STATUS_LOST) 
                  (is-eq (get status item) STATUS_FOUND)) ERR_INVALID_STATUS)
    (asserts! (is-none (get claimed-by item)) ERR_ALREADY_CLAIMED)
    (asserts! (not (is-eq tx-sender (get owner item))) ERR_NOT_AUTHORIZED)
    (map-set items item-id (merge item {
      claimed-by: (some tx-sender),
      status: STATUS_CLAIMED
    }))
    (try! (add-item-to-user tx-sender item-id))
    (ok true)
  )
)

(define-public (verify-claim (item-id uint) (approve bool))
  (let ((item (unwrap! (map-get? items item-id) ERR_ITEM_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner item)) ERR_NOT_OWNER)
    (asserts! (is-eq (get status item) STATUS_CLAIMED) ERR_INVALID_STATUS)
    (if approve
      (begin
        (map-set items item-id (merge item {
          status: STATUS_VERIFIED,
          verified: true
        }))
        (if (> (get reward item) u0)
          (stx-transfer? (get reward item) tx-sender (unwrap! (get claimed-by item) ERR_ITEM_NOT_FOUND))
          (ok true)
        )
      )
      (begin
        (map-set items item-id (merge item {
          claimed-by: none,
          status: (if (is-eq (get status item) STATUS_LOST) STATUS_LOST STATUS_FOUND)
        }))
        (ok false)
      )
    )
  )
)

(define-public (update-item (item-id uint) 
                           (title (string-ascii 64)) 
                           (description (string-ascii 256)) 
                           (location (string-ascii 128)))
  (let ((item (unwrap! (map-get? items item-id) ERR_ITEM_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner item)) ERR_NOT_OWNER)
    (asserts! (or (is-eq (get status item) STATUS_LOST) 
                  (is-eq (get status item) STATUS_FOUND)) ERR_INVALID_STATUS)
    (map-set items item-id (merge item {
      title: title,
      description: description,
      location: location
    }))
    (ok true)
  )
)

(define-public (cancel-item (item-id uint))
  (let ((item (unwrap! (map-get? items item-id) ERR_ITEM_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner item)) ERR_NOT_OWNER)
    (asserts! (is-none (get claimed-by item)) ERR_ALREADY_CLAIMED)
    (map-delete items item-id)
    (ok true)
  )
)

(define-read-only (get-items-by-status (status uint))
  (list)
)


(define-map user-reputation
  principal
  {
    score: int,
    successful-claims: uint,
    verified-submissions: uint,
    rejected-claims: uint,
    total-submissions: uint
  }
)

(define-private (get-user-rep (user principal))
  (default-to 
    {score: 0, successful-claims: u0, verified-submissions: u0, rejected-claims: u0, total-submissions: u0}
    (map-get? user-reputation user)
  )
)

(define-private (update-reputation (user principal) (score-change int) (stat-type (string-ascii 20)))
  (let ((current-rep (get-user-rep user)))
    (map-set user-reputation user
      (merge current-rep
        {
          score: (+ (get score current-rep) score-change),
          successful-claims: (if (is-eq stat-type "claim") (+ (get successful-claims current-rep) u1) (get successful-claims current-rep)),
          verified-submissions: (if (is-eq stat-type "verify") (+ (get verified-submissions current-rep) u1) (get verified-submissions current-rep)),
          rejected-claims: (if (is-eq stat-type "reject") (+ (get rejected-claims current-rep) u1) (get rejected-claims current-rep)),
          total-submissions: (if (is-eq stat-type "submit") (+ (get total-submissions current-rep) u1) (get total-submissions current-rep))
        }
      )
    )
  )
)

(define-read-only (get-reputation (user principal))
  (get-user-rep user)
)

(define-read-only (get-reputation-score (user principal))
  (get score (get-user-rep user))
)

(define-read-only (get-reputation-level (user principal))
  (let ((score (get score (get-user-rep user))))
    (if (>= score 100) "Expert"
      (if (>= score 50) "Trusted" 
        (if (>= score 20) "Reliable"
          (if (>= score 0) "Newcomer" "Untrustworthy")
        )
      )
    )
  )
)

(define-public (submit-lost-item-with-rep (title (string-ascii 64)) (description (string-ascii 256)) (location (string-ascii 128)) (reward uint))
  (begin
    (try! (submit-lost-item title description location reward))
    (update-reputation tx-sender 0 "submit")
    (ok (- (var-get next-item-id) u1))
  )
)

(define-public (verify-claim-with-rep (item-id uint) (approve bool))
  (let ((item (unwrap! (map-get? items item-id) ERR_ITEM_NOT_FOUND))
        (claimer (unwrap! (get claimed-by item) ERR_ITEM_NOT_FOUND)))
    (try! (verify-claim item-id approve))
    (if approve
      (begin
        (update-reputation claimer REPUTATION_SUCCESSFUL_CLAIM "claim")
        (update-reputation tx-sender REPUTATION_VERIFIED_SUBMISSION "verify")
      )
      (update-reputation claimer REPUTATION_REJECTED_CLAIM "reject")
    )
    (ok approve)
  )
)

(define-public (cancel-item-with-rep (item-id uint))
  (begin
    (try! (cancel-item item-id))
    (update-reputation tx-sender REPUTATION_CANCELED_ITEM "cancel")
    (ok true)
  )
)