# StackSub - Decentralized Recurring Subscription Contract

A smart contract for the Stacks blockchain that enables creators to manage decentralized recurring subscriptions using STX tokens.

## Features

-  **Create Subscription Plans** - Creators can set up subscription plans with custom pricing and duration
-  **Subscribe to Plans** - Users can subscribe to any active plan by paying the subscription price
-  **Renew Subscriptions** - Subscribers can extend their subscription for another billing period
-  **Cancel Subscriptions** - Subscribers can cancel active subscriptions at any time
-  **Withdraw Payments** - Contract owner can withdraw collected STX from subscriptions
-  **Track Subscriptions** - Query subscription status and expiration blocks

## Contract Structure

### Data Storage
- **Plans Map** - Stores subscription plans with creator, name, price, and duration
- **Subscriptions Map** - Tracks active subscriptions with start/end blocks and payment history
- **Global Variables** - Owner, next plan ID, and total subscriber count

### Error Codes
- `ERR_NOT_OWNER` (100) - Caller is not the contract owner
- `ERR_INVALID_AMOUNT` (101) - Invalid subscription amount or plan settings
- `ERR_SUBSCRIPTION_EXPIRED` (102) - Subscription has expired
- `ERR_ALREADY_ACTIVE` (103) - Subscription is already active
- `ERR_NO_SUBSCRIPTION` (104) - Subscription does not exist
- `ERR_NOT_SUBSCRIBER` (105) - Caller is not a subscriber

## Public Functions

### `create-plan(name, price, duration)`
Create a new subscription plan.
- **Parameters:** Plan name (string), price in STX, duration in blocks
- **Returns:** Plan ID and details
- **Usage:** Creators call this to set up their subscription offering

### `subscribe(plan-id, amount)`
Subscribe to an existing plan.
- **Parameters:** Plan ID, payment amount (STX)
- **Returns:** Subscription confirmation with expiration block
- **Usage:** Users call this to start a subscription

### `renew(plan-id, amount)`
Extend an active subscription for another period.
- **Parameters:** Plan ID, renewal payment (STX)
- **Returns:** New expiration block
- **Usage:** Subscribers call this before expiration

### `cancel-subscription(plan-id)`
Cancel an active subscription.
- **Parameters:** Plan ID
- **Returns:** Confirmation message
- **Usage:** Subscribers call this to stop their subscription

### `withdraw(amount)`
Withdraw collected payments (owner only).
- **Parameters:** Amount to withdraw (STX)
- **Returns:** Success or error
- **Usage:** Contract owner calls this to claim payments

## Read-Only Functions

- `get-plan(id)` - Retrieve plan details
- `get-subscription(plan-id, subscriber)` - Check subscription status
- `is-active(plan-id, subscriber)` - Verify if subscription is active
- `get-total-subscribers()` - Get total subscriber count

## Usage Example

```clarity
;; 1. Creator sets up a plan ($10 STX per month = 4,320 blocks @ 10 min blocks)
(contract-call? .stacksub create-plan "Premium Access" u10000000 u4320)
;; Returns: {plan-id: u1, price: u10000000, duration: u4320}

;; 2. User subscribes to the plan
(contract-call? .stacksub subscribe u1 u10000000)
;; Returns: {status: "subscribed", plan: u1, expires: u5320}

;; 3. User checks if subscription is active
(contract-call? .stacksub is-active u1 'SPXXXXXX...)
;; Returns: true

;; 4. When ready to renew, user extends subscription
(contract-call? .stacksub renew u1 u10000000)
;; Returns: {renewed-until: u9640}

;; 5. Owner withdraws collected payments
(contract-call? .stacksub withdraw u50000000)
