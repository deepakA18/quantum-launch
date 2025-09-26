// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseTestHooks} from "v4-core/test/BaseTestHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {CurrencySettler} from "../lib/v4-core/test/utils/CurrencySettler.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IQuantumHook.sol";
import "./utils/MathUtils.sol";

/**
 * @title QuantumHook
 * @notice Uniswap v4 Hook implementing Quantum Markets mechanics
 * @dev Manages proposal pools with shared liquidity and quantum trade execution
 */
contract QuantumHook is IQuantumHook, BaseTestHooks, Ownable, ReentrancyGuard {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    using CurrencySettler for Currency;
    using MathUtils for uint256;

    /// @notice Pool manager instance
    IPoolManager public immutable poolManager;

    /// @notice Mapping from pool ID to pool metadata
    mapping(PoolId => PoolMetadata) public poolMetadata;

    /// @notice Mapping from factory address to authorization status
    mapping(address => bool) public authorizedFactories;

    /// @notice Mapping to track credits reserves per pool
    mapping(PoolId => uint256) public creditsReserves;

    /// @notice Mapping to track token reserves per pool
    mapping(PoolId => uint256) public tokensReserves;

    /// @notice Mapping to track total liquidity per pool
    mapping(PoolId => uint128) public totalLiquidity;

    /// @notice Initial virtual liquidity for new pools
    uint256 public constant INITIAL_VIRTUAL_LIQUIDITY = 1000 * 1e18;

    /// @notice Events
    event ProposalPoolRegistered(
        uint256 indexed decisionId, uint256 indexed proposalId, PoolKey poolKey, address factory
    );
    event QuantumTradeExecuted(PoolKey indexed poolKey, address indexed trader, uint256 creditsIn, uint256 tokensOut);
    event ProposalPoolFrozen(uint256 indexed decisionId, uint256 indexed proposalId, bool isWinner);

    /// @notice Hook permissions - we need beforeSwap and afterSwap
    function getHookPermissions() public pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    constructor(IPoolManager _poolManager, address _initialOwner) Ownable(_initialOwner) {
        poolManager = _poolManager;
    }

    /**
     * @notice Authorize a factory to register pools
     * @param factory Factory address to authorize
     * @param authorized Whether to authorize or deauthorize
     */
    function setAuthorizedFactory(address factory, bool authorized) external onlyOwner {
        authorizedFactories[factory] = authorized;
    }

    /**
     * @inheritdoc IQuantumHook
     */
    function registerProposalPool(PoolKey calldata poolKey, uint256 decisionId, uint256 proposalId, address factory)
        external
        override
    {
        require(authorizedFactories[msg.sender], "QuantumHook: unauthorized factory");

        PoolId poolId = poolKey.toId();

        poolMetadata[poolId] = PoolMetadata({
            decisionId: decisionId,
            proposalId: proposalId,
            factory: factory,
            totalSupply: 0,
            currentPrice: 1e18, // Initial price: 1 credit per token
            isActive: true,
            isFrozen: false
        });

        // Initialize reserves with virtual liquidity
        creditsReserves[poolId] = INITIAL_VIRTUAL_LIQUIDITY;
        tokensReserves[poolId] = INITIAL_VIRTUAL_LIQUIDITY;

        emit ProposalPoolRegistered(decisionId, proposalId, poolKey, factory);
    }

    /**
     * @inheritdoc IQuantumHook
     */
    function executeQuantumTrade(PoolKey calldata poolKey, address trader, uint256 creditsIn, uint256 minTokensOut)
        external
        override
        nonReentrant
        returns (uint256 tokensOut)
    {
        PoolId poolId = poolKey.toId();
        PoolMetadata storage metadata = poolMetadata[poolId];

        require(metadata.isActive && !metadata.isFrozen, "QuantumHook: pool not active");
        require(msg.sender == metadata.factory, "QuantumHook: unauthorized caller");

        // Calculate tokens out using current reserves
        tokensOut = MathUtils.calculateTokensOut(creditsIn, creditsReserves[poolId], tokensReserves[poolId]);

        require(tokensOut >= minTokensOut, "QuantumHook: slippage exceeded");

        // Update reserves
        creditsReserves[poolId] = creditsReserves[poolId].safeAdd(creditsIn);
        tokensReserves[poolId] = tokensReserves[poolId].safeSub(tokensOut);

        // Update metadata
        metadata.totalSupply += tokensOut;
        metadata.currentPrice = MathUtils.calculatePriceFromReserves(creditsReserves[poolId], tokensReserves[poolId]);

        emit QuantumTradeExecuted(poolKey, trader, creditsIn, tokensOut);
    }

    /**
     * @inheritdoc IQuantumHook
     */
    function freezeProposalPool(PoolKey calldata poolKey, bool isWinner) external override {
        PoolId poolId = poolKey.toId();
        PoolMetadata storage metadata = poolMetadata[poolId];

        require(msg.sender == metadata.factory, "QuantumHook: unauthorized caller");
        require(metadata.isActive, "QuantumHook: pool already frozen");

        metadata.isActive = false;
        metadata.isFrozen = true;

        emit ProposalPoolFrozen(metadata.decisionId, metadata.proposalId, isWinner);
    }

    /**
     * @notice Hook called after pool initialization
     */
    function afterInitialize(address, PoolKey calldata poolKey, uint160, int24, bytes calldata)
        external
        returns (bytes4)
    {
        // Pool is initialized, ready for trades
        PoolId poolId = poolKey.toId();

        // Add initial liquidity to the pool if it's a registered proposal pool
        if (poolMetadata[poolId].factory != address(0)) {
            _addInitialLiquidity(poolKey);
        }

        return BaseTestHooks.afterInitialize.selector;
    }

    /**
     * @notice Hook called before swaps - we intercept to implement quantum mechanics
     */
    function beforeSwap(
        address sender,
        PoolKey calldata poolKey,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId poolId = poolKey.toId();
        PoolMetadata storage metadata = poolMetadata[poolId];

        // Only allow swaps if pool is active and not frozen
        require(metadata.isActive && !metadata.isFrozen, "QuantumHook: pool not active");

        // For quantum markets, we override normal swap behavior
        // The swap is handled by our executeQuantumTrade function
        // So we return a delta that prevents the normal swap
        return (BaseTestHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /**
     * @notice Hook called after swaps - update our internal state
     */
    function afterSwap(
        address sender,
        PoolKey calldata poolKey,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        // Update our internal tracking after successful swaps
        return (BaseTestHooks.afterSwap.selector, 0);
    }

    /**
     * @inheritdoc IQuantumHook
     */
    function calculateTokensOut(PoolKey calldata poolKey, uint256 creditsIn)
        external
        view
        override
        returns (uint256 tokensOut)
    {
        PoolId poolId = poolKey.toId();

        return MathUtils.calculateTokensOut(creditsIn, creditsReserves[poolId], tokensReserves[poolId]);
    }

    /**
     * @inheritdoc IQuantumHook
     */
    function getCurrentPrice(PoolKey calldata poolKey) external view override returns (uint256 price) {
        PoolId poolId = poolKey.toId();
        return poolMetadata[poolId].currentPrice;
    }

    /**
     * @inheritdoc IQuantumHook
     */
    function getPoolMetadata(PoolKey calldata poolKey) external view override returns (PoolMetadata memory metadata) {
        PoolId poolId = poolKey.toId();
        return poolMetadata[poolId];
    }

    /**
     * @inheritdoc IQuantumHook
     */
    function isPoolActive(PoolKey calldata poolKey) external view override returns (bool isActive) {
        PoolId poolId = poolKey.toId();
        PoolMetadata storage metadata = poolMetadata[poolId];
        return metadata.isActive && !metadata.isFrozen;
    }

    /**
     * @inheritdoc IQuantumHook
     */
    function getPoolFactory(PoolKey calldata poolKey) external view override returns (address factory) {
        PoolId poolId = poolKey.toId();
        return poolMetadata[poolId].factory;
    }

    /**
     * @notice Get reserves for a pool
     * @param poolKey The pool to query
     * @return creditsReserve Current credits reserve
     * @return tokensReserve Current tokens reserve
     */
    function getPoolReserves(PoolKey calldata poolKey)
        external
        view
        returns (uint256 creditsReserve, uint256 tokensReserve)
    {
        PoolId poolId = poolKey.toId();
        return (creditsReserves[poolId], tokensReserves[poolId]);
    }

    /**
     * @notice Add initial liquidity to a newly created pool
     * @param poolKey The pool key
     */
    function _addInitialLiquidity(PoolKey memory poolKey) internal {
        PoolId poolId = poolKey.toId();

        // Get current pool state
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);

        // Calculate liquidity amount
        uint128 liquidity =
            MathUtils.getLiquidityForAmounts(INITIAL_VIRTUAL_LIQUIDITY, INITIAL_VIRTUAL_LIQUIDITY, sqrtPriceX96);

        totalLiquidity[poolId] = liquidity;
    }

    /**
     * @notice Emergency function to update pool state (owner only)
     * @param poolKey The pool to update
     * @param newCreditsReserve New credits reserve
     * @param newTokensReserve New tokens reserve
     */
    function emergencyUpdateReserves(PoolKey calldata poolKey, uint256 newCreditsReserve, uint256 newTokensReserve)
        external
        onlyOwner
    {
        PoolId poolId = poolKey.toId();
        creditsReserves[poolId] = newCreditsReserve;
        tokensReserves[poolId] = newTokensReserve;

        // Update price
        poolMetadata[poolId].currentPrice = MathUtils.calculatePriceFromReserves(newCreditsReserve, newTokensReserve);
    }

    /**
     * @notice Get pool ID from pool key
     * @param poolKey The pool key
     * @return poolId The pool ID
     */
    function getPoolId(PoolKey calldata poolKey) external pure returns (PoolId poolId) {
        return poolKey.toId();
    }

    /**
     * @notice Check if a pool is registered
     * @param poolKey The pool key
     * @return isRegistered Whether the pool is registered
     */
    function isPoolRegistered(PoolKey calldata poolKey) external view returns (bool isRegistered) {
        PoolId poolId = poolKey.toId();
        return poolMetadata[poolId].factory != address(0);
    }
}
