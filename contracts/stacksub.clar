;; stacksub.clar
;; A decentralized recurring subscription contract for the Stacks blockchain

;; ----------------------------------
;; ERRORS
;; ----------------------------------
(define-constant ERR_NOT_OWNER u100)
(define-constant ERR_INVALID_AMOUNT u101)
(define-constant ERR_SUBSCRIPTION_EXPIRED u102)
(define-constant ERR_ALREADY_ACTIVE u103)
(define-constant ERR_NO_SUBSCRIPTION u104)
(define-constant ERR_NOT_SUBSCRIBER u105)

;; ----------------------------------
;; DATA STORAGE
;; ----------------------------------
(define-data-var owner principal tx-sender)
(define-data-var next-plan-id uint u0)
(define-data-var total-subscribers uint u0)

(define-map plans
  uint
  (tuple
    (creator principal)
    (name (string-ascii 64))
    (price uint)
    (duration uint) ;; in blocks
    (active bool)
  )
)

(define-map subscriptions
  (tuple (plan-id uint) (subscriber principal))
  (tuple
    (start-block uint)
    (end-block uint)
    (active bool)
    (total-paid uint)
  )
)

;; ----------------------------------
;; EVENTS (Emitted via contract execution)
;; ----------------------------------
;; plan-created: (id uint) (creator principal)
;; subscribed: (plan-id uint) (subscriber principal) (end-block uint)
;; renewed: (plan-id uint) (subscriber principal)
;; canceled: (plan-id uint) (subscriber principal)
;; withdrawn: (creator principal) (amount uint)

;; ----------------------------------
;; PRIVATE FUNCTIONS
;; ----------------------------------

(define-private (only-owner)
  (if (is-eq tx-sender (var-get owner))
      (ok true)
      (err ERR_NOT_OWNER))
)

;; ----------------------------------
;; PUBLIC FUNCTIONS
;; ----------------------------------

;; (1) Create a new subscription plan
(define-public (create-plan (name (string-ascii 64)) (price uint) (duration uint))
  (if (and (> price u0) (> duration u0))
      (let ((id (+ (var-get next-plan-id) u1)))
        (begin
          (map-set plans id
            {
              creator: tx-sender,
              name: name,
              price: price,
              duration: duration,
              active: true
            })
          (var-set next-plan-id id)
          ;; emit-event: plan-created with id and creator
          (ok {plan-id: id, price: price, duration: duration})))
      (err ERR_INVALID_AMOUNT))
)

;; (2) Subscribe to a plan
(define-public (subscribe (plan-id uint) (amount uint))
  (if (>= plan-id u0)
    (let ((plan (map-get? plans plan-id)))
      (match plan
        p
          (if (get active p)
              (if (>= amount (get price p))
                  (let (
                        (start u0)
                        (end (+ u1000 (get duration p)))
                      )
                    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
                    (map-set subscriptions {plan-id: plan-id, subscriber: tx-sender}
                      {start-block: start, end-block: end, active: true, total-paid: amount})
                    (var-set total-subscribers (+ (var-get total-subscribers) u1))
                    ;; emit-event: subscribed with plan-id, subscriber, and end-block
                    (ok {status: "subscribed", plan: plan-id, expires: end}))
                  (err ERR_INVALID_AMOUNT))
              (err ERR_INVALID_AMOUNT))
        (err ERR_NO_SUBSCRIPTION)))
    (err ERR_INVALID_AMOUNT))
)

;; (3) Renew subscription (manual payment)
(define-public (renew (plan-id uint) (amount uint))
  (if (>= plan-id u0)
    (let (
          (sub (map-get? subscriptions {plan-id: plan-id, subscriber: tx-sender}))
          (plan (map-get? plans plan-id))
         )
      (match plan
        p
          (match sub
            s
              (if (>= amount (get price p))
                  (let ((new-end (+ (get end-block s) (get duration p))))
                    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
                    (map-set subscriptions {plan-id: plan-id, subscriber: tx-sender}
                      {
                        start-block: (get start-block s),
                        end-block: new-end,
                        active: true,
                        total-paid: (+ (get total-paid s) amount)
                      })
                    ;; emit-event: renewed with plan-id and subscriber
                    (ok {renewed-until: new-end}))
                  (err ERR_INVALID_AMOUNT))
              (err ERR_NO_SUBSCRIPTION))
        (err ERR_NO_SUBSCRIPTION)))
    (err ERR_INVALID_AMOUNT))
)

;; (4) Cancel subscription
;; (4) Cancel subscription
(define-public (cancel-subscription (plan-id uint))
  (if (>= plan-id u0)
    (let ((sub (map-get? subscriptions {plan-id: plan-id, subscriber: tx-sender})))
      (match sub
        s
          (if (get active s)
              (begin
                (map-set subscriptions {plan-id: plan-id, subscriber: tx-sender}
                  {
                    start-block: (get start-block s),
                    end-block: (get end-block s),
                    active: false,
                    total-paid: (get total-paid s)
                  })
                ;; emit-event: canceled with plan-id and subscriber
                (ok "Subscription canceled"))
              (err ERR_NOT_SUBSCRIBER))
        (err ERR_NO_SUBSCRIPTION)))
    (err ERR_INVALID_AMOUNT))
)

;; (5) Withdraw collected STX
(define-public (withdraw (amount uint))
  (match (only-owner)
    ok-val (ok true)
    err-val (err err-val))
)

;; ----------------------------------
;; READ-ONLY FUNCTIONS
;; ----------------------------------

(define-read-only (get-plan (id uint))
  (map-get? plans id)
)

(define-read-only (get-subscription (plan-id uint) (subscriber principal))
  (map-get? subscriptions (tuple (plan-id plan-id) (subscriber subscriber)))
)

(define-read-only (is-active (plan-id uint) (subscriber principal))
  (let ((sub (map-get? subscriptions (tuple (plan-id plan-id) (subscriber subscriber)))))
    (match sub
      s (if (get active s)
            true
            false)
      false))
)

(define-read-only (get-total-subscribers)
  (var-get total-subscribers)
)
