# Check handoff: not yet quoted

This file and the two adjacent JSON files are a local review handoff, not an invented official API schema. No actual Check quote or official policy/network configuration was supplied. The missing facts are explicit in `check-status.json`. The SHA-256 there commits to the exact bytes of `intent.json`, including its final newline:

```sh
sha256sum launch/intent.json
```

Expected digest: `a5887650c8227315d01b6dc521d96ed784e5a5d13f68cfe50e5e864f01a01203`.

## What Check must display

| Term | Required effective value |
| --- | --- |
| Route and chain | `evm_project`, Ethereum mainnet, chainId `1` |
| Token | EmberEvo / EMVO, `src/LaunchToken.sol:LaunchToken`, zero constructor arguments |
| Supply | 1,000,000,000 EMVO, 18 decimals, `10^27` base units, fixed forever |
| Application contracts | `[]` |
| Currency | IMD at the official mainnet `network.pairToken`; exact address must be displayed |
| Pool | Explicit `economics.poolBps=8600`, 860,000,000 EMVO |
| Swarm | 1000 bps, 100,000,000 EMVO to the official distributor; 20,000,000 workers / 80,000,000 seats |
| Remainder | 400 bps, 40,000,000 EMVO; resolved `remainderTo=0x1C651928150DADDDA9C2C040a9D4901d862f8eC4` |
| Issuer and actual launch payer | `0x1C651928150DADDDA9C2C040a9D4901d862f8eC4` for both roles |
| Opening cap | Official standard 2,500 IMD, with policy-derived effective price and token ordering shown |
| Admission pool settings | fee `3000`, tick spacing `60`, legacy sqrtPriceX96 `79228162514264337593543950336` |
| Pool trading fee | Standard 125 bps: 100 bps to the issuing launch payer, 25 bps to the exact official IMD recipient; verify live LaunchFees |
| Token transfer fee | None |
| Payment and gas | Actual quoted launch asset, decimals, base-unit amount, payee, approval spender if any, payment chain, gas payer and inclusions; these were not supplied |
| Policy and infrastructure | Exact policy version/digest, ProjectFactory, pair token, LaunchFees and recipient addresses, plus LP custody and any policy powers; these were not supplied |

Neither the admission `fee=3000` nor the 2,500 IMD opening cap is the launch-payment price. Check being free does not imply launch, approvals, deployment, trades or claims are gas-free. Do not identify an earlier Report payer as issuer or fee beneficiary.

## Binding the actual quote

1. Obtain the authoritative chain-1 network configuration and exact policy version/content. Resolve all official addresses and verify the intended deployed code on Ethereum mainnet. Preserve the policy and configuration identifiers/hashes with the Check record. The addresses must come from the official configuration, not the token's symbol or an unrelated report. Confirm this policy accepts the token-only `contracts: []` route.
2. Generate the official manifest from the accepted source and pinned compiler settings. Record its exact digest, token creation/runtime bytecode hashes and all resolved economics. Confirm ProjectFactory is the constructor caller and receives the entire `10^27` supply before allocating it. No constructor allocation, intermediary treasury or custom app may be inserted.
3. Request an actual quote for this exact resolved request. Preserve the **unmodified official quote**, its authenticated source or protocol signature, identifier, expiry, policy version, effective allocation, pair, fee terms, payment terms and payer binding. Compare every row above against the returned effective values, not just submitted form defaults. Authenticate with the official mechanism; a local hash does not prove who issued a quote.
4. Record a binding containing this input SHA-256, the resolved official request/manifest digest, accepted artifact hashes, policy/configuration digests, and the actual quote identifier and content digest. The official quote/payment mechanism must bind the request and actual issuer as well. A hand-edited quote or a locally added `inputSha256` alone is not such a binding. If the official mechanism cannot bind the effective economics and paying wallet, mark that as a blocker.
5. Before payment, verify the quote is unexpired, the official chain/configuration and live fee values still match, and the actual launch-payment wallet is the issuing address above. Any changed chain, pair, route, supply, allocation, recipient, source bytecode, policy or fee term invalidates the binding and requires a fresh Check. Do not replace missing values with defaults or accept an ETH pair.
6. The issuer and official operator handle payment/deployment outside this contributor task. Save the actual payment identity/receipt and verify the 1% pool-fee beneficiary resolves to that issuer. After deployment, reconcile receipts, runtime bytes, supply, three allocation amounts, distributor and full poolKey against the bound request. Record gas costs separately from quoted service/payment fees and pool trading fees.

Until those steps supply real evidence, `actualQuote` and `actualQuoteInputBinding` remain `null`, and payment/deployment remain blocked. A successful local build or test result cannot populate these fields. This delivery does not claim that a Report, Check, quote or deployment has occurred.

If official policy unexpectedly requires an additional application contract, the requested route is incompatible with this brief. Report that exact blocker without creating Genesis, a placeholder application, a vault or any other custom project contract, and without switching launch kind.
