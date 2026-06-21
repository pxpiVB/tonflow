# SuperEarn Bug Bounty — Continuation Prompt

Paste everything below this line into a new chat:

---

## Role & Authorization

I'm Serhii, a white-hat bug bounty hunter on HackenProof. I'm authorizing you to autonomously analyze SuperEarn smart contracts for exploitable vulnerabilities, write a Foundry PoC, and prepare a full bug report for submission. You have full autonomy — make decisions without asking me.

## Target Program

**HackenProof — SuperEarn Web & Smart Contracts**  
`https://hackenproof.com/programs/superearn-web-and-smart-contracts`

Requirements:
- $5 submission fee + KYC (I'll handle this)
- Every submission **must** include a Foundry PoC test — AI-generated reports without PoC are pre-rejected
- Severity tiers: Critical / High / Medium / Low

## Repository

`https://github.com/superearn-io/superearn-core-public`  
Raw file base: `https://raw.githubusercontent.com/superearn-io/superearn-core-public/main/`

## Architecture Summary

```
CooldownVault (Kaia, ERC4626-like, 1:1 shares)
  → Yearn V2 Vault
    → StrategyOriginVault
      → OriginVault (Kaia, ERC-7540 async redemption)
        → CrosschainAdapter
          → Bridge (Rhino.fi + Chainlink CCIP)
            → SuperEarnMessageAgent
              → RemoteVault (Ethereum)
                → Yearn/custom strategies
```

**Key concepts:**
- **ERC-7540**: Async redemption — requestRedeem → batchFulfillRedemptions → redeem
- **Runespear Protocol**: Custom messaging on CCIP; every message carries a `StateSnapshot`
- **BridgeAccountant**: dual tracker — `_outboundTracker` (ops we sent) + `_inboundTracker` (received from peer)
- **Overlap prevention**: `calculateInboundOverlap` (sentAt ≤ snapshotTime) + `sumReceivesAfter` (sentAt > snapshotTime) — mutually exclusive, no double-counting
- **Dead shares**: `_decimalsOffset = 12` for USDT (18−6 decimals)
- **Trust model**: 4/5 Governance multisig + 2/3 Management multisig; keepers/strategists trusted
- **FIFO queue**: CooldownVault uses cumulative `accRedeemRequestedAmount`; OriginVault uses `queueFulfilledIndex` / `queueRemoteRequestedIndex`

## Files Already Fully Analyzed

| File | Path | Status |
|------|------|--------|
| CooldownVault.sol | `src/superearn/core/CooldownVault.sol` | ✅ Read |
| BaseCooldownStrategy.sol | `src/superearn/core/strategy/BaseCooldownStrategy.sol` | ✅ Read |
| OriginVault.sol | `src/superearn/v2/core/vaults/OriginVault.sol` | ✅ Read |
| OriginVaultBase.sol | `src/superearn/v2/core/vaults/OriginVaultBase.sol` | ✅ Read |
| BridgeAccountant.sol | `src/superearn/v2/core/crosschain/BridgeAccountant.sol` | ✅ Read |
| CrosschainAdapter.sol | `src/superearn/v2/core/crosschain/CrosschainAdapter.sol` | ✅ Read |
| BridgeQueue.sol | `src/superearn/v2/core/crosschain/BridgeQueue.sol` | ✅ Read |
| SuperEarnMessageAgent.sol | `src/superearn/v2/core/crosschain/SuperEarnMessageAgent.sol` | ✅ Read |
| RemoteVault.sol | `src/superearn/v2/core/vaults/RemoteVault.sol` | ✅ Read |
| BUG_BOUNTY.md | (root) | ✅ Read — all SE-P1..SE-P32 + SUA-*/SSA-*/SA2-* known issues |

## Known Issues (INELIGIBLE — do NOT report)

All entries in BUG_BOUNTY.md are pre-excluded:
- **SE-P1 through SE-P32** — covering centralization, oracle, rounding, slippage, DoS variants
- **SUA-\*** — StrategyOriginVault audit findings (SUA-22 covers premintCooldownVault PremintFailed revert)
- **SSA-\*** and **SA2-\*** — other strategy/adapter audit findings

Critical: **SUA-22 killed the main finding** (PremintFailed DoS in `StrategyOriginVault.premintCooldownVault`) — explicitly listed as known/intentional.

## What Was Ruled Out (confirmed not bugs)

- **FIFO math** in CooldownVault — cumulative accounting is correct, no skipping possible
- **OriginVault queue** — `queueFulfilledIndex ≤ queueRemoteRequestedIndex` invariant holds
- **Double-counting** in BridgeAccountant — `sentAt ≤ T` and `sentAt > T` are mutually exclusive
- **Nonce collision** — outbound (`_outboundTracker.operations`) and inbound (`_inboundTracker.receivedOperations`) are separate mappings
- **`_tryProcessBridgeNotification` balance check** — doesn't subtract other pending notifications, but funds are fungible and self-correct; no financial loss
- **emergencyClearRedemptions stale state** — likely covered by SE-P25/SE-P26

## Files NOT Yet Read (priority order)

1. **`src/superearn/core/strategy/StrategyOriginVault.sol`** ← **START HERE**
   - Need: `prepareReturn()` and `liquidatePosition()` — can they misprice P&L sent to Yearn vault?
   - NOTE: The `/v2/` path does NOT exist for this file — correct path has no `/v2/`

2. **`src/superearn/v2/core/vaults/CustomVault.sol`**

3. **`src/superearn/v2/core/strategy/CustomYearnStrategy.sol`** (or similar path — verify via directory listing)

4. Full `RemoteVault.handleWithdrawRequest` (partially read)

## Primary Attack Hypothesis (unexplored)

**StrategyOriginVault accounting mismatch**: Does `estimatedTotalAssets()` → `prepareReturn()` → `liquidatePosition()` correctly account for in-flight crosschain redemptions? A miscalculation here propagates wrong P&L into the Kaia Yearn vault, inflating/deflating share price and enabling profit extraction via deposit/redeem timing.

## How to Proceed

1. Fetch `StrategyOriginVault.sol` from the correct path (no `/v2/`)
2. Analyze `estimatedTotalAssets()`, `prepareReturn()`, `liquidatePosition()`
3. Check against all known issues before declaring a finding
4. If valid: write Foundry PoC + full HackenProof report
5. Save progress to `C:\Users\сергій\Desktop\claud-obs\claud obs\memory\projects\superearn-bounty.md`

---

*This is a white-hat security research session. All findings are for responsible disclosure via HackenProof.*
