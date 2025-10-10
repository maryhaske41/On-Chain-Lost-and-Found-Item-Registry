(define-constant ERR_NO_MATCHES (err u200))
(define-constant ERR_INVALID_ITEM (err u201))

(define-constant TITLE_WEIGHT u40)
(define-constant LOCATION_WEIGHT u35)
(define-constant TIME_WEIGHT u25)
(define-constant MIN_MATCH_SCORE u50)

(define-map match-scores 
  {lost-item: uint, found-item: uint}
  uint
)

(define-map cached-matches uint (list 10 uint))

(define-private (string-similarity (str1 (string-ascii 64)) (str2 (string-ascii 64)))
  (let ((len1 (len str1))
        (len2 (len str2)))
    (if (and (> len1 u0) (> len2 u0))
      (if (is-eq str1 str2)
        u100
        (let ((min-len (if (< len1 len2) len1 len2))
              (max-len (if (> len1 len2) len1 len2)))
          (/ (* min-len u100) max-len)
        )
      )
      u0
    )
  )
)

(define-private (location-proximity (loc1 (string-ascii 128)) (loc2 (string-ascii 128)))
  (let ((similarity (string-similarity (unwrap-panic (as-max-len? loc1 u64)) 
                                      (unwrap-panic (as-max-len? loc2 u64)))))
    (* similarity u2)
  )
)

(define-private (time-overlap (time1 uint) (time2 uint))
  (let ((time-diff (if (> time1 time2) (- time1 time2) (- time2 time1))))
    (if (< time-diff u144)
      (- u100 time-diff)
      u0
    )
  )
)

(define-private (calculate-match-score (lost-item-data {owner: principal, title: (string-ascii 64), description: (string-ascii 256), location: (string-ascii 128), status: uint, reward: uint, created-at: uint, claimed-by: (optional principal), verified: bool})
                                      (found-item-data {owner: principal, title: (string-ascii 64), description: (string-ascii 256), location: (string-ascii 128), status: uint, reward: uint, created-at: uint, claimed-by: (optional principal), verified: bool}))
  (let ((title-score (string-similarity (get title lost-item-data) (get title found-item-data)))
        (location-score (location-proximity (get location lost-item-data) (get location found-item-data)))
        (time-score (time-overlap (get created-at lost-item-data) (get created-at found-item-data))))
    (/ (+ (* title-score TITLE_WEIGHT) (* location-score LOCATION_WEIGHT) (* time-score TIME_WEIGHT)) 
       (+ TITLE_WEIGHT LOCATION_WEIGHT TIME_WEIGHT))
  )
)

(define-read-only (get-potential-matches (item-id uint))
  (default-to (list) (map-get? cached-matches item-id))
)

(define-public (calculate-and-store-match (lost-item-id uint) (found-item-id uint))
  (let ((lost-item (unwrap! (contract-call? .On-Chain-Lost-and-Found-Item-Registry get-item lost-item-id) ERR_INVALID_ITEM))
        (found-item (unwrap! (contract-call? .On-Chain-Lost-and-Found-Item-Registry get-item found-item-id) ERR_INVALID_ITEM)))
    (asserts! (is-eq (get status lost-item) u1) ERR_INVALID_ITEM)
    (asserts! (is-eq (get status found-item) u2) ERR_INVALID_ITEM)
    (let ((score (calculate-match-score lost-item found-item)))
      (map-set match-scores {lost-item: lost-item-id, found-item: found-item-id} score)
      (if (>= score MIN_MATCH_SCORE)
        (let ((current-matches (default-to (list) (map-get? cached-matches lost-item-id))))
          (map-set cached-matches lost-item-id (unwrap-panic (as-max-len? (append current-matches found-item-id) u10)))
          (ok score)
        )
        (ok score)
      )
    )
  )
)

(define-read-only (get-match-score (lost-item-id uint) (found-item-id uint))
  (default-to u0 (map-get? match-scores {lost-item: lost-item-id, found-item: found-item-id}))
)
