# EmberEvo test scope

Run `forge build` and `forge test` from the repository root. Tests use the
vendored dependencies, require no network or environment variables, and never
call `vm.setEnv`. No production source or configuration changes are needed.

The existing token suite checks EmberEvo / EMVO metadata, the single mint of
`10^27` base units, construction by a factory-like caller, plain transfers,
allocation arithmetic, and rejection of common administrative selectors. The
selector probes now encode each signature's actual argument types, including
the dynamic bytes argument of `upgradeToAndCall(address,bytes)`.

`LaunchToken.adversarial.t.sol` adds allowance isolation, issuer and transaction
origin impersonation, self-directed delegated transfers, approval replacement
and revocation, rollback after failed delegated spending, zero recipients and
spenders, native-value rejection, and one-unit/full-supply/uint256 boundaries.
Its three fuzz properties each run 1,000 cases.

`LaunchToken.invariant.t.sol` runs 256 sequences of depth 96, checking three invariants.
Ten handler actions interleave transfers, approvals, delegated spending,
boundary approvals, full-balance movements, expected failures and elapsed time
across four holders, including the issuing wallet. Independent ghost balances
and all 16 owner/spender allowances must match the token after every action;
the supply and metadata stay fixed. Unexpected handler reverts fail the run.
A deterministic sequence also exercises positive delegated spending, revocation,
rejection, recovery and return of the entire supply to the initial holder.

The holder set is closed for accounting: these handlers transfer only between
those four addresses. Test-only callers and deployment probes have no place in
the launch application's `contracts` array.

## Verification limits

The pinned token and project checks were read. Their official deployment inputs
are supplied separately to the verifier; this suite does not invent them or
claim to run those checks with production configuration.

The local allocation test demonstrates only exact ERC-20 transfers of
860,000,000 / 100,000,000 / 40,000,000 EMVO. It cannot prove that ProjectFactory
allocates those amounts to the actual pool, official Swarm distributor and
`0x1C651928150DADDDA9C2C040a9D4901d862f8eC4` on Ethereum mainnet.

As already recorded in `launch/check-status.json`, the official policy version,
factory, IMD pair address, LaunchFees and protocol recipient, launch-payment and
gas terms, and actual quote/binding are absent. Verifying those facts, the
2,500 IMD opening cap, the 125 bps pool fee split (100 bps to the issuing launch
payer / 25 bps to IMD), and payment by that exact issuer requires the official
infrastructure and quote. They remain launch blockers, not passing assertions.

No token implementation defect was reproduced. These tests do not certify the
launch, a previous Report, or a free Check. No Genesis or other product contract
is implemented or tested by this deliverable.
