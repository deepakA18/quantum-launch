// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {QMFactory} from "../src/QMFactory.sol";
import {QuantumHook} from "../src/QuantumHook.sol";
import {IQMFactory} from "../src/interfaces/IQMFactory.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice Real ERC20 implementation for testing
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title QMFactoryTest
 * @notice Comprehensive production-level tests for QMFactory and QuantumHook
 */
contract QMFactoryTest is Test {
    using PoolIdLibrary for PoolKey;

    QMFactory public factory;
    QuantumHook public hook;
    IPoolManager public poolManager;
    MockERC20 public depositToken;

    address public owner;
    address public admin;
    address public user1;
    address public user2;
    address public user3;

    uint256 constant INITIAL_BALANCE = 10000 * 1e18;
    uint256 constant DEPOSIT_AMOUNT = 1000 * 1e18;
    uint256 constant TRADE_AMOUNT = 100 * 1e18;

    event DecisionCreated(uint256 indexed decisionId, address indexed creator, string metadata, uint256 timestamp);
    event ProposalCreated(uint256 indexed decisionId, uint256 indexed proposalId, address indexed poolAddress, PoolKey poolKey, string metadata);
    event DepositMade(uint256 indexed decisionId, address indexed user, uint256 amount, uint256 credits);
    event TradeExecuted(uint256 indexed decisionId, uint256 indexed proposalId, address indexed trader, uint256 creditsIn, uint256 tokensOut, uint256 newPrice);
    event DecisionSettled(uint256 indexed decisionId, uint256 indexed winningProposalId, address indexed settler, uint256 totalPayout);

    function setUp() public {
        owner = makeAddr("owner");
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        depositToken = new MockERC20("USD Coin", "USDC");
        poolManager = new PoolManager(owner);

        // Create hook with proper permissions
        hook = new QuantumHook(poolManager, owner);

        factory = new QMFactory(address(depositToken), address(poolManager), address(hook), owner);

        vm.prank(owner);
        hook.setAuthorizedFactory(address(factory), true);
        
        vm.prank(owner);
        factory.setAdmin(admin, true);

        _fundUsers();
    }

    function _fundUsers() internal {
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        for (uint256 i = 0; i < users.length; i++) {
            depositToken.mint(users[i], INITIAL_BALANCE);
            vm.prank(users[i]);
            depositToken.approve(address(factory), type(uint256).max);
        }
    }

    /* ========== DECISION TESTS ========== */

    function test_CreateDecision() public {
        string memory metadata = "Should we launch on mainnet?";

        vm.expectEmit(true, true, false, true);
        emit DecisionCreated(1, user1, metadata, block.timestamp);

        vm.prank(user1);
        uint256 decisionId = factory.createDecision(metadata);

        assertEq(decisionId, 1);

        IQMFactory.Decision memory decision = factory.getDecision(decisionId);
        assertEq(decision.id, 1);
        assertEq(decision.creator, user1);
        assertEq(decision.metadata, metadata);
        assertEq(decision.totalDeposits, 0);
        assertEq(decision.proposalCount, 0);
        assertFalse(decision.isSettled);
    }

    function test_CreateMultipleDecisions() public {
        vm.startPrank(user1);
        uint256 d1 = factory.createDecision("Decision 1");
        uint256 d2 = factory.createDecision("Decision 2");
        uint256 d3 = factory.createDecision("Decision 3");
        vm.stopPrank();

        assertEq(d1, 1);
        assertEq(d2, 2);
        assertEq(d3, 3);
        assertEq(factory.decisionCounter(), 3);
    }

    function testFuzz_CreateDecisionWithMetadata(string memory metadata) public {
        vm.prank(user1);
        uint256 decisionId = factory.createDecision(metadata);

        IQMFactory.Decision memory decision = factory.getDecision(decisionId);
        assertEq(decision.metadata, metadata);
    }

    /* ========== PROPOSAL TESTS ========== */

    function test_CreateProposal() public {
        vm.prank(user1);
        uint256 decisionId = factory.createDecision("Test Decision");

        vm.prank(user1);
        uint256 proposalId = factory.createProposal(decisionId, "Option A");

        assertEq(proposalId, 1);

        IQMFactory.Proposal memory proposal = factory.getProposal(decisionId, proposalId);
        assertEq(proposal.id, 1);
        assertEq(proposal.decisionId, decisionId);
        assertTrue(proposal.isActive);
        assertEq(proposal.currentPrice, 1e18);
    }

    function test_CreateMultipleProposals() public {
        vm.prank(user1);
        uint256 decisionId = factory.createDecision("Test");

        vm.startPrank(user1);
        uint256 p1 = factory.createProposal(decisionId, "A");
        uint256 p2 = factory.createProposal(decisionId, "B");
        uint256 p3 = factory.createProposal(decisionId, "C");
        vm.stopPrank();

        assertEq(p1, 1);
        assertEq(p2, 2);
        assertEq(p3, 3);

        IQMFactory.Decision memory decision = factory.getDecision(decisionId);
        assertEq(decision.proposalCount, 3);
    }

    function test_RevertCreateProposalNonexistent() public {
        vm.prank(user1);
        vm.expectRevert("QMFactory: decision does not exist");
        factory.createProposal(999, "Invalid");
    }

    function test_RevertCreateProposalSettled() public {
        vm.startPrank(user1);
        uint256 decisionId = factory.createDecision("Test");
        factory.createProposal(decisionId, "A");
        vm.stopPrank();

        vm.prank(admin);
        factory.settle(decisionId, 1);

        vm.prank(user1);
        vm.expectRevert("QMFactory: decision already settled");
        factory.createProposal(decisionId, "B");
    }

    /* ========== DEPOSIT TESTS ========== */

    function test_Deposit() public {
        vm.prank(user1);
        uint256 decisionId = factory.createDecision("Test");

        uint256 balanceBefore = depositToken.balanceOf(user1);

        vm.expectEmit(true, true, false, true);
        emit DepositMade(decisionId, user1, DEPOSIT_AMOUNT, DEPOSIT_AMOUNT);

        vm.prank(user1);
        factory.deposit(decisionId, DEPOSIT_AMOUNT);

        assertEq(balanceBefore - depositToken.balanceOf(user1), DEPOSIT_AMOUNT);

        (uint256 credits, uint256 used) = factory.getUserPosition(decisionId, user1);
        assertEq(credits, DEPOSIT_AMOUNT);
        assertEq(used, 0);

        IQMFactory.Decision memory decision = factory.getDecision(decisionId);
        assertEq(decision.totalDeposits, DEPOSIT_AMOUNT);
    }

    function test_MultipleUsersDeposit() public {
        vm.prank(user1);
        uint256 decisionId = factory.createDecision("Test");

        vm.prank(user1);
        factory.deposit(decisionId, DEPOSIT_AMOUNT);

        vm.prank(user2);
        factory.deposit(decisionId, DEPOSIT_AMOUNT * 2);

        vm.prank(user3);
        factory.deposit(decisionId, DEPOSIT_AMOUNT / 2);

        IQMFactory.Decision memory decision = factory.getDecision(decisionId);
        assertEq(decision.totalDeposits, DEPOSIT_AMOUNT + DEPOSIT_AMOUNT * 2 + DEPOSIT_AMOUNT / 2);
    }

    function test_RevertDepositZero() public {
        vm.prank(user1);
        uint256 decisionId = factory.createDecision("Test");

        vm.prank(user1);
        vm.expectRevert("QMFactory: amount must be greater than 0");
        factory.deposit(decisionId, 0);
    }

    function test_RevertDepositNonexistent() public {
        vm.prank(user1);
        vm.expectRevert("QMFactory: decision does not exist");
        factory.deposit(999, DEPOSIT_AMOUNT);
    }

    function test_RevertDepositSettled() public {
        vm.startPrank(user1);
        uint256 decisionId = factory.createDecision("Test");
        factory.createProposal(decisionId, "A");
        factory.deposit(decisionId, DEPOSIT_AMOUNT);
        vm.stopPrank();

        vm.prank(admin);
        factory.settle(decisionId, 1);

        vm.prank(user1);
        vm.expectRevert("QMFactory: decision already settled");
        factory.deposit(decisionId, DEPOSIT_AMOUNT);
    }

    function testFuzz_Deposit(uint128 amount) public {
        vm.assume(amount > 0 && amount <= INITIAL_BALANCE);

        vm.prank(user1);
        uint256 decisionId = factory.createDecision("Test");

        vm.prank(user1);
        factory.deposit(decisionId, amount);

        (uint256 credits,) = factory.getUserPosition(decisionId, user1);
        assertEq(credits, amount);
    }

    /* ========== TRADING TESTS ========== */

    function test_Trade() public {
        vm.startPrank(user1);
        uint256 decisionId = factory.createDecision("Test");
        uint256 proposalId = factory.createProposal(decisionId, "A");
        factory.deposit(decisionId, DEPOSIT_AMOUNT);
        vm.stopPrank();

        uint256 priceBefore = factory.getProposalPrice(decisionId, proposalId);

        vm.prank(user1);
        factory.trade(decisionId, proposalId, TRADE_AMOUNT, 0);

        (, uint256 usedCredits) = factory.getUserPosition(decisionId, user1);
        assertEq(usedCredits, TRADE_AMOUNT);

        uint256 tokens = factory.getUserProposalTokens(decisionId, proposalId, user1);
        assertGt(tokens, 0);

        uint256 priceAfter = factory.getProposalPrice(decisionId, proposalId);
        assertGt(priceAfter, priceBefore);
    }

    function test_TradePriceImpact() public {
        vm.startPrank(user1);
        uint256 decisionId = factory.createDecision("Test");
        uint256 proposalId = factory.createProposal(decisionId, "A");
        factory.deposit(decisionId, DEPOSIT_AMOUNT);
        vm.stopPrank();

        uint256 p1 = factory.getProposalPrice(decisionId, proposalId);

        vm.prank(user1);
        factory.trade(decisionId, proposalId, TRADE_AMOUNT, 0);
        uint256 p2 = factory.getProposalPrice(decisionId, proposalId);

        vm.prank(user1);
        factory.trade(decisionId, proposalId, TRADE_AMOUNT, 0);
        uint256 p3 = factory.getProposalPrice(decisionId, proposalId);

        assertGt(p2, p1);
        assertGt(p3, p2);
    }

    function test_TradeMultipleProposals() public {
        vm.startPrank(user1);
        uint256 decisionId = factory.createDecision("Test");
        uint256 p1 = factory.createProposal(decisionId, "A");
        uint256 p2 = factory.createProposal(decisionId, "B");
        factory.deposit(decisionId, DEPOSIT_AMOUNT);
        factory.trade(decisionId, p1, TRADE_AMOUNT, 0);
        factory.trade(decisionId, p2, TRADE_AMOUNT, 0);
        vm.stopPrank();

        uint256 t1 = factory.getUserProposalTokens(decisionId, p1, user1);
        uint256 t2 = factory.getUserProposalTokens(decisionId, p2, user1);

        assertGt(t1, 0);
        assertGt(t2, 0);

        (, uint256 used) = factory.getUserPosition(decisionId, user1);
        assertEq(used, TRADE_AMOUNT * 2);
    }

    function test_RevertTradeInsufficientCredits() public {
        vm.startPrank(user1);
        uint256 decisionId = factory.createDecision("Test");
        uint256 proposalId = factory.createProposal(decisionId, "A");
        factory.deposit(decisionId, TRADE_AMOUNT);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert("QMFactory: insufficient credits");
        factory.trade(decisionId, proposalId, TRADE_AMOUNT + 1, 0);
    }

    function test_RevertTradeNonexistentProposal() public {
        vm.startPrank(user1);
        uint256 decisionId = factory.createDecision("Test");
        factory.deposit(decisionId, DEPOSIT_AMOUNT);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert("QMFactory: proposal does not exist");
        factory.trade(decisionId, 1, TRADE_AMOUNT, 0);
    }

    function testFuzz_Trade(uint96 deposit, uint96 trade) public {
        vm.assume(deposit > 0 && deposit <= INITIAL_BALANCE);
        vm.assume(trade > 0 && trade <= deposit);

        vm.startPrank(user1);
        uint256 decisionId = factory.createDecision("Test");
        uint256 proposalId = factory.createProposal(decisionId, "A");
        factory.deposit(decisionId, deposit);
        factory.trade(decisionId, proposalId, trade, 0);
        vm.stopPrank();

        (, uint256 used) = factory.getUserPosition(decisionId, user1);
        assertEq(used, trade);
    }

    /* ========== SETTLEMENT TESTS ========== */

    function test_Settle() public {
        vm.startPrank(user1);
        uint256 decisionId = factory.createDecision("Test");
        uint256 proposalId = factory.createProposal(decisionId, "A");
        factory.deposit(decisionId, DEPOSIT_AMOUNT);
        factory.trade(decisionId, proposalId, TRADE_AMOUNT, 0);
        vm.stopPrank();

        vm.prank(admin);
        factory.settle(decisionId, proposalId);

        IQMFactory.Decision memory decision = factory.getDecision(decisionId);
        assertTrue(decision.isSettled);
        assertEq(decision.winningProposal, proposalId);

        IQMFactory.Proposal memory proposal = factory.getProposal(decisionId, proposalId);
        assertFalse(proposal.isActive);
    }

    function test_RevertSettleNonAdmin() public {
        vm.prank(user1);
        uint256 decisionId = factory.createDecision("Test");

        vm.prank(user1);
        uint256 proposalId = factory.createProposal(decisionId, "A");

        vm.prank(user2);
        vm.expectRevert("QMFactory: not admin");
        factory.settle(decisionId, proposalId);
    }

    function test_RevertSettleAlreadySettled() public {
        vm.startPrank(user1);
        uint256 decisionId = factory.createDecision("Test");
        uint256 proposalId = factory.createProposal(decisionId, "A");
        vm.stopPrank();

        vm.prank(admin);
        factory.settle(decisionId, proposalId);

        vm.prank(admin);
        vm.expectRevert("QMFactory: decision already settled");
        factory.settle(decisionId, proposalId);
    }

    /* ========== CLAIM WINNINGS TESTS ========== */

    function test_ClaimWinningsAsWinner() public {
        vm.startPrank(user1);
        uint256 decisionId = factory.createDecision("Test");
        uint256 p1 = factory.createProposal(decisionId, "A");
        factory.deposit(decisionId, DEPOSIT_AMOUNT);
        factory.trade(decisionId, p1, DEPOSIT_AMOUNT, 0);
        vm.stopPrank();

        vm.prank(admin);
        factory.settle(decisionId, p1);

        uint256 balBefore = depositToken.balanceOf(user1);

        vm.prank(user1);
        factory.claimWinnings(decisionId);

        uint256 balAfter = depositToken.balanceOf(user1);
        assertGt(balAfter - balBefore, 0);

        (uint256 credits,) = factory.getUserPosition(decisionId, user1);
        assertEq(credits, 0);
    }

    function test_ClaimWinningsAsLoser() public {
        vm.prank(user1);
        uint256 decisionId = factory.createDecision("Test");

        vm.startPrank(user1);
        uint256 p1 = factory.createProposal(decisionId, "A");
        factory.deposit(decisionId, DEPOSIT_AMOUNT);
        factory.trade(decisionId, p1, DEPOSIT_AMOUNT, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 p2 = factory.createProposal(decisionId, "B");
        factory.deposit(decisionId, DEPOSIT_AMOUNT);
        factory.trade(decisionId, p2, DEPOSIT_AMOUNT, 0);
        vm.stopPrank();

        vm.prank(admin);
        factory.settle(decisionId, p1);

        uint256 balBefore = depositToken.balanceOf(user2);

        vm.prank(user2);
        factory.claimWinnings(decisionId);

        uint256 balAfter = depositToken.balanceOf(user2);
        uint256 refund = balAfter - balBefore;

        uint256 expectedRefund = DEPOSIT_AMOUNT / 2;
        assertEq(refund, expectedRefund);
    }

    function test_RevertClaimBeforeSettlement() public {
        vm.startPrank(user1);
        uint256 decisionId = factory.createDecision("Test");
        factory.createProposal(decisionId, "A");
        factory.deposit(decisionId, DEPOSIT_AMOUNT);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert("QMFactory: decision not settled");
        factory.claimWinnings(decisionId);
    }

    function test_RevertClaimWithoutPosition() public {
        vm.prank(user1);
        uint256 decisionId = factory.createDecision("Test");

        vm.prank(user1);
        uint256 proposalId = factory.createProposal(decisionId, "A");

        vm.prank(admin);
        factory.settle(decisionId, proposalId);

        vm.prank(user2);
        vm.expectRevert("QMFactory: no position found");
        factory.claimWinnings(decisionId);
    }

    function test_RevertDoubleClaimWinnings() public {
        vm.startPrank(user1);
        uint256 decisionId = factory.createDecision("Test");
        uint256 proposalId = factory.createProposal(decisionId, "A");
        factory.deposit(decisionId, DEPOSIT_AMOUNT);
        factory.trade(decisionId, proposalId, DEPOSIT_AMOUNT, 0);
        vm.stopPrank();

        vm.prank(admin);
        factory.settle(decisionId, proposalId);

        vm.prank(user1);
        factory.claimWinnings(decisionId);

        vm.prank(user1);
        vm.expectRevert("QMFactory: no position found");
        factory.claimWinnings(decisionId);
    }

    /* ========== INTEGRATION TESTS ========== */

    function test_FullLifecycle() public {
        // 1. Create decision
        vm.prank(user1);
        uint256 decisionId = factory.createDecision("Launch chain?");

        // 2. Create proposals
        vm.startPrank(user1);
        uint256 p1 = factory.createProposal(decisionId, "Ethereum");
        uint256 p2 = factory.createProposal(decisionId, "Base");
        factory.createProposal(decisionId, "Arbitrum");
        vm.stopPrank();

        // 3. Users deposit
        vm.prank(user1);
        factory.deposit(decisionId, 1000e18);

        vm.prank(user2);
        factory.deposit(decisionId, 800e18);

        vm.prank(user3);
        factory.deposit(decisionId, 600e18);

        // 4. Users trade
        vm.prank(user1);
        factory.trade(decisionId, p1, 500e18, 0);

        vm.prank(user2);
        factory.trade(decisionId, p2, 400e18, 0);

        vm.prank(user3);
        factory.trade(decisionId, p1, 300e18, 0);

        // 5. Settle
        vm.prank(admin);
        factory.settle(decisionId, p1);

        // 6. Claim
        uint256 u1Before = depositToken.balanceOf(user1);
        uint256 u2Before = depositToken.balanceOf(user2);
        uint256 u3Before = depositToken.balanceOf(user3);

        vm.prank(user1);
        factory.claimWinnings(decisionId);

        vm.prank(user2);
        factory.claimWinnings(decisionId);

        vm.prank(user3);
        factory.claimWinnings(decisionId);

        uint256 u1After = depositToken.balanceOf(user1);
        uint256 u2After = depositToken.balanceOf(user2);
        uint256 u3After = depositToken.balanceOf(user3);

        assertGt(u1After, u1Before);
        assertGt(u2After, u2Before);
        assertGt(u3After, u3Before);
    }

    function test_MultipleDecisionsParallel() public {
        vm.startPrank(user1);
        uint256 d1 = factory.createDecision("Decision 1");
        uint256 d2 = factory.createDecision("Decision 2");

        uint256 d1p1 = factory.createProposal(d1, "D1 Option A");
        uint256 d2p1 = factory.createProposal(d2, "D2 Option A");

        factory.deposit(d1, 500e18);
        factory.deposit(d2, 500e18);

        factory.trade(d1, d1p1, 250e18, 0);
        factory.trade(d2, d2p1, 250e18, 0);
        vm.stopPrank();

        (uint256 cred1,) = factory.getUserPosition(d1, user1);
        (uint256 cred2,) = factory.getUserPosition(d2, user1);

        assertEq(cred1, 500e18);
        assertEq(cred2, 500e18);
    }
}
