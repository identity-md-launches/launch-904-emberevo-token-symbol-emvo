# Vendored dependencies

The repository contains ordinary source files, not submodules. No dependency installation or network access is required to build or test with Solidity 0.8.26 installed.

| Dependency | Pinned release | Included files | Archive SHA-256 |
| --- | --- | --- | --- |
| OpenZeppelin Contracts | `v5.0.2` | ERC20 and its four transitive Solidity imports, MIT license | `18c7b7e949b9a82dcd8cd394426c9c2636dfc263aa2317d4749dbfa0c7b3925a` |
| forge-std | `v1.9.7` | Complete `src/`, MIT and Apache licenses | `45157353ab49eab01d294565866731e599b32401757229689ee459aa26b7ee94` |

Sources:

- https://codeload.github.com/OpenZeppelin/openzeppelin-contracts/tar.gz/refs/tags/v5.0.2
- https://codeload.github.com/foundry-rs/forge-std/tar.gz/refs/tags/v1.9.7

The selected source files are unmodified. Only OpenZeppelin's base ERC-20 is inherited by the production token. forge-std is used exclusively in tests. Its cheatcode interface includes filesystem, environment and FFI operations, but this project's tests do not use them and the Foundry configuration grants no filesystem or FFI permission.
