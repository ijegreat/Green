# Environmental Cleanup Initiative Smart Contract

A decentralized environmental cleanup contract built on the Stacks blockchain that enables community-driven environmental restoration projects through crowdfunding and democratic governance.

## Overview

This smart contract allows project coordinators to create environmental cleanup initiatives with specific budgets and timelines. Community members can donate funds, vote on cleanup zones, and receive refunds if funding goals aren't met. The contract ensures transparency and community oversight through a voting mechanism.

## Features

- **Decentralized Crowdfunding**: Community members can donate STX tokens to support cleanup initiatives
- **Democratic Governance**: Donors vote on cleanup zones before funds are released
- **Refund Mechanism**: Automatic refunds if funding goals aren't met by the deadline
- **Zone Management**: Coordinators can add multiple cleanup zones with specific budgets
- **Transparent Tracking**: All donations, votes, and initiative details are publicly viewable

## Contract Functions

### Public Functions

#### For Project Coordinators

**`start-cleanup-initiative`**
```clarity
(start-cleanup-initiative (budget uint) (duration uint))
```
- Initializes a new cleanup initiative
- Sets the funding goal and deadline
- Only one initiative can be active at a time
- Duration is in blocks (max ~1 year = 52,560 blocks)

**`add-cleanup-zone`**
```clarity
(add-cleanup-zone (location string-utf8) (budget uint))
```
- Adds a new cleanup zone to the current initiative
- Specifies location description and required budget
- Only callable by the project coordinator

**`initiate-community-review`**
```clarity
(initiate-community-review)
```
- Starts the community voting period for the current zone
- Changes initiative status to "community_review"
- Resets vote counters

**`conclude-community-review`**
```clarity
(conclude-community-review)
```
- Finalizes the community vote
- Approves zone if support votes > opposition votes
- Advances to next zone if approved

**`release-cleanup-funds`**
```clarity
(release-cleanup-funds (amount uint))
```
- Releases approved funds to the coordinator
- Can only release up to the total donations received
- Requires coordinator authorization

#### For Community Members

**`donate-to-cleanup`**
```clarity
(donate-to-cleanup (amount uint))
```
- Donate STX tokens to the active initiative
- Updates donor contribution records
- Transfers tokens to the contract
- Only works during active funding period

**`vote-on-zone`**
```clarity
(vote-on-zone (approve bool))
```
- Vote to approve or reject a cleanup zone
- Voting power is weighted by donation amount
- Only donors can participate in voting
- Only during "community_review" status

**`request-donor-refund`**
```clarity
(request-donor-refund)
```
- Claim refund if funding goal wasn't met by deadline
- Only available after deadline has passed
- Only for donors who contributed to the initiative

### Read-Only Functions

**`get-initiative-details`**
- Returns current initiative status, budget, donations, deadline, and coordinator

**`get-donor-contribution`**
- Returns the total contribution amount for a specific donor

**`get-zone-details`**
- Returns location and budget information for a specific zone

## Usage Workflow

### 1. Starting an Initiative
```clarity
;; Coordinator starts a new cleanup initiative
(contract-call? .cleanup-contract start-cleanup-initiative u1000000 u1440) ;; 1M microSTX, ~10 days
```

### 2. Adding Cleanup Zones
```clarity
;; Add zones to be cleaned
(contract-call? .cleanup-contract add-cleanup-zone u"Central Park Lake Area" u300000)
```

### 3. Community Donations
```clarity
;; Community members donate to the initiative
(contract-call? .cleanup-contract donate-to-cleanup u50000) ;; 0.05 STX
```

### 4. Community Voting
```clarity
;; Coordinator initiates review
(contract-call? .cleanup-contract initiate-community-review)

;; Donors vote on the zone
(contract-call? .cleanup-contract vote-on-zone true) ;; Approve zone

;; Coordinator concludes review
(contract-call? .cleanup-contract conclude-community-review)
```

### 5. Fund Release
```clarity
;; Coordinator releases funds for cleanup execution
(contract-call? .cleanup-contract release-cleanup-funds u300000)
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | ERR_NOT_COORDINATOR | Action requires coordinator privileges |
| u101 | ERR_INITIATIVE_ALREADY_ACTIVE | Cannot start new initiative while one is active |
| u102 | ERR_DONOR_NOT_FOUND | Address has no donation record |
| u103 | ERR_CLEANUP_PERIOD_ENDED | Initiative deadline has passed |
| u104 | ERR_FUNDING_GOAL_UNMET | Would exceed funding target |
| u105 | ERR_INSUFFICIENT_CLEANUP_FUNDS | Not enough funds available for release |
| u106 | ERR_INVALID_DONATION_AMOUNT | Amount must be greater than 0 |
| u107 | ERR_INVALID_CLEANUP_DURATION | Duration must be 1-52560 blocks |
| u108 | ERR_ZONE_REJECTED | Community voted against the zone |
| u109 | ERR_INVALID_LOCATION | Location string too long (>256 chars) |

## Initiative Status States

- **"not_started"**: No active initiative
- **"active"**: Initiative is accepting donations
- **"community_review"**: Donors are voting on a cleanup zone

## Security Considerations

- **Single Coordinator**: Only one coordinator can manage an initiative at a time
- **Donation Limits**: Cannot exceed the specified budget
- **Time Constraints**: Donations only accepted before deadline
- **Voting Rights**: Only donors can vote, weighted by contribution
- **Refund Protection**: Automatic refunds if goals aren't met

## Testing

Before deploying to mainnet, thoroughly test:

1. Initiative creation with various parameters
2. Donation flows and edge cases
3. Voting mechanisms and outcomes
4. Fund release permissions
5. Refund scenarios
6. Error handling for all edge cases

## Deployment

1. Deploy the contract to Stacks blockchain
2. Verify contract functions work as expected
3. Set up monitoring for initiative activities
4. Create frontend interface for easy interaction

