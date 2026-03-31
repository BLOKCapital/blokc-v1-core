# Blok Capital Glossary

A comprehensive reference of terms, concepts, and keywords used across the Blok Capital protocol.

---

## Core Architecture (Diamond Pattern / EIP-2535)

| Term | Definition |
|------|-----------|
| **Diamond** | The main upgradeable proxy contract (Garden) that routes function calls to facets based on selectors. Central to EIP-2535. |
| **Facet** | A contract implementing specific functionality, registered with the Diamond and called via `delegatecall`. |
| **Function Selector** | 4-byte identifier (`bytes4`) derived from a function signature hash, used to route calls to the correct facet. |
| **Facet Cut** | A data structure containing a facet address, action (Add/Replace/Remove), and selectors to modify. |
| **Facet Cut Action** | Enum: `Add` (0), `Replace` (1), `Remove` (2) — determines how the Diamond is modified. |
| **DiamondCut** | The function that applies facet cuts to modify the Diamond's routing table. |
| **DiamondLoupe** | Query interface for inspecting a Diamond's current facets, selectors, and routing. |
| **Module** | Logical grouping of related facets. Each facet belongs to exactly one module. |
| **Base Module** | Immutable module (`keccak256("BASE")`) containing the 4 core facets — always included in every Garden. |
| **Delegatecall** | Low-level EVM call that executes external code in the calling contract's storage context. |

## Garden & Factory

| Term | Definition |
|------|-----------|
| **Garden** | The Diamond contract(user's vault) that holds tokens and implements strategies through facets. |
| **GardenFactory** | Factory contract deploying new Gardens via `CREATE2` deterministic deployment. |
| **Garden Index** | Numeric value (1-10) uniquely identifying one of a user's Gardens for deterministic address calculation. |
| **Garden Type** | Categorization of a Garden that determines which optional modules it can use. |
| **Garden Owner** | The address that created/owns a Garden and controls its operations. |
| **Facet Registry** | Central registry managing all facets, modules, garden types, and their versions. |

## Index & Rebalancing

| Term | Definition |
|------|-----------|
| **Index** | A contract managing a diversified portfolio of asset components with calculated weights. |
| **Index Component** | An ERC20 token included in an Index's composition, paired with a Chainlink price feed. |
| **Index Calculation Strategy** | Pluggable contract that computes asset weights (e.g., `MarketCapWeighted`). |
| **Rebalance** | Process of adjusting Garden holdings to match target Index allocations. |
| **Rebalance Intent** | A pending rebalance containing current values, target values, and weights for all components. |
| **Rebalance Interval** | Minimum time (1 hour) between consecutive rebalances. |
| **Swap Call** | Individual swap instruction from CRE containing selector, encoded data, output token, and minimum output. |
| **Component Weights** | Normalized allocation percentages for Index components (scaled to 1e18). |
| **Market Cap Weighted** | Strategy that weights components proportionally to their market cap. |

## Protocol Governance & Status

| Term | Definition |
|------|-----------|
| **Protocol Status** | Enum: `ACTIVE`, `UPGRADES_DISABLED`, or `INACTIVE` — controls protocol-level behavior. |
| **Security Council Member (SCM)** | DAO member tracked via ENS who can authorize protocol state changes. |
| **ENS Namehash** | Hash identifier of an ENS domain used to track SCM membership. |

## DEX & Liquidity

| Term | Definition |
|------|-----------|
| **Liquidity Pool** | AMM pool registered in the `LiquidityPoolRegistry` for token swapping. |
| **DEX ID** | `bytes32` identifier for a DEX platform (e.g., `keccak256("UNISWAP_V3")`). |
| **Pair ID** | Canonical identifier (`keccak256` of ordered token addresses) for a token pair across all DEXes. |
| **Fee Tier** | Fee percentage for concentrated liquidity pools (`uint24`: 500, 3000, 10000 basis points). |
| **Exact Input Swap** | Swap with a fixed input amount and variable output. |
| **Exact Output Swap** | Swap with a fixed output amount and variable input. |
| **Slippage Protection** | Min output (`amountOutMin`) or max input (`amountInMax`) to prevent unfavorable swaps. |
| **Swap Path** | Sequence of token hops for multi-pool swaps (e.g., WETH -> USDC -> DAI). |
| **TWAP (Time-Weighted Average Price)** | Oracle price from historical observations, resistant to flash loan manipulation. |
| **Sqrt Price X96** | Uniswap V3's internal price representation in Q64.96 fixed-point format. |

## Cross-Chain (CCTP)

| Term | Definition |
|------|-----------|
| **CCTP** | Circle Cross-Chain Transfer Protocol for bridging USDC across chains. |
| **Destination Domain** | Circle domain ID for a blockchain (1 = Ethereum, 42161 = Arbitrum, etc.). |
| **TokenMessengerV2** | Circle contract for initiating cross-chain USDC burns. |
| **MessageTransmitterV2** | Circle contract for receiving/verifying cross-chain messages. |

## NFT & Membership

| Term | Definition |
|------|-----------|
| **Reward Collection** | ERC721 NFT collection minted by Gardens to track their own contributions. |
| **SBT (Soulbound Token)** | Non-transferable NFT (ERC-5484) representing membership. |
| **SBT Registry** | Registry managing SBT collections and minting permissions. |

## Storage & Internals

| Term | Definition |
|------|-----------|
| **Storage Layout (EIP-7201)** | Namespaced storage using `LibStorageSlot` to prevent slot collisions across facets. |
| **LibDiamond** | Core library storing Diamond metadata (facetRegistry, protocolStatus, gardenType, etc.). |
| **Price Feed / Heartbeat** | Chainlink `AggregatorV3` oracle; heartbeat is max staleness interval before data is considered stale. |
| **Self-call** | A Garden calling its own Diamond proxy (`msg.sender == address(this)`) for internal facet composability. |
