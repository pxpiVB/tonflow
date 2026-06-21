# CapyFi Bug Bounty (Immunefi)

**Status:** Report drafted, submission blocked on account verification
**Program:** https://immunefi.com/bug-bounty/capyfi/
**Max bounty:** $1M (Critical)

## The Finding

**Title:** Centralized oracle (CapyFiAggregatorV3) for caLAC and caRPC allows arbitrary price manipulation, enabling protocol drain of ~$7.94M TVL
**Severity:** Critical
**Report file:** `capyfi_immunefi_report.md` in workspace root

### Root Cause
- `CapyFiAggregatorV3` (deployed March 2026, never audited) has `boundChecksEnabled = false`
- `updateAnswer()` accepts any positive int — no TWAP, no deviation limit, no timelock
- `ChainlinkPriceOracle` performs zero validation on returned price
- Same address `0x6A138bd6d69Feb3C2f5426549e60E644778AD04C` controls oracle AND Whitelist

### Key Contracts
| Contract | Address |
|---|---|
| CapyFiAggregatorV3 (caLAC oracle) | `0xF3585f9D9a671e630055Ce0c436AA214954ce6D4` |
| ChainlinkPriceOracle | `0xfbA2712d3bbcf32c6E0178a21955b61FE1FF424A` |
| caLAC (CF=60%) | `0x0568F6cb5A0E84FACa107D02f81ddEB1803f3B50` |
| caRPC (CF=50%) | `0xF61159B4a0EE5b1615c9Afb3dA38111043344c32` |
| Unitroller | `0x0b9af1fd73885aD52680A1aeAa7A3f17AC702afA` |

### Why Not CAPY-02
CAPY-02 = missing Chainlink `updatedAt` staleness check (Coinspect, severity None).
This finding = centralized oracle where admin pushes ANY value. Different root cause, different contracts (deployed post-audit), exploitable without any external failure.

### Known Issues (all ineligible)
- CAPY-01: caUXD fixedPrice=$1.00 — in tracker
- CAPY-02: Oracle staleness — in tracker
- CAPY-03: blocksPerYear hardcoded — in tracker

## Immunefi Account Status

**Account:** medylicsghe@gmail.com
**Wallet:** `0x6AEa710B586fD554bfbF648bf0319424Bf01499E` — NOT yet added to account
**Verification:** NOT done (need Human Passport score ≥25 OR pay USDC)

### To Unblock Submission
1. Go to `bugs.immunefi.com/settings/wallets` → Add wallet
2. Go to `bugs.immunefi.com/settings/identity` → Human Passport
   - Google account (~15 pts)
   - GitHub (~5 pts)  
   - Twitter/X (~5 pts)
   - Total needed: ≥25
3. Submit at `bugs.immunefi.com/dashboard/new-submission` → CapyFi

## Submission Form Steps (when ready)
1. Assets & Impact — paste affected contract addresses
2. Severity — Critical
3. Main Report — paste content from `capyfi_immunefi_report.md`
4. Wallet Address — payout wallet
5. Review & Submit

## KYC Note
Full KYC (passport + proof of address) required before payout. Not required to submit.
