(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ITEM_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_CLAIMED (err u102))
(define-constant ERR_INVALID_STATUS (err u103))
(define-constant ERR_NOT_OWNER (err u104))
(define-constant ERR_DUPLICATE_ITEM (err u105))

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