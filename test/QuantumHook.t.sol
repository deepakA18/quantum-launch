// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {QuantumHook} from "../src/QuantumHook.sol";
import {IQuantumHook} from "../src/interfaces/IQuantumHook.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

/**
 * @title QuantumHookTest
 * @notice Production-level tests for QuantumHook contract
 */
contract QuantumHookTest is Test {
    using PoolIdLibrary for PoolKey;

    QuantumHook public hook;
    IPoolManager public poolManager;

    address public owner;
    address public factory;
    address public user;

    function setUp() public {
        owner = makeAddr("owner");
        factory = makeAddr("factory");
        user = makeAddr("user");

        poolManager = new PoolManager(owner);

        // Create hook with proper permissions
        hook = new QuantumHook(poolManager, owner);

        vm.prank(owner);
        hook.setAuthorizedFactory(factory, true);
    }

    function _createPoolKey(uint256 seed) internal view returns (PoolKey memory) {
        address token0 = address(uint160(uint256(keccak256(abi.encode(seed, "token0")))));
        address token1 = address(uint160(uint256(keccak256(abi.encode(seed, "token1")))));

        if (uint160(token0) > uint160(token1)) {
            (token0, token1) = (token1, token0);
        }

        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
    }

    /* ========== HOOK PERMISSION TESTS ========== */

    function test_GetHookPermissions() public view {
        Hooks.Permissions memory perms = hook.getHookPermissions();

        assertFalse(perms.beforeInitialize);
        assertTrue(perms.afterInitialize);
        assertFalse(perms.beforeAddLiquidity);
        assertFalse(perms.afterAddLiquidity);
        assertFalse(perms.beforeRemoveLiquidity);
        assertFalse(perms.afterRemoveLiquidity);
        assertTrue(perms.beforeSwap);
        assertTrue(perms.afterSwap);
        assertFalse(perms.beforeDonate);
        assertFalse(perms.afterDonate);
        assertTrue(perms.beforeSwapReturnDelta);
        assertFalse(perms.afterSwapReturnDelta);
    }

    /* ========== AUTHORIZATION TESTS ========== */

    function test_SetAuthorizedFactory() public {
        address newFactory = makeAddr("newFactory");

        hook.setAuthorizedFactory(newFactory, true);
        assertTrue(hook.authorizedFactories(newFactory));

        hook.setAuthorizedFactory(newFactory, false);
        assertFalse(hook.authorizedFactories(newFactory));
    }

    function test_RevertSetAuthorizedFactoryNonOwner() public {
        address newFactory = makeAddr("newFactory");

        vm.prank(user);
        vm.expectRevert();
        hook.setAuthorizedFactory(newFactory, true);
    }

    /* ========== POOL REGISTRATION TESTS ========== */

    function test_RegisterProposalPool() public {
        PoolKey memory poolKey = _createPoolKey(1);
        uint256 decisionId = 1;
        uint256 proposalId = 1;

        vm.prank(factory);
        hook.registerProposalPool(poolKey, decisionId, proposalId, factory);

        IQuantumHook.PoolMetadata memory metadata = hook.getPoolMetadata(poolKey);

        assertEq(metadata.decisionId, decisionId);
        assertEq(metadata.proposalId, proposalId);
        assertEq(metadata.factory, factory);
        assertEq(metadata.currentPrice, 1e18);
        assertTrue(metadata.isActive);
        assertFalse(metadata.isFrozen);

        (uint256 creditsReserve, uint256 tokensReserve) = hook.getPoolReserves(poolKey);
        assertEq(creditsReserve, 1000 * 1e18);
        assertEq(tokensReserve, 1000 * 1e18);
    }

    function test_RevertRegisterPoolUnauthorized() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(user);
        vm.expectRevert("QuantumHook: unauthorized factory");
        hook.registerProposalPool(poolKey, 1, 1, factory);
    }

    function test_RegisterMultiplePools() public {
        PoolKey memory pool1 = _createPoolKey(1);
        PoolKey memory pool2 = _createPoolKey(2);
        PoolKey memory pool3 = _createPoolKey(3);

        vm.startPrank(factory);
        hook.registerProposalPool(pool1, 1, 1, factory);
        hook.registerProposalPool(pool2, 1, 2, factory);
        hook.registerProposalPool(pool3, 2, 1, factory);
        vm.stopPrank();

        assertTrue(hook.isPoolRegistered(pool1));
        assertTrue(hook.isPoolRegistered(pool2));
        assertTrue(hook.isPoolRegistered(pool3));
    }

    /* ========== QUANTUM TRADE TESTS ========== */

    function test_ExecuteQuantumTrade() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        uint256 creditsIn = 100e18;
        (uint256 initialCredits, uint256 initialTokens) = hook.getPoolReserves(poolKey);

        vm.prank(factory);
        uint256 tokensOut = hook.executeQuantumTrade(poolKey, user, creditsIn, 0);

        assertGt(tokensOut, 0);

        (uint256 finalCredits, uint256 finalTokens) = hook.getPoolReserves(poolKey);
        assertEq(finalCredits, initialCredits + creditsIn);
        assertEq(finalTokens, initialTokens - tokensOut);

        IQuantumHook.PoolMetadata memory metadata = hook.getPoolMetadata(poolKey);
        assertEq(metadata.totalSupply, tokensOut);
    }

    function test_TradeIncreasesPrice() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        uint256 price1 = hook.getCurrentPrice(poolKey);

        vm.prank(factory);
        hook.executeQuantumTrade(poolKey, user, 100e18, 0);

        uint256 price2 = hook.getCurrentPrice(poolKey);
        assertGt(price2, price1);

        vm.prank(factory);
        hook.executeQuantumTrade(poolKey, user, 100e18, 0);

        uint256 price3 = hook.getCurrentPrice(poolKey);
        assertGt(price3, price2);
    }

    function test_RevertTradeInactivePool() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.startPrank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);
        hook.freezeProposalPool(poolKey, false);
        vm.stopPrank();

        vm.prank(factory);
        vm.expectRevert("QuantumHook: pool not active");
        hook.executeQuantumTrade(poolKey, user, 100e18, 0);
    }

    function test_RevertTradeUnauthorizedCaller() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        vm.prank(user);
        vm.expectRevert("QuantumHook: unauthorized caller");
        hook.executeQuantumTrade(poolKey, user, 100e18, 0);
    }

    function test_RevertTradeSlippageExceeded() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        uint256 creditsIn = 100e18;
        uint256 expectedTokens = hook.calculateTokensOut(poolKey, creditsIn);

        vm.prank(factory);
        vm.expectRevert("QuantumHook: slippage exceeded");
        hook.executeQuantumTrade(poolKey, user, creditsIn, expectedTokens + 1);
    }

    function testFuzz_QuantumTrade(uint96 creditsIn) public {
        vm.assume(creditsIn > 0 && creditsIn < 500e18);

        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        (uint256 initialCredits, uint256 initialTokens) = hook.getPoolReserves(poolKey);

        vm.prank(factory);
        uint256 tokensOut = hook.executeQuantumTrade(poolKey, user, creditsIn, 0);

        (uint256 finalCredits, uint256 finalTokens) = hook.getPoolReserves(poolKey);

        assertEq(finalCredits, initialCredits + creditsIn);
        assertEq(finalTokens, initialTokens - tokensOut);
        assertGt(tokensOut, 0);
        assertLt(tokensOut, initialTokens);
    }

    /* ========== FREEZE POOL TESTS ========== */

    function test_FreezeProposalPool() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        assertTrue(hook.isPoolActive(poolKey));

        vm.prank(factory);
        hook.freezeProposalPool(poolKey, true);

        assertFalse(hook.isPoolActive(poolKey));

        IQuantumHook.PoolMetadata memory metadata = hook.getPoolMetadata(poolKey);
        assertFalse(metadata.isActive);
        assertTrue(metadata.isFrozen);
    }

    function test_RevertFreezeUnauthorized() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        vm.prank(user);
        vm.expectRevert("QuantumHook: unauthorized caller");
        hook.freezeProposalPool(poolKey, true);
    }

    function test_RevertFreezeAlreadyFrozen() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.startPrank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);
        hook.freezeProposalPool(poolKey, true);
        vm.stopPrank();

        vm.prank(factory);
        vm.expectRevert("QuantumHook: pool already frozen");
        hook.freezeProposalPool(poolKey, true);
    }

    /* ========== PRICE CALCULATION TESTS ========== */

    function test_CalculateTokensOut() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        uint256 creditsIn = 100e18;
        uint256 tokensOut = hook.calculateTokensOut(poolKey, creditsIn);

        assertGt(tokensOut, 0);
        assertLt(tokensOut, 1000e18);
    }

    function test_GetCurrentPrice() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        uint256 price = hook.getCurrentPrice(poolKey);
        assertEq(price, 1e18);
    }

    function test_PriceChangesWithTrades() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        uint256[] memory prices = new uint256[](5);
        prices[0] = hook.getCurrentPrice(poolKey);

        for (uint256 i = 1; i < 5; i++) {
            vm.prank(factory);
            hook.executeQuantumTrade(poolKey, user, 50e18, 0);
            prices[i] = hook.getCurrentPrice(poolKey);
            assertGt(prices[i], prices[i-1]);
        }
    }

    /* ========== RESERVE MANAGEMENT TESTS ========== */

    function test_GetPoolReserves() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        (uint256 credits, uint256 tokens) = hook.getPoolReserves(poolKey);
        assertEq(credits, 1000e18);
        assertEq(tokens, 1000e18);
    }

    function test_EmergencyUpdateReserves() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        uint256 newCredits = 2000e18;
        uint256 newTokens = 500e18;

        hook.emergencyUpdateReserves(poolKey, newCredits, newTokens);

        (uint256 credits, uint256 tokens) = hook.getPoolReserves(poolKey);
        assertEq(credits, newCredits);
        assertEq(tokens, newTokens);

        uint256 newPrice = hook.getCurrentPrice(poolKey);
        assertGt(newPrice, 1e18);
    }

    function test_RevertEmergencyUpdateNonOwner() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        vm.prank(user);
        vm.expectRevert();
        hook.emergencyUpdateReserves(poolKey, 2000e18, 500e18);
    }

    /* ========== POOL METADATA TESTS ========== */

    function test_GetPoolMetadata() public {
        PoolKey memory poolKey = _createPoolKey(1);
        uint256 decisionId = 123;
        uint256 proposalId = 456;

        vm.prank(factory);
        hook.registerProposalPool(poolKey, decisionId, proposalId, factory);

        IQuantumHook.PoolMetadata memory metadata = hook.getPoolMetadata(poolKey);

        assertEq(metadata.decisionId, decisionId);
        assertEq(metadata.proposalId, proposalId);
        assertEq(metadata.factory, factory);
        assertEq(metadata.totalSupply, 0);
        assertEq(metadata.currentPrice, 1e18);
        assertTrue(metadata.isActive);
        assertFalse(metadata.isFrozen);
    }

    function test_IsPoolActive() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        assertTrue(hook.isPoolActive(poolKey));

        vm.prank(factory);
        hook.freezeProposalPool(poolKey, true);

        assertFalse(hook.isPoolActive(poolKey));
    }

    function test_GetPoolFactory() public {
        PoolKey memory poolKey = _createPoolKey(1);

        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);

        address poolFactory = hook.getPoolFactory(poolKey);
        assertEq(poolFactory, factory);
    }

    function test_IsPoolRegistered() public {
        PoolKey memory pool1 = _createPoolKey(1);
        PoolKey memory pool2 = _createPoolKey(2);

        assertFalse(hook.isPoolRegistered(pool1));

        vm.prank(factory);
        hook.registerProposalPool(pool1, 1, 1, factory);

        assertTrue(hook.isPoolRegistered(pool1));
        assertFalse(hook.isPoolRegistered(pool2));
    }

    /* ========== INTEGRATION TESTS ========== */

    function test_CompletePoolLifecycle() public {
        PoolKey memory poolKey = _createPoolKey(1);

        // 1. Register pool
        vm.prank(factory);
        hook.registerProposalPool(poolKey, 1, 1, factory);
        assertTrue(hook.isPoolActive(poolKey));

        // 2. Execute trades
        vm.startPrank(factory);
        uint256 tokens1 = hook.executeQuantumTrade(poolKey, user, 100e18, 0);
        uint256 tokens2 = hook.executeQuantumTrade(poolKey, user, 150e18, 0);
        uint256 tokens3 = hook.executeQuantumTrade(poolKey, user, 200e18, 0);
        vm.stopPrank();

        assertGt(tokens1, 0);
        assertGt(tokens2, 0);
        assertGt(tokens3, 0);

        // 3. Check metadata
        IQuantumHook.PoolMetadata memory metadata = hook.getPoolMetadata(poolKey);
        assertEq(metadata.totalSupply, tokens1 + tokens2 + tokens3);
        assertGt(metadata.currentPrice, 1e18);

        // 4. Freeze pool
        vm.prank(factory);
        hook.freezeProposalPool(poolKey, true);
        assertFalse(hook.isPoolActive(poolKey));

        // 5. Verify cannot trade after freeze
        vm.prank(factory);
        vm.expectRevert("QuantumHook: pool not active");
        hook.executeQuantumTrade(poolKey, user, 50e18, 0);
    }

    function test_MultiplePoolsIndependent() public {
        PoolKey memory pool1 = _createPoolKey(1);
        PoolKey memory pool2 = _createPoolKey(2);

        vm.startPrank(factory);
        hook.registerProposalPool(pool1, 1, 1, factory);
        hook.registerProposalPool(pool2, 1, 2, factory);

        hook.executeQuantumTrade(pool1, user, 200e18, 0);
        hook.executeQuantumTrade(pool2, user, 100e18, 0);
        vm.stopPrank();

        uint256 price1 = hook.getCurrentPrice(pool1);
        uint256 price2 = hook.getCurrentPrice(pool2);

        assertGt(price1, 1e18);
        assertGt(price2, 1e18);
        assertNotEq(price1, price2);

        IQuantumHook.PoolMetadata memory meta1 = hook.getPoolMetadata(pool1);
        IQuantumHook.PoolMetadata memory meta2 = hook.getPoolMetadata(pool2);

        assertNotEq(meta1.totalSupply, meta2.totalSupply);
    }

    function test_PoolIdGeneration() public view {
        PoolKey memory poolKey = _createPoolKey(1);

        PoolId poolId1 = hook.getPoolId(poolKey);
        PoolId poolId2 = poolKey.toId();

        assertEq(PoolId.unwrap(poolId1), PoolId.unwrap(poolId2));
    }
}
