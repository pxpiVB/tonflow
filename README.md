# TonFlow — DCA & Limit Orders for TON

> Automated trading for everyone on Telegram. Powered by STON.fi SDK + Omniston.

## What is TonFlow?

TonFlow is a Telegram Mini App that brings **DCA (Dollar-Cost Averaging)** and **Limit Orders** to TON blockchain — a gap that currently doesn't exist natively on TON, while Solana equivalents (Banana Gun, BullX, Unibot) generated **$940M revenue in 2025**.

Users set recurring buys or price-triggered orders directly inside Telegram. All swaps execute through **STON.fi SDK + Omniston** for best-price routing across DEX v1/v2, DeDust, and Tonco.

## Features

- **DCA Orders** — buy any token on a schedule (daily / weekly / custom interval)
- **Limit Orders** — trigger a swap when token hits your target price
- **Telegram-native** — opens as a Mini App, no separate app needed
- **TON Connect** — non-custodial wallet auth
- **STON.fi Omniston** — best price routing across all TON liquidity

## Tech Stack

| Layer | Tech |
|---|---|
| Smart Contracts | Tact (TON) |
| Mini App | HTML/JS + Telegram WebApp SDK |
| Swap Execution | STON.fi SDK v2 |
| Liquidity | Omniston (DEX v1/v2, DeDust, Tonco) |
| Wallet Auth | TON Connect |
| Price Feeds | TonCenter API |

## Repository Structure

```
TonFlow.tact          — Main smart contract (DCA scheduler + limit order logic)
CryptoVisit.tact      — Earlier TON contract demo (loyalty token, cooldown logic)
CryptoVisit.sol       — Solidity version for cross-chain reference
miniapp.html          — Telegram Mini App frontend
index.html            — Web frontend (Celo/MiniPay version)
tonconnect-manifest.json — TON Connect config
```

## Milestones

| Milestone | Deliverable | Budget |
|---|---|---|
| M1 | Smart contracts on TON testnet (DCA + limit order logic in Tact) | $2,000 |
| M2 | Telegram Mini App + full STON.fi SDK / Omniston integration | $4,000 |
| M3 | Mainnet launch + referral fees active + 1,000 active users | $4,000 |

## Revenue Model

TonFlow earns **referral fees (0.1–1% per swap)** via STON.fi's referral program, set at swap execution time. This makes the product self-sustaining after the grant period.

## Author

**Serhii Medulych** — former STON.fi Ambassador, TON/Ethereum developer.  
Telegram: [@Serhiimeds](https://t.me/Serhiimeds)  
Email: serhiimeduylich@gmail.com

---

*Grant application submitted to STON.fi DEX Grant Program — up to $10,000 USDT.*
