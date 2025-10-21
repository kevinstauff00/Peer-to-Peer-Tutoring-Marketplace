# Peer-to-Peer Tutoring Marketplace

A peer-to-peer marketplace that matches tutors and learners and escrows STX for sessions, releasing payment on completion proofs.

## Features

- Tutor registration with configurable rate
- Learner-funded session creation with STX escrow
- Tutor completion with proof text and block height capture
- Learner approval to release escrow to tutor
- Learner cancellation with refund prior to tutor completion

## Contract

- File: contracts/Peer-to-Peer-Tutoring-Marketplace.clar
- Clarity: v3
- Uses stacks-block-height for timestamps

## Install and Check

- Ensure Clarinet is installed
- Run:

```bash path=null start=null
clarinet check
```

## Usage

- Register as tutor:

```clarity path=null start=null
(contract-call? .Peer-to-Peer-Tutoring-Marketplace register-tutor u1000000)
```

- Update rate:

```clarity path=null start=null
(contract-call? .Peer-to-Peer-Tutoring-Marketplace update-rate u1500000)
```

- Create a session (escrow STX):

```clarity path=null start=null
(contract-call? .Peer-to-Peer-Tutoring-Marketplace create-session 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC "Math" u1500000)
```

- Tutor marks complete with proof:

```clarity path=null start=null
(contract-call? .Peer-to-Peer-Tutoring-Marketplace mark-complete u1 "session-2025-09-26-proof")
```

- Learner approves and releases escrow:

```clarity path=null start=null
(contract-call? .Peer-to-Peer-Tutoring-Marketplace approve-session u1)
```

- Learner cancels before completion:

```clarity path=null start=null
(contract-call? .Peer-to-Peer-Tutoring-Marketplace cancel-session u1)
```

## Read-Only Helpers

```clarity path=null start=null
(contract-call? .Peer-to-Peer-Tutoring-Marketplace get-next-id)
(contract-call? .Peer-to-Peer-Tutoring-Marketplace get-tutor 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
(contract-call? .Peer-to-Peer-Tutoring-Marketplace get-session u1)
(contract-call? .Peer-to-Peer-Tutoring-Marketplace session-status u1)
(contract-call? .Peer-to-Peer-Tutoring-Marketplace tutor-stats 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
```

## Notes

- Prices are in microstacks
- Status values: 1 funded, 2 completed, 3 paid, 4 cancelled
- No comments in code as requested

## Quick Demo Flow

1. Tutor registers ✅
2. Learner creates session and escrows STX 💎
3. Tutor marks complete with proof 📝
4. Learner approves and funds are released 🎉
