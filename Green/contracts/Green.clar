;; Contract: Environmental Cleanup Initiative Smart Contract  
;; Description: A decentralised environmental cleanup contract on Stacks. The project coordinator sets a cleanup budget and timeline, community members donate funds, and cleanup zones are executed only if donors approve through voting. If the budget isn't met, donors can claim refunds.

;; Constants
(define-constant ERR_NOT_COORDINATOR (err u100))
(define-constant ERR_INITIATIVE_ALREADY_ACTIVE (err u101))
(define-constant ERR_DONOR_NOT_FOUND (err u102))
(define-constant ERR_CLEANUP_PERIOD_ENDED (err u103))
(define-constant ERR_FUNDING_GOAL_UNMET (err u104))
(define-constant ERR_INSUFFICIENT_CLEANUP_FUNDS (err u105))
(define-constant ERR_INVALID_DONATION_AMOUNT (err u106))
(define-constant ERR_INVALID_CLEANUP_DURATION (err u107))

;; Data Variables
(define-data-var project-coordinator (optional principal) none)
(define-data-var cleanup-budget uint u0)
(define-data-var donations-received uint u0)
(define-data-var current-zone uint u0)
(define-data-var support-votes uint u0)
(define-data-var opposition-votes uint u0)
(define-data-var total-donors uint u0)
(define-data-var cleanup-deadline uint u0)
(define-data-var initiative-status (string-ascii 20) "not_started")

;; Maps
(define-map donor-contributions principal uint)
(define-map cleanup-zones uint {location: (string-utf8 256), budget: uint})

;; Private Functions
(define-private (is-project-coordinator)
  (is-eq (some tx-sender) (var-get project-coordinator))
)

(define-private (is-cleanup-ongoing)
  (and
    (is-eq (var-get initiative-status) "active")
    (<= stacks-block-height (var-get cleanup-deadline))
  )
)

;; Public Functions
(define-public (start-cleanup-initiative (budget uint) (duration uint))
  (begin
    (asserts! (is-none (var-get project-coordinator)) ERR_INITIATIVE_ALREADY_ACTIVE)
    (asserts! (> budget u0) ERR_INVALID_DONATION_AMOUNT)
    (asserts! (and (> duration u0) (<= duration u52560)) ERR_INVALID_CLEANUP_DURATION)
    (var-set project-coordinator (some tx-sender))
    (var-set cleanup-budget budget)
    (var-set cleanup-deadline (+ stacks-block-height duration))
    (var-set initiative-status "active")
    (ok true)
  )
)

(define-public (donate-to-cleanup (amount uint))
  (let (
    (current-donation (default-to u0 (map-get? donor-contributions tx-sender)))
  )
    (asserts! (is-cleanup-ongoing) ERR_CLEANUP_PERIOD_ENDED)
    (asserts! (> amount u0) ERR_INVALID_DONATION_AMOUNT)
    (asserts! (<= (+ (var-get donations-received) amount) (var-get cleanup-budget)) ERR_FUNDING_GOAL_UNMET)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set donations-received (+ (var-get donations-received) amount))
    (map-set donor-contributions tx-sender (+ current-donation amount))
    (if (is-eq current-donation u0)
      (var-set total-donors (+ (var-get total-donors) u1))
      true
    )
    (ok true)
  )
)

(define-public (vote-on-zone (approve bool))
  (let ((donation (default-to u0 (map-get? donor-contributions tx-sender))))
    (asserts! (> donation u0) ERR_DONOR_NOT_FOUND)
    (asserts! (is-eq (var-get initiative-status) "community_review") ERR_NOT_COORDINATOR)
    (if approve
      (var-set support-votes (+ (var-get support-votes) donation))
      (var-set opposition-votes (+ (var-get opposition-votes) donation))
    )
    (ok true)
  )
)

(define-public (initiate-community-review)
  (begin
    (asserts! (is-project-coordinator) ERR_NOT_COORDINATOR)
    (asserts! (is-eq (var-get initiative-status) "active") ERR_NOT_COORDINATOR)
    (var-set initiative-status "community_review")
    (var-set support-votes u0)
    (var-set opposition-votes u0)
    (ok true)
  )
)

(define-public (conclude-community-review)
  (begin
    (asserts! (is-project-coordinator) ERR_NOT_COORDINATOR)
    (asserts! (is-eq (var-get initiative-status) "community_review") ERR_NOT_COORDINATOR)
    (let ((total-votes (+ (var-get support-votes) (var-get opposition-votes))))
      (asserts! (> total-votes u0) ERR_DONOR_NOT_FOUND)
      (if (> (var-get support-votes) (var-get opposition-votes))
        (begin
          (var-set current-zone (+ (var-get current-zone) u1))
          (var-set initiative-status "active")
          (ok true)
        )
        (begin
          (var-set initiative-status "active")
          (err u108)  ;; ERR_ZONE_REJECTED
        )
      )
    )
  )
)

(define-public (add-cleanup-zone (location (string-utf8 256)) (budget uint))
  (begin
    (asserts! (is-project-coordinator) ERR_NOT_COORDINATOR)
    (asserts! (> budget u0) ERR_INVALID_DONATION_AMOUNT)
    (asserts! (<= (len location) u256) (err u109))  ;; ERR_INVALID_LOCATION
    (map-set cleanup-zones (var-get current-zone) {location: location, budget: budget})
    (ok true)
  )
)

(define-public (release-cleanup-funds (amount uint))
  (begin
    (asserts! (is-project-coordinator) ERR_NOT_COORDINATOR)
    (asserts! (> amount u0) ERR_INVALID_DONATION_AMOUNT)
    (asserts! (<= amount (var-get donations-received)) ERR_INSUFFICIENT_CLEANUP_FUNDS)
    (as-contract (stx-transfer? amount tx-sender (unwrap! (var-get project-coordinator) ERR_DONOR_NOT_FOUND)))
  )
)

(define-public (request-donor-refund)
  (let ((donation (default-to u0 (map-get? donor-contributions tx-sender))))
    (asserts! (and
      (> stacks-block-height (var-get cleanup-deadline))
      (< (var-get donations-received) (var-get cleanup-budget))
    ) ERR_NOT_COORDINATOR)
    (asserts! (> donation u0) ERR_DONOR_NOT_FOUND)
    (map-delete donor-contributions tx-sender)
    (as-contract (stx-transfer? donation tx-sender tx-sender))
  )
)

;; Read-only Functions
(define-read-only (get-initiative-details)
  (ok {
    coordinator: (var-get project-coordinator),
    budget: (var-get cleanup-budget),
    received: (var-get donations-received),
    deadline: (var-get cleanup-deadline),
    status: (var-get initiative-status),
    current-zone: (var-get current-zone)
  })
)

(define-read-only (get-donor-contribution (donor principal))
  (ok (default-to u0 (map-get? donor-contributions donor)))
)

(define-read-only (get-zone-details (zone-id uint))
  (map-get? cleanup-zones zone-id)
)