# EmberEvo (EMVO)

EmberEvo is an independent IMD Ember World ecosystem token. This deliverable implements its plain ERC-20 for the official **Ethereum mainnet (chainId 1), IMD-paired, `evm_project`** route. No transaction has been broadcast and no mainnet deployment is claimed.

`src/LaunchToken.sol:LaunchToken` has a nonpayable, zero-argument constructor. It mints exactly **1,000,000,000 EMVO**, with **18 decimals** (`1000000000000000000000000000` base units), once to `msg.sender`. In the official launch that sender must be ProjectFactory. The factory, not the token, allocates the supply. The token has no owner, later mint, burn entry point, upgrade mechanism, pause, blacklist, transfer tax, rebase, staking, vesting or AI financial authority. Ordinary ERC-20 approvals and transfers are its only public mutation paths.

## Effective launch allocation

| Destination | Initial supply | EMVO | Base units |
| --- | ---: | ---: | ---: |
| Official EMVO/IMD pool | 86% (`economics.poolBps = 8600`) | 860,000,000 | `860000000000000000000000000` |
| Official Swarm MerkleDistributor | 10% | 100,000,000 | `100000000000000000000000000` |
| Issuing wallet, `remainderTo` | 4% | 40,000,000 | `40000000000000000000000000` |

**Issuer, launch-payment wallet, remainder recipient and launch-payer trading-fee beneficiary must all be `0x1C651928150DADDDA9C2C040a9D4901d862f8eC4`.** Payment for a previous Report by a different wallet does not establish the issuer. The same issuing wallet must make the actual launch payment; a matching remainder recipient alone is insufficient.

The supplied route describes the Swarm share as 2% of total supply (20,000,000 EMVO) shared equally among wallets with accepted launch work, and 8% (80,000,000 EMVO) shared equally among paired seats connected at admission, one share per seat. The official distributor and admission snapshot implement this. This repository creates no reward contract, seat registry or vesting contract.

The application `contracts` array is **empty**. The supplied route permits zero application contracts and provides the pool, MerkleDistributor and PoolInitializationGuard through official infrastructure. Do not list the guard or distributor as application contracts. If the actual policy requires a custom project contract, stop and report that incompatibility; do not add an extra contract or switch to `custom_token`.

## Opening price and fees

The required standard IMD opening cap in the supplied reference is **2,500 IMD**. The official deployer derives the opening price from the pinned policy and token ordering. ProjectFactory seeds single-sided liquidity using the **860,000,000 EMVO** allocation. The opening cap is a pricing parameter, not a promise of value, backing, redemption, or a requirement to deposit 2,500 IMD as matching liquidity.

Admission parameters are `fee = 3000`, `tickSpacing = 60`, and `initialPrice = "79228162514264337593543950336"` (sqrtPriceX96). That manifest price is a legacy input; the current standard route uses the policy's opening cap. **The actual pool trading fee is read from the official LaunchFees contract**, not inferred from the admission value `3000`.

The supplied standard terms are **1.25% per trade**: **1%** to the wallet that paid for the launch (the issuing wallet above), and **0.25%** to IMD's official protocol fee recipient. Anyone may claim accrued fees for those beneficiaries under the official machinery. These are pool fees; an ordinary EMVO transfer incurs zero token tax. The token implements no fee collection or fee setter. Verify these terms against the pinned policy and live LaunchFees at Check; a different value is a mismatch requiring explicit resolution, never a silent substitution. Liquidity ownership, withdrawal rights and protocol administrative powers require the actual policy; this deliverable makes no lock or burn claim about the LP.

## Check and launch status

`launch/intent.json` records the exact requested input, and `launch/check-status.json` records its SHA-256 and the missing official facts. They are local handoff documents, **not an official manifest or an approved quote**. The downstream manifest step must produce `launch.json` for this accepted source with `contracts: []` and the same resolved economics. See [launch/CHECK.md](launch/CHECK.md) for the required quote binding and verification.

The supplied files contain **no exact policy version, ProjectFactory address, mainnet IMD address, LaunchFees address, protocol fee-recipient address, launch-payment price/payee, gas sponsorship terms or actual Check quote**. These are unresolved launch blockers, not zero-valued defaults. An exact version/factory/payment fee cannot honestly be stated or a real quote bound without them. No lookalike address, placeholder factory or assumed payment amount is deployable. The actual quote remains `null`; neither payment nor deployment is ready.

## Operational responsibilities

- **Issuing wallet:** verify and accept the bound Check terms, then make the launch payment from the exact wallet above using the quoted asset, amount and official payee. It normally needs native ETH for its own approval/payment transaction gas, even though the pool pairs with IMD. A separate Report payer is not a substitute.
- **Official launch operator/deployer:** resolve the chain-1 policy and infrastructure, verify code and payment identity, produce the final manifest, use ProjectFactory to create the token and official infrastructure, and verify the deployed source/bytes and allocations. The sender of the factory transaction pays its Ethereum gas; the operator must disclose that sender and any sponsorship or reimbursement in the actual quote. This repository does not assume that the launch charge includes deployment gas.
- **Traders and claim submitters:** fund the ETH gas for their own approvals, swaps, Swarm claims or fee-claim transactions unless the official service explicitly sponsors them. Claiming fees for a beneficiary does not change that beneficiary.
- **Handoff operator:** record the exact deployed token/distributor addresses, transaction receipts, resolved fee recipients, liquidity ownership and full `poolKey`. Consumers must use that exact `poolKey`, including the official initialization guard. The guard restricts initialization only; it has no swap callbacks and does not itself add swap fees or determine liquidity ownership.

Only the issuer's use of its own receipts is unrestricted; holding EMVO confers no treasury ownership. No contributor task has authority to access keys or broadcast transactions.

## Planned utility and limits

Planned utility includes crypto token/NFT research discovery and a future Genesis PEPE paid NFT mint. A later, separately implemented Genesis contract is intended to take an exact EMVO payment to the issuing wallet and mint an NFT atomically: failure of either action must revert both. No burn is required, and the owner may freely use receipts. No Genesis contract, research service, website, treasury/vault or other product contract is implemented or deployed here. There is no yield, dividend, redemption, backing or price promise.

## Reproduce and review

With Foundry and the pinned Solidity 0.8.26 installed:

```sh
forge build
forge test
forge fmt --check
```

The build uses optimizer runs 200, Cancun EVM and `bytecode_hash = "none"`. All Solidity dependencies and their licenses are vendored as ordinary files; see [DEPENDENCIES.md](DEPENDENCIES.md). No FFI, filesystem cheatcode permissions, RPC, keys, environment variables or network are needed for tests. Test order and sender configuration are independent. Test-only creation probes and handlers are excluded from the launch's application list.

Coverage includes metadata, the one-time mint event and factory constructor context, exact transfer amounts, allocation arithmetic, zero/self/full-balance transfers, contract recipients without callbacks, approvals/revocation/infinite allowances, failures for insufficient balance/allowance and invalid recipients, rollback of allowance on failure, rejected admin/mint/burn/upgrade selectors, constant supply over time and runtime escape-opcode checks. Fuzz tests exercise transfer conservation and spending limits; a stateful invariant exercises transfers, approvals and delegated transfers over four holders while asserting exact balances and constant supply.

The local allocation test demonstrates token accounting only. It does not test the unavailable official factory, live pool, distributor, fee collection, admission snapshot, LP custody or actual quote/payment binding. No mainnet fork, Slither, Mythril or independent audit has run. The pinned protected checks were read; their production configuration is supplied separately by the verifier and is not fabricated here. Passing local tests, completed Report work and a free Check are **not security certification**. Independent adversarial review of the accepted source, final manifest and actual official deployment terms remains a release responsibility.
