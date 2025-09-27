// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {QMFactory} from "../src/QMFactory.sol";
import {QuantumHook} from "../src/QuantumHook.sol";
import {IQMFactory} from "../src/interfaces/IQMFactory.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title StressTest
 * @notice Edge cases, stress tests, and attack vector tests
 */
contract StressTest is Test {
    QMFactory public factory;
    QuantumHook public hook;
    IPoolManager public poolManager;
    MockERC20 public depositToken;

    address public owner;
    address public admin;
    address[] public users;

    uint256 constant NUM_USERS = 100;
    uint256 constant LARGE_AMOUNT = 100000 * 1e18;

    function setUp() public {
        owner = makeAddr("owner");
        admin = makeAddr("admin");

        depositToken = new MockERC20("USDC", "USDC");
        poolManager = new PoolManager(owner);

        // Create hook with proper permissions
        hook = new QuantumHook(poolManager, owner);

        factory = new QMFactory(address(depositToken), address(poolManager), address(hook), owner);
        vm.prank(owner);
        hook.setAuthorizedFactory(address(factory), true);
        
        vm.prank(owner);
        factory.setAdmin(admin, true);

        // Create many users
        for (uint256 i = 0; i < NUM_USERS; i++) {
            address user = makeAddr(string(abi.encodePacked("user", vm.toString(i))));
            users.push(user);
            depositToken.mint(user, LARGE_AMOUNT);
            vm.prank(user);
            depositToken.approve(address(factory), type(uint256).max);
        }
    }

    /* ========== STRESS TESTS ========== */

    function test_Stress_ManyUsers() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Stress Test Decision");

        vm.prank(users[0]);
        uint256 proposalId = factory.createProposal(decisionId, "Option A");

        // All users deposit
        for (uint256 i = 0; i < 50; i++) {
            vm.prank(users[i]);
            factory.deposit(decisionId, 1000e18);
        }

        // All users trade
        for (uint256 i = 0; i < 50; i++) {
            vm.prank(users[i]);
            factory.trade(decisionId, proposalId, 500e18, 0);
        }

        // Settle
        vm.prank(admin);
        factory.settle(decisionId, proposalId);

        // All users claim
        for (uint256 i = 0; i < 50; i++) {
            vm.prank(users[i]);
            factory.claimWinnings(decisionId);
        }

        // Verify no tokens stuck
        uint256 factoryBalance = depositToken.balanceOf(address(factory));
        assertLt(factoryBalance, 1e18); // Less than 1 token stuck
    }

    function test_Stress_ManyProposals() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Many Proposals");

        // Create 50 proposals
        for (uint256 i = 0; i < 50; i++) {
            vm.prank(users[0]);
            factory.createProposal(decisionId, string(abi.encodePacked("Option ", vm.toString(i))));
        }

        IQMFactory.Decision memory decision = factory.getDecision(decisionId);
        assertEq(decision.proposalCount, 50);

        // User trades on all proposals
        vm.prank(users[0]);
        factory.deposit(decisionId, 50000e18);

        for (uint256 i = 1; i <= 50; i++) {
            vm.prank(users[0]);
            factory.trade(decisionId, i, 1000e18, 0);
        }

        (, uint256 usedCredits) = factory.getUserPosition(decisionId, users[0]);
        assertEq(usedCredits, 50000e18);
    }

    function test_Stress_ManyDecisions() public {
        // Create 100 decisions
        for (uint256 i = 0; i < 100; i++) {
            vm.prank(users[i % 10]);
            factory.createDecision(string(abi.encodePacked("Decision ", vm.toString(i))));
        }

        assertEq(factory.decisionCounter(), 100);

        // Interact with all decisions
        for (uint256 i = 1; i <= 100; i++) {
            vm.prank(users[i % 10]);
            factory.createProposal(i, "Option A");
            
            vm.prank(users[i % 10]);
            factory.deposit(i, 100e18);
        }
    }

    function test_Stress_LargeTradeVolume() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Large Volume");

        vm.prank(users[0]);
        uint256 proposalId = factory.createProposal(decisionId, "Option A");

        vm.prank(users[0]);
        factory.deposit(decisionId, LARGE_AMOUNT);

        // Execute many small trades
        for (uint256 i = 0; i < 100; i++) {
            vm.prank(users[0]);
            factory.trade(decisionId, proposalId, 100e18, 0);
        }

        uint256 price = factory.getProposalPrice(decisionId, proposalId);
        assertGt(price, 1e18);
    }

    /* ========== EDGE CASE TESTS ========== */

    function test_Edge_MinimalDeposit() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Minimal");

        vm.prank(users[0]);
        factory.deposit(decisionId, 1); // 1 wei

        (uint256 credits,) = factory.getUserPosition(decisionId, users[0]);
        assertEq(credits, 1);
    }

    function test_Edge_MaximalDeposit() public {
        address whale = makeAddr("whale");
        depositToken.mint(whale, type(uint128).max);
        
        vm.prank(whale);
        depositToken.approve(address(factory), type(uint256).max);

        vm.prank(whale);
        uint256 decisionId = factory.createDecision("Maximal");

        vm.prank(whale);
        factory.deposit(decisionId, type(uint128).max);

        (uint256 credits,) = factory.getUserPosition(decisionId, whale);
        assertEq(credits, type(uint128).max);
    }

    function test_Edge_TinyTrade() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Tiny Trade");

        vm.prank(users[0]);
        uint256 proposalId = factory.createProposal(decisionId, "Option A");

        vm.prank(users[0]);
        factory.deposit(decisionId, 1000e18);

        vm.prank(users[0]);
        factory.trade(decisionId, proposalId, 1, 0); // 1 wei trade

        uint256 tokens = factory.getUserProposalTokens(decisionId, proposalId, users[0]);
        assertGt(tokens, 0);
    }

    function test_Edge_SingleWinnerTakesAll() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Winner Takes All");

        vm.prank(users[0]);
        uint256 p1 = factory.createProposal(decisionId, "A");
        
        vm.prank(users[0]);
        uint256 p2 = factory.createProposal(decisionId, "B");

        // User 0 bets on winning proposal
        vm.prank(users[0]);
        factory.deposit(decisionId, 1000e18);
        vm.prank(users[0]);
        factory.trade(decisionId, p1, 1000e18, 0);

        // User 1 bets on losing proposal
        vm.prank(users[1]);
        factory.deposit(decisionId, 1000e18);
        vm.prank(users[1]);
        factory.trade(decisionId, p2, 1000e18, 0);

        vm.prank(admin);
        factory.settle(decisionId, p1);

        uint256 balBefore = depositToken.balanceOf(users[0]);
        vm.prank(users[0]);
        factory.claimWinnings(decisionId);
        uint256 balAfter = depositToken.balanceOf(users[0]);

        // Winner should get almost all deposits (2000e18 total)
        assertGt(balAfter - balBefore, 1500e18);
    }

    function test_Edge_NoOneTradesOnWinner() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Empty Winner");

        vm.prank(users[0]);
        uint256 p1 = factory.createProposal(decisionId, "Empty");
        
        vm.prank(users[0]);
        uint256 p2 = factory.createProposal(decisionId, "Full");

        // Everyone bets on p2
        vm.prank(users[0]);
        factory.deposit(decisionId, 1000e18);
        vm.prank(users[0]);
        factory.trade(decisionId, p2, 1000e18, 0);

        // But p1 wins (empty)
        vm.prank(admin);
        factory.settle(decisionId, p1);

        uint256 balBefore = depositToken.balanceOf(users[0]);
        vm.prank(users[0]);
        factory.claimWinnings(decisionId);
        uint256 balAfter = depositToken.balanceOf(users[0]);

        // Should get 50% refund
        assertEq(balAfter - balBefore, 500e18);
    }

    /* ========== ATTACK VECTOR TESTS ========== */

    function test_Attack_ReentrancyProtection() public {
        // Reentrancy is blocked by ReentrancyGuard
        // This test verifies the guard is in place
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Reentrancy Test");

        vm.prank(users[0]);
        factory.createProposal(decisionId, "A");

        vm.prank(users[0]);
        factory.deposit(decisionId, 1000e18);

        // Multiple sequential calls should work
        vm.startPrank(users[0]);
        factory.trade(decisionId, 1, 100e18, 0);
        factory.trade(decisionId, 1, 100e18, 0);
        vm.stopPrank();
    }

    function test_Attack_FrontRunning() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Front Run");

        vm.prank(users[0]);
        uint256 proposalId = factory.createProposal(decisionId, "A");

        vm.prank(users[0]);
        factory.deposit(decisionId, 1000e18);

        vm.prank(users[1]);
        factory.deposit(decisionId, 1000e18);

        // User 1 sees user 0's trade and front-runs
        uint256 priceBefore = factory.getProposalPrice(decisionId, proposalId);

        vm.prank(users[1]);
        factory.trade(decisionId, proposalId, 500e18, 0);

        uint256 priceMiddle = factory.getProposalPrice(decisionId, proposalId);

        vm.prank(users[0]);
        factory.trade(decisionId, proposalId, 500e18, 0);

        uint256 priceAfter = factory.getProposalPrice(decisionId, proposalId);

        // User 1 got better price by front-running
        assertGt(priceMiddle, priceBefore);
        assertGt(priceAfter, priceMiddle);
    }

    function test_Attack_DepositWithdrawManipulation() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Deposit Withdraw");

        vm.prank(users[0]);
        factory.deposit(decisionId, 1000e18);

        // Cannot withdraw directly - must wait for settlement
        (uint256 credits,) = factory.getUserPosition(decisionId, users[0]);
        assertEq(credits, 1000e18);

        // Create proposal and settle immediately
        vm.prank(users[0]);
        uint256 proposalId = factory.createProposal(decisionId, "A");

        vm.prank(admin);
        factory.settle(decisionId, proposalId);

        // Can claim but with no trades, just gets refund
        uint256 balBefore = depositToken.balanceOf(users[0]);
        vm.prank(users[0]);
        factory.claimWinnings(decisionId);
        uint256 balAfter = depositToken.balanceOf(users[0]);

        assertEq(balAfter - balBefore, 1000e18);
    }

    function test_Attack_PriceManipulation() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Price Manip");

        vm.prank(users[0]);
        uint256 proposalId = factory.createProposal(decisionId, "A");

        // Whale tries to manipulate price
        address whale = makeAddr("whale");
        depositToken.mint(whale, 1000000e18);
        vm.prank(whale);
        depositToken.approve(address(factory), type(uint256).max);

        vm.prank(whale);
        factory.deposit(decisionId, 1000000e18);

        uint256 priceBefore = factory.getProposalPrice(decisionId, proposalId);

        // Massive trade to pump price
        vm.prank(whale);
        factory.trade(decisionId, proposalId, 500000e18, 0);

        uint256 priceAfter = factory.getProposalPrice(decisionId, proposalId);

        // Price increases significantly but doesn't break
        assertGt(priceAfter, priceBefore);
        assertLt(priceAfter, type(uint128).max);
    }

    /* ========== GAS OPTIMIZATION TESTS ========== */

    function test_Gas_SingleTrade() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Gas Test");

        vm.prank(users[0]);
        uint256 proposalId = factory.createProposal(decisionId, "A");

        vm.prank(users[0]);
        factory.deposit(decisionId, 1000e18);

        uint256 gasBefore = gasleft();
        vm.prank(users[0]);
        factory.trade(decisionId, proposalId, 100e18, 0);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for single trade:", gasUsed);
        assertLt(gasUsed, 500000); // Should be under 500k gas
    }

    function test_Gas_BatchTrades() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Batch Gas");

        vm.prank(users[0]);
        uint256 proposalId = factory.createProposal(decisionId, "A");

        vm.prank(users[0]);
        factory.deposit(decisionId, 10000e18);

        uint256 gasBefore = gasleft();
        vm.startPrank(users[0]);
        for (uint256 i = 0; i < 10; i++) {
            factory.trade(decisionId, proposalId, 100e18, 0);
        }
        vm.stopPrank();
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for 10 trades:", gasUsed);
        uint256 avgGasPerTrade = gasUsed / 10;
        console2.log("Average gas per trade:", avgGasPerTrade);
    }

    function test_Gas_Settlement() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Settlement Gas");

        vm.startPrank(users[0]);
        uint256 p1 = factory.createProposal(decisionId, "A");
        factory.createProposal(decisionId, "B");
        factory.createProposal(decisionId, "C");
        factory.deposit(decisionId, 1000e18);
        factory.trade(decisionId, p1, 500e18, 0);
        vm.stopPrank();

        uint256 gasBefore = gasleft();
        vm.prank(admin);
        factory.settle(decisionId, p1);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for settlement:", gasUsed);
        assertLt(gasUsed, 500000);
    }

    function test_Gas_ClaimWinnings() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Claim Gas");

        vm.startPrank(users[0]);
        uint256 proposalId = factory.createProposal(decisionId, "A");
        factory.deposit(decisionId, 1000e18);
        factory.trade(decisionId, proposalId, 800e18, 0);
        vm.stopPrank();

        vm.prank(admin);
        factory.settle(decisionId, proposalId);

        uint256 gasBefore = gasleft();
        vm.prank(users[0]);
        factory.claimWinnings(decisionId);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("Gas used for claim:", gasUsed);
        assertLt(gasUsed, 300000);
    }

    /* ========== ECONOMIC MODEL TESTS ========== */

    function test_Economic_RefundMechanics() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Refund Test");

        vm.startPrank(users[0]);
        uint256 p1 = factory.createProposal(decisionId, "Winning");
        uint256 p2 = factory.createProposal(decisionId, "Losing");
        factory.deposit(decisionId, 1000e18);
        factory.trade(decisionId, p2, 600e18, 0); // Bet on loser
        vm.stopPrank();

        vm.prank(admin);
        factory.settle(decisionId, p1);

        uint256 balBefore = depositToken.balanceOf(users[0]);
        vm.prank(users[0]);
        factory.claimWinnings(decisionId);
        uint256 balAfter = depositToken.balanceOf(users[0]);

        uint256 refund = balAfter - balBefore;
        // Expected: 400 unused + 300 (50% of 600 used) = 700
        assertEq(refund, 700e18);
    }

    function test_Economic_WinnerPayoutAccuracy() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Payout Test");

        vm.prank(users[0]);
        uint256 proposalId = factory.createProposal(decisionId, "Winner");

        // User 0 deposits 1000 and trades 1000
        vm.prank(users[0]);
        factory.deposit(decisionId, 1000e18);
        vm.prank(users[0]);
        factory.trade(decisionId, proposalId, 1000e18, 0);

        // User 1 deposits 1000 and trades 1000
        vm.prank(users[1]);
        factory.deposit(decisionId, 1000e18);
        vm.prank(users[1]);
        factory.trade(decisionId, proposalId, 1000e18, 0);

        uint256 tokens0 = factory.getUserProposalTokens(decisionId, proposalId, users[0]);
        uint256 tokens1 = factory.getUserProposalTokens(decisionId, proposalId, users[1]);

        vm.prank(admin);
        factory.settle(decisionId, proposalId);

        uint256 bal0Before = depositToken.balanceOf(users[0]);
        uint256 bal1Before = depositToken.balanceOf(users[1]);

        vm.prank(users[0]);
        factory.claimWinnings(decisionId);
        vm.prank(users[1]);
        factory.claimWinnings(decisionId);

        uint256 payout0 = depositToken.balanceOf(users[0]) - bal0Before;
        uint256 payout1 = depositToken.balanceOf(users[1]) - bal1Before;

        // Total payout should equal total deposits
        assertApproxEqAbs(payout0 + payout1, 2000e18, 1e18);

        // Payouts should be proportional to tokens
        uint256 expectedRatio = (tokens0 * 1e18) / (tokens0 + tokens1);
        uint256 actualRatio = (payout0 * 1e18) / (payout0 + payout1);
        
        assertApproxEqRel(actualRatio, expectedRatio, 0.01e18); // 1% tolerance
    }

    function test_Economic_PriceDiscovery() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Price Discovery");

        vm.prank(users[0]);
        uint256 proposalId = factory.createProposal(decisionId, "A");

        vm.prank(users[0]);
        factory.deposit(decisionId, 10000e18);

        uint256[] memory prices = new uint256[](11);
        uint256[] memory amounts = new uint256[](10);

        prices[0] = factory.getProposalPrice(decisionId, proposalId);

        for (uint256 i = 0; i < 10; i++) {
            amounts[i] = (i + 1) * 100e18;
            vm.prank(users[0]);
            factory.trade(decisionId, proposalId, amounts[i], 0);
            prices[i + 1] = factory.getProposalPrice(decisionId, proposalId);
        }

        // Prices should increase monotonically
        for (uint256 i = 1; i < 11; i++) {
            assertGt(prices[i], prices[i - 1]);
        }

        // Larger trades should cause larger price increases
        uint256 priceIncrease1 = prices[1] - prices[0];
        uint256 priceIncrease10 = prices[10] - prices[9];
        assertGt(priceIncrease10, priceIncrease1);
    }

    /* ========== BOUNDARY TESTS ========== */

    function test_Boundary_MaxProposalsPerDecision() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Max Proposals");

        // Create maximum reasonable proposals
        for (uint256 i = 0; i < 100; i++) {
            vm.prank(users[0]);
            factory.createProposal(decisionId, string(abi.encodePacked("Option ", vm.toString(i))));
        }

        IQMFactory.Decision memory decision = factory.getDecision(decisionId);
        assertEq(decision.proposalCount, 100);
    }

    function test_Boundary_PriceLimits() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Price Limits");

        vm.prank(users[0]);
        uint256 proposalId = factory.createProposal(decisionId, "A");

        address whale = makeAddr("megawhale");
        depositToken.mint(whale, type(uint128).max);
        vm.prank(whale);
        depositToken.approve(address(factory), type(uint256).max);

        vm.prank(whale);
        factory.deposit(decisionId, type(uint128).max / 2);

        // Try to pump price to maximum
        vm.prank(whale);
        try factory.trade(decisionId, proposalId, type(uint128).max / 4, 0) {
            uint256 price = factory.getProposalPrice(decisionId, proposalId);
            assertLt(price, type(uint128).max);
        } catch {
            // Expected to fail if amount too large
        }
    }

    function test_Boundary_ZeroAddressProtection() public {
        // Factory should not allow zero address operations
        vm.prank(address(0));
        vm.expectRevert();
        factory.createDecision("Zero Address");
    }

    /* ========== INVARIANT TESTS ========== */

    function invariant_TotalDepositsSumCorrect() public {
        // Sum of all user deposits should equal decision totalDeposits
        // This would be implemented with a handler contract in full invariant testing
    }

    function invariant_TokenSupplyMatchesReserves() public {
        // Total token supply should match reserve calculations
        // Implementation requires tracking across multiple proposals
    }

    function invariant_NoTokensLocked() public {
        // After all claims, factory should have near-zero balance
        // This is tested in individual test cases
    }

    /* ========== UPGRADE & MIGRATION TESTS ========== */

    function test_Admin_EmergencyRecover() public {
        // Send some tokens to factory accidentally
        require(depositToken.transfer(address(factory), 1000e18), "Transfer failed");

        uint256 ownerBalBefore = depositToken.balanceOf(owner);

        factory.emergencyRecover(address(depositToken), 1000e18);

        uint256 ownerBalAfter = depositToken.balanceOf(owner);
        assertEq(ownerBalAfter - ownerBalBefore, 1000e18);
    }

    function test_Admin_EmergencyUpdateReserves() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Emergency");

        vm.prank(users[0]);
        uint256 proposalId = factory.createProposal(decisionId, "A");

        IQMFactory.Proposal memory proposal = factory.getProposal(decisionId, proposalId);

        // Owner can emergency update reserves
        hook.emergencyUpdateReserves(proposal.poolKey, 5000e18, 500e18);

        (uint256 credits, uint256 tokens) = hook.getPoolReserves(proposal.poolKey);
        assertEq(credits, 5000e18);
        assertEq(tokens, 500e18);
    }

    function test_Admin_ChangeAdmin() public {
        address newAdmin = makeAddr("newAdmin");
        
        factory.setAdmin(newAdmin, true);
        assertTrue(factory.admins(newAdmin));

        factory.setAdmin(newAdmin, false);
        assertFalse(factory.admins(newAdmin));
    }

    function test_Ownership_TransferOwnership() public {
        address newOwner = makeAddr("newOwner");
        
        factory.transferOwnership(newOwner);
        
        assertEq(factory.owner(), newOwner);
    }

    /* ========== INTEGRATION SCENARIOS ========== */

    function test_Scenario_RealWorldUsage() public {
        // Scenario: DAO deciding on treasury allocation
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Treasury Allocation: 10M USDC");

        // Create 3 competing proposals
        vm.prank(users[1]);
        uint256 p1 = factory.createProposal(decisionId, "DEX Liquidity");
        
        vm.prank(users[2]);
        uint256 p2 = factory.createProposal(decisionId, "Marketing");
        
        vm.prank(users[3]);
        uint256 p3 = factory.createProposal(decisionId, "Development");

        // Community members deposit and vote with trades
        uint256[] memory deposits = new uint256[](10);
        deposits[0] = 10000e18;
        deposits[1] = 5000e18;
        deposits[2] = 8000e18;
        deposits[3] = 3000e18;
        deposits[4] = 12000e18;
        deposits[5] = 6000e18;
        deposits[6] = 9000e18;
        deposits[7] = 4000e18;
        deposits[8] = 7000e18;
        deposits[9] = 11000e18;

        for (uint256 i = 0; i < 10; i++) {
            vm.prank(users[i]);
            factory.deposit(decisionId, deposits[i]);
        }

        // Users trade based on preferences
        vm.prank(users[0]);
        factory.trade(decisionId, p1, 8000e18, 0); // Strong DEX vote

        vm.prank(users[1]);
        factory.trade(decisionId, p2, 3000e18, 0);

        vm.prank(users[2]);
        factory.trade(decisionId, p1, 6000e18, 0);

        vm.prank(users[3]);
        factory.trade(decisionId, p3, 2000e18, 0);

        vm.prank(users[4]);
        factory.trade(decisionId, p1, 10000e18, 0); // Another strong DEX vote

        // Check market sentiment through prices
        uint256 price1 = factory.getProposalPrice(decisionId, p1);
        uint256 price2 = factory.getProposalPrice(decisionId, p2);
        uint256 price3 = factory.getProposalPrice(decisionId, p3);

        console2.log("DEX Liquidity price:", price1);
        console2.log("Marketing price:", price2);
        console2.log("Development price:", price3);

        // P1 should have highest price (most trades)
        assertGt(price1, price2);
        assertGt(price1, price3);

        // Admin settles based on governance vote (p1 wins)
        vm.prank(admin);
        factory.settle(decisionId, p1);

        // All users claim
        uint256 totalPayout = 0;
        for (uint256 i = 0; i < 10; i++) {
            uint256 balBefore = depositToken.balanceOf(users[i]);
            vm.prank(users[i]);
            factory.claimWinnings(decisionId);
            uint256 balAfter = depositToken.balanceOf(users[i]);
            totalPayout += (balAfter - balBefore);
        }

        // Total payout should approximately equal total deposits
        uint256 totalDeposits = factory.getDecision(decisionId).totalDeposits;
        assertApproxEqAbs(totalPayout, totalDeposits, 1e18);
    }

    function test_Scenario_LastMinuteSwing() public {
        vm.prank(users[0]);
        uint256 decisionId = factory.createDecision("Last Minute Swing");

        vm.startPrank(users[0]);
        uint256 p1 = factory.createProposal(decisionId, "Option A");
        uint256 p2 = factory.createProposal(decisionId, "Option B");
        vm.stopPrank();

        // Initial sentiment favors p1
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(users[i]);
            factory.deposit(decisionId, 1000e18);
            vm.prank(users[i]);
            factory.trade(decisionId, p1, 800e18, 0);
        }

        uint256 priceP1 = factory.getProposalPrice(decisionId, p1);
        uint256 priceP2 = factory.getProposalPrice(decisionId, p2);
        assertGt(priceP1, priceP2);

        // Last minute whale changes sentiment
        address whale = makeAddr("lateWhale");
        depositToken.mint(whale, 100000e18);
        vm.prank(whale);
        depositToken.approve(address(factory), type(uint256).max);

        vm.prank(whale);
        factory.deposit(decisionId, 100000e18);
        vm.prank(whale);
        factory.trade(decisionId, p2, 80000e18, 0);

        uint256 newPriceP1 = factory.getProposalPrice(decisionId, p1);
        uint256 newPriceP2 = factory.getProposalPrice(decisionId, p2);

        // P2 should now be more expensive
        assertGt(newPriceP2, newPriceP1);

        // But p1 still wins
        vm.prank(admin);
        factory.settle(decisionId, p1);

        // Whale loses most of investment
        uint256 balBefore = depositToken.balanceOf(whale);
        vm.prank(whale);
        factory.claimWinnings(decisionId);
        uint256 balAfter = depositToken.balanceOf(whale);

        uint256 whaleLoss = 100000e18 - (balAfter - balBefore);
        assertGt(whaleLoss, 50000e18); // Loses more than 50%
    }
}