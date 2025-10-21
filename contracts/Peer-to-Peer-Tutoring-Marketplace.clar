(define-constant ERR-ALREADY-REGISTERED u100)
(define-constant ERR-NOT-REGISTERED u101)
(define-constant ERR-INACTIVE u102)
(define-constant ERR-NOT-TUTOR u103)
(define-constant ERR-NOT-LEARNER u104)
(define-constant ERR-INVALID-PRICE u105)
(define-constant ERR-SESSION-NOT-FOUND u106)
(define-constant ERR-ALREADY-COMPLETED u107)
(define-constant ERR-ALREADY-APPROVED u108)
(define-constant ERR-ALREADY-CANCELLED u109)
(define-constant ERR-NOT-ACTIVE u110)
(define-constant ERR-CANCEL-BLOCKED u111)
(define-constant ERR-TRANSFER-FAILED u199)
(define-constant ERR-INVALID-RATING u200)
(define-constant ERR-ALREADY-RATED u201)
(define-constant ERR-SESSION-NOT-COMPLETED u202)
(define-constant STATUS-FUNDED u1)
(define-constant STATUS-COMPLETED u2)
(define-constant STATUS-PAID u3)
(define-constant STATUS-CANCELLED u4)
(define-data-var next-id uint u1)
(define-map tutors (tuple (who principal)) (tuple (rate uint) (active bool) (sessions uint) (earned uint) (total-rating uint) (review-count uint)))
(define-map sessions
  (tuple (id uint))
  (tuple
    (learner principal)
    (tutor principal)
    (subject (string-ascii 64))
    (price uint)
    (created-at uint)
    (completed-at (optional uint))
    (approved-at (optional uint))
    (cancelled-at (optional uint))
    (proof (optional (string-ascii 128)))
    (status uint)
    (tutor-completed bool)
    (learner-approved bool)
  )
)
(define-map reviews
  (tuple (session-id uint))
  (tuple
    (rating uint)
    (review (string-ascii 256))
    (reviewer principal)
    (tutor principal)
    (created-at uint)
  )
)
(define-read-only (contract-principal) (as-contract tx-sender))
(define-read-only (is-tutor? (who principal)) (is-some (map-get? tutors { who: who })))
(define-read-only (get-next-id) (var-get next-id))
(define-read-only (get-tutor (who principal)) (map-get? tutors { who: who }))
(define-read-only (get-session (id uint)) (map-get? sessions { id: id }))
(define-read-only (get-review (session-id uint)) (map-get? reviews { session-id: session-id }))
(define-read-only (session-active? (id uint))
  (let ((s (map-get? sessions { id: id })))
    (match s
      sess (and (not (is-eq (get status sess) STATUS-PAID)) (not (is-eq (get status sess) STATUS-CANCELLED)))
      false
    )
  )
)
(define-public (register-tutor (rate uint))
  (if (<= rate u0)
      (err ERR-INVALID-PRICE)
      (if (is-some (map-get? tutors { who: tx-sender }))
          (err ERR-ALREADY-REGISTERED)
          (begin
            (map-set tutors { who: tx-sender } { rate: rate, active: true, sessions: u0, earned: u0, total-rating: u0, review-count: u0 })
            (ok true)
          )
      )
  )
)
(define-public (update-rate (rate uint))
  (let ((t (map-get? tutors { who: tx-sender })))
    (match t
      tutor-data
        (if (not (get active tutor-data))
            (err ERR-INACTIVE)
            (if (<= rate u0)
                (err ERR-INVALID-PRICE)
                (begin
                  (map-set tutors { who: tx-sender } { rate: rate, active: true, sessions: (get sessions tutor-data), earned: (get earned tutor-data), total-rating: (get total-rating tutor-data), review-count: (get review-count tutor-data) })
                  (ok true)
                )
            )
        )
      (err ERR-NOT-REGISTERED)
    )
  )
)
(define-public (deactivate-tutor)
  (let ((t (map-get? tutors { who: tx-sender })))
    (match t
      tutor-data
        (begin
          (map-set tutors { who: tx-sender } { rate: (get rate tutor-data), active: false, sessions: (get sessions tutor-data), earned: (get earned tutor-data), total-rating: (get total-rating tutor-data), review-count: (get review-count tutor-data) })
          (ok true)
        )
      (err ERR-NOT-REGISTERED)
    )
  )
)
(define-public (activate-tutor)
  (let ((t (map-get? tutors { who: tx-sender })))
    (match t
      tutor-data
        (begin
          (map-set tutors { who: tx-sender } { rate: (get rate tutor-data), active: true, sessions: (get sessions tutor-data), earned: (get earned tutor-data), total-rating: (get total-rating tutor-data), review-count: (get review-count tutor-data) })
          (ok true)
        )
      (err ERR-NOT-REGISTERED)
    )
  )
)
(define-public (create-session (tutor principal) (subject (string-ascii 64)) (price uint))
  (let ((t (map-get? tutors { who: tutor })))
    (match t
      tdata
        (if (not (get active tdata))
            (err ERR-INACTIVE)
            (if (< price (get rate tdata))
                (err ERR-INVALID-PRICE)
                (let ((c (as-contract tx-sender)))
                  (match (stx-transfer? price tx-sender c)
                    ok-res
                      (let ((id (var-get next-id)))
                        (map-set sessions { id: id }
                          {
                            learner: tx-sender,
                            tutor: tutor,
                            subject: subject,
                            price: price,
                            created-at: stacks-block-height,
                            completed-at: none,
                            approved-at: none,
                            cancelled-at: none,
                            proof: none,
                            status: STATUS-FUNDED,
                            tutor-completed: false,
                            learner-approved: false
                          }
                        )
                        (var-set next-id (+ id u1))
                        (ok id)
                      )
                    err-code (err err-code)
                  )
                )
            )
        )
      (err ERR-NOT-REGISTERED)
    )
  )
)
(define-public (mark-complete (id uint) (proof (string-ascii 128)))
  (let ((s (map-get? sessions { id: id })))
    (match s
      sess
        (if (is-eq (get status sess) STATUS-CANCELLED)
            (err ERR-ALREADY-CANCELLED)
            (if (is-eq (get status sess) STATUS-PAID)
                (err ERR-ALREADY-APPROVED)
                (if (not (is-eq (get tutor sess) tx-sender))
                    (err ERR-NOT-TUTOR)
                    (if (get tutor-completed sess)
                        (err ERR-ALREADY-COMPLETED)
                        (if (not (is-eq (get status sess) STATUS-FUNDED))
                            (err ERR-NOT-ACTIVE)
                            (begin
                              (map-set sessions { id: id }
                                {
                                  learner: (get learner sess),
                                  tutor: (get tutor sess),
                                  subject: (get subject sess),
                                  price: (get price sess),
                                  created-at: (get created-at sess),
                                  completed-at: (some stacks-block-height),
                                  approved-at: (get approved-at sess),
                                  cancelled-at: (get cancelled-at sess),
                                  proof: (some proof),
                                  status: STATUS-COMPLETED,
                                  tutor-completed: true,
                                  learner-approved: (get learner-approved sess)
                                }
                              )
                              (ok true)
                            )
                        )
                    )
                )
            )
        )
      (err ERR-SESSION-NOT-FOUND)
    )
  )
)
(define-public (approve-session (id uint))
  (let ((s (map-get? sessions { id: id })))
    (match s
      sess
        (if (is-eq (get status sess) STATUS-CANCELLED)
            (err ERR-ALREADY-CANCELLED)
            (if (not (is-eq (get learner sess) tx-sender))
                (err ERR-NOT-LEARNER)
                (if (not (get tutor-completed sess))
                    (err ERR-ALREADY-COMPLETED)
                    (if (get learner-approved sess)
                        (err ERR-ALREADY-APPROVED)
                        (if (not (is-eq (get status sess) STATUS-COMPLETED))
                            (err ERR-NOT-ACTIVE)
                            (let ((amt (get price sess)) (t (get tutor sess)))
                              (match (as-contract (stx-transfer? amt tx-sender t))
                                ok-pay
                                  (match (map-get? tutors { who: t })
                                    tdata
                                      (begin
                                        (map-set sessions { id: id }
                                          {
                                            learner: (get learner sess),
                                            tutor: (get tutor sess),
                                            subject: (get subject sess),
                                            price: (get price sess),
                                            created-at: (get created-at sess),
                                            completed-at: (get completed-at sess),
                                            approved-at: (some stacks-block-height),
                                            cancelled-at: (get cancelled-at sess),
                                            proof: (get proof sess),
                                            status: STATUS-PAID,
                                            tutor-completed: (get tutor-completed sess),
                                            learner-approved: true
                                          }
                                        )
                                        (map-set tutors { who: t } { rate: (get rate tdata), active: (get active tdata), sessions: (+ (get sessions tdata) u1), earned: (+ (get earned tdata) amt), total-rating: (get total-rating tdata), review-count: (get review-count tdata) })
                                        (ok true)
                                      )
                                    (err ERR-NOT-REGISTERED)
                                  )
                                err-code (err err-code)
                              )
                            )
                        )
                    )
                )
            )
        )
      (err ERR-SESSION-NOT-FOUND)
    )
  )
)
(define-public (cancel-session (id uint))
  (let ((s (map-get? sessions { id: id })))
    (match s
      sess
        (if (not (is-eq (get learner sess) tx-sender))
            (err ERR-NOT-LEARNER)
            (if (is-eq (get status sess) STATUS-CANCELLED)
                (err ERR-ALREADY-CANCELLED)
                (if (is-eq (get status sess) STATUS-PAID)
                    (err ERR-ALREADY-APPROVED)
                    (if (get tutor-completed sess)
                        (err ERR-CANCEL-BLOCKED)
                        (if (not (is-eq (get status sess) STATUS-FUNDED))
                            (err ERR-NOT-ACTIVE)
                            (let ((amt (get price sess)) (l (get learner sess)))
                              (match (as-contract (stx-transfer? amt tx-sender l))
                                ok-refund
                                  (begin
                                    (map-set sessions { id: id }
                                      {
                                        learner: (get learner sess),
                                        tutor: (get tutor sess),
                                        subject: (get subject sess),
                                        price: (get price sess),
                                        created-at: (get created-at sess),
                                        completed-at: (get completed-at sess),
                                        approved-at: (get approved-at sess),
                                        cancelled-at: (some stacks-block-height),
                                        proof: (get proof sess),
                                        status: STATUS-CANCELLED,
                                        tutor-completed: (get tutor-completed sess),
                                        learner-approved: (get learner-approved sess)
                                      }
                                    )
                                    (ok true)
                                  )
                                err-code (err err-code)
                              )
                            )
                        )
                    )
                )
            )
        )
      (err ERR-SESSION-NOT-FOUND)
    )
  )
)
(define-read-only (session-status (id uint))
  (let ((s (map-get? sessions { id: id })))
    (match s
      sess (some (tuple (status (get status sess)) (tutor-completed (get tutor-completed sess)) (learner-approved (get learner-approved sess))))
      none
    )
  )
)
(define-read-only (tutor-stats (who principal))
  (let ((t (map-get? tutors { who: who })))
    (match t
      tutor-data (some (tuple (rate (get rate tutor-data)) (active (get active tutor-data)) (sessions (get sessions tutor-data)) (earned (get earned tutor-data)) (average-rating (if (> (get review-count tutor-data) u0) (/ (get total-rating tutor-data) (get review-count tutor-data)) u0)) (review-count (get review-count tutor-data))))
      none
    )
  )
)
(define-public (submit-review (session-id uint) (rating uint) (review-text (string-ascii 256)))
  (let ((s (map-get? sessions { id: session-id })))
    (match s
      sess
        (if (not (is-eq (get learner sess) tx-sender))
            (err ERR-NOT-LEARNER)
            (if (not (is-eq (get status sess) STATUS-PAID))
                (err ERR-SESSION-NOT-COMPLETED)
                (if (or (< rating u1) (> rating u5))
                    (err ERR-INVALID-RATING)
                    (if (is-some (map-get? reviews { session-id: session-id }))
                        (err ERR-ALREADY-RATED)
                        (let ((tutor (get tutor sess)))
                          (match (map-get? tutors { who: tutor })
                            tdata
                              (begin
                                (map-set reviews { session-id: session-id }
                                  {
                                    rating: rating,
                                    review: review-text,
                                    reviewer: tx-sender,
                                    tutor: tutor,
                                    created-at: stacks-block-height
                                  }
                                )
                                (map-set tutors { who: tutor }
                                  {
                                    rate: (get rate tdata),
                                    active: (get active tdata),
                                    sessions: (get sessions tdata),
                                    earned: (get earned tdata),
                                    total-rating: (+ (get total-rating tdata) rating),
                                    review-count: (+ (get review-count tdata) u1)
                                  }
                                )
                                (ok true)
                              )
                            (err ERR-NOT-REGISTERED)
                          )
                        )
                    )
                )
            )
        )
      (err ERR-SESSION-NOT-FOUND)
    )
  )
)

