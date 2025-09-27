// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

import {IQMFactory} from "./interfaces/IQMFactory.sol";
import {IQuantumHook} from "./interfaces/IQuantumHook.sol";
import {MathUtils} from "./utils/MathUtils.sol";

/**
 * @title QMFactory
 * @notice Quantum Markets Factory - manages decisions, proposals, and settlements
 * @dev Core contract that orchestrates the quantum market launchpad with real Uniswap v4 integration
 */
contract QMFactory is IQMFactory, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using MathUtils for uint256;

    /// @notice The deposit token (e.g., USDC, WETH)
    IERC20 public immutable DEPOSIT_TOKEN;

    /// @notice Uniswap v4 Pool Manager
    IPoolManager public immutable POOL_MANAGER;

    /// @notice Quantum Hook contract
    IQuantumHook public immutable QUANTUM_HOOK;

    /// @notice Counter for decision IDs
    uint256 public decisionCounter;

    /// @notice Initial price for new proposals (1 credit per token)
    uint256 public constant INITIAL_PRICE = 1e18;

    /// @notice Refund rate for losing positions (50% of used credits)
    uint256 public constant REFUND_RATE = 5e17; // 0.5 * 1e18

    /// @notice Fee tier for Uniswap v4 pools (0.3%)
    uint24 public constant POOL_FEE = 3000;

    /// @notice Tick spacing for pools
    int24 public constant TICK_SPACING = 60;

    /// @notice Mapping of decision ID to Decision struct
    mapping(uint256 => Decision) public decisions;

    /// @notice Mapping of decision ID to proposal ID to Proposal struct
    mapping(uint256 => mapping(uint256 => Proposal)) public proposals;

    /// @notice Mapping of decision ID to user address to UserPosition
    mapping(uint256 => mapping(address => UserPosition)) public userPositions;

    /// @notice Mapping to track admin addresses
    mapping(address => bool) public admins;

    /// @notice Mapping from decision+proposal to pool ID for easy lookup
    mapping(uint256 => mapping(uint256 => PoolId)) public proposalPools;

    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() internal {
        require(admins[msg.sender] || msg.sender == owner(), "QMFactory: not admin");
    }

    modifier decisionExists(uint256 decisionId) {
        _decisionExists(decisionId);
        _;
    }

    function _decisionExists(uint256 decisionId) internal {
        require(decisionId > 0 && decisionId <= decisionCounter, "QMFactory: decision does not exist");
    }

    modifier decisionNotSettled(uint256 decisionId) {
        _decisionNotSettled(decisionId);
        _;
    }

    function _decisionNotSettled(uint256 decisionId) internal {
        require(!decisions[decisionId].isSettled, "QMFactory: decision already settled");
    }

    modifier proposalExists(uint256 decisionId, uint256 proposalId) {
        _proposalExists(decisionId, proposalId);
        _;
    }

    function _proposalExists(uint256 decisionId, uint256 proposalId) internal {
        require(
            proposalId > 0 && proposalId <= decisions[decisionId].proposalCount, "QMFactory: proposal does not exist"
        );
    }

    constructor(address _depositToken, address _poolManager, address _quantumHook, address _initialOwner)
        Ownable(_initialOwner)
    {
        DEPOSIT_TOKEN = IERC20(_depositToken);
        POOL_MANAGER = IPoolManager(_poolManager);
        QUANTUM_HOOK = IQuantumHook(_quantumHook);

        // Set initial owner as admin
        admins[_initialOwner] = true;
    }

    /**
     * @notice Add or remove admin addresses
     * @param admin Address to modify
     * @param isAdmin Whether to add or remove admin status
     */
    function setAdmin(address admin, bool isAdmin) external onlyOwner {
        admins[admin] = isAdmin;
    }

    /**
     * @inheritdoc IQMFactory
     */
    function createDecision(string calldata metadata) external override returns (uint256 decisionId) {
        decisionId = ++decisionCounter;

        decisions[decisionId] = Decision({
            id: decisionId,
            creator: msg.sender,
            metadata: metadata,
            totalDeposits: 0,
            totalCredits: 0,
            proposalCount: 0,
            isSettled: false,
            winningProposal: 0,
            createdAt: block.timestamp
        });

        emit DecisionCreated(decisionId, msg.sender, metadata, block.timestamp);
    }

    /**
     * @inheritdoc IQMFactory
     */
    function createProposal(uint256 decisionId, string calldata metadata)
        external
        override
        decisionExists(decisionId)
        decisionNotSettled(decisionId)
        returns (uint256 proposalId)
    {
        Decision storage decision = decisions[decisionId];
        proposalId = ++decision.proposalCount;

        // Create PoolKey for this proposal
        // Currency0 is always the smaller address for proper ordering
        Currency currency0 = Currency.wrap(address(DEPOSIT_TOKEN));
        Currency currency1 = Currency.wrap(address(uint160(uint256(keccak256(abi.encode(decisionId, proposalId))))));

        // Ensure proper ordering (currency0 < currency1)
        if (Currency.unwrap(currency0) > Currency.unwrap(currency1)) {
            (currency0, currency1) = (currency1, currency0);
        }

        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(QUANTUM_HOOK))
        });

        // Get pool ID
        PoolId poolId = poolKey.toId();
        proposalPools[decisionId][proposalId] = poolId;

        // Register the pool with our hook first
        QUANTUM_HOOK.registerProposalPool(poolKey, decisionId, proposalId, address(this));

        // Initialize the pool in Uniswap v4 with proper sqrt price
        uint160 sqrtPriceX96 = MathUtils.priceToSqrtPriceX96(INITIAL_PRICE);
        POOL_MANAGER.initialize(poolKey, sqrtPriceX96);

        proposals[decisionId][proposalId] = Proposal({
            id: proposalId,
            decisionId: decisionId,
            poolAddress: address(POOL_MANAGER),
            poolKey: poolKey,
            metadata: metadata,
            totalTrades: 0,
            currentPrice: INITIAL_PRICE,
            isActive: true
        });

        emit ProposalCreated(decisionId, proposalId, address(POOL_MANAGER), poolKey, metadata);
    }

    /**
     * @inheritdoc IQMFactory
     */
    function deposit(uint256 decisionId, uint256 amount)
        external
        override
        nonReentrant
        decisionExists(decisionId)
        decisionNotSettled(decisionId)
    {
        require(amount > 0, "QMFactory: amount must be greater than 0");

        // Transfer deposit token from user
        DEPOSIT_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        // Issue 1:1 credits for deposits
        uint256 credits = amount;

        // Update decision totals
        Decision storage decision = decisions[decisionId];
        decision.totalDeposits += amount;
        decision.totalCredits += credits;

        // Update user position
        UserPosition storage position = userPositions[decisionId][msg.sender];
        position.totalCredits += credits;

        emit DepositMade(decisionId, msg.sender, amount, credits);
    }

    /**
     * @inheritdoc IQMFactory
     */
    function trade(uint256 decisionId, uint256 proposalId, uint256 creditsIn, uint256 minTokensOut)
        external
        override
        nonReentrant
        decisionExists(decisionId)
        proposalExists(decisionId, proposalId)
        decisionNotSettled(decisionId)
    {
        require(creditsIn > 0, "QMFactory: credits must be greater than 0");

        UserPosition storage position = userPositions[decisionId][msg.sender];
        require(position.totalCredits >= position.usedCredits + creditsIn, "QMFactory: insufficient credits");

        Proposal storage proposal = proposals[decisionId][proposalId];
        require(proposal.isActive, "QMFactory: proposal not active");

        // Execute trade through the hook
        uint256 tokensOut = QUANTUM_HOOK.executeQuantumTrade(proposal.poolKey, msg.sender, creditsIn, minTokensOut);

        // Update proposal state
        proposal.totalTrades++;
        proposal.currentPrice = QUANTUM_HOOK.getCurrentPrice(proposal.poolKey);

        // Update user position
        position.usedCredits += creditsIn;
        position.proposalTokens[proposalId] += tokensOut;

        emit TradeExecuted(decisionId, proposalId, msg.sender, creditsIn, tokensOut, proposal.currentPrice);
    }

    /**
     * @inheritdoc IQMFactory
     */
    function settle(uint256 decisionId, uint256 winningProposalId)
        external
        override
        onlyAdmin
        decisionExists(decisionId)
        proposalExists(decisionId, winningProposalId)
        decisionNotSettled(decisionId)
    {
        Decision storage decision = decisions[decisionId];
        decision.isSettled = true;
        decision.winningProposal = winningProposalId;

        // Freeze all proposal pools
        for (uint256 i = 1; i <= decision.proposalCount; i++) {
            Proposal storage proposal = proposals[decisionId][i];
            proposal.isActive = false;

            bool isWinner = (i == winningProposalId);
            QUANTUM_HOOK.freezeProposalPool(proposal.poolKey, isWinner);
        }

        emit DecisionSettled(decisionId, winningProposalId, msg.sender, decision.totalDeposits);
    }

    /**
     * @inheritdoc IQMFactory
     */
    function claimWinnings(uint256 decisionId) external override nonReentrant decisionExists(decisionId) {
        Decision storage decision = decisions[decisionId];
        require(decision.isSettled, "QMFactory: decision not settled");

        UserPosition storage position = userPositions[decisionId][msg.sender];
        require(position.totalCredits > 0, "QMFactory: no position found");

        uint256 totalPayout = 0;
        uint256 winningTokens = position.proposalTokens[decision.winningProposal];

        if (winningTokens > 0) {
            // Calculate winner payout
            uint256 totalWinningTokens = getCurrentProposalSupply(decisionId, decision.winningProposal);
            uint256 winnerPayout = MathUtils.calculatePayout(winningTokens, totalWinningTokens, decision.totalDeposits);
            totalPayout += winnerPayout;
        }

        // Calculate refund for unused/losing credits
        uint256 refund = MathUtils.calculateRefund(position.totalCredits, position.usedCredits, REFUND_RATE);
        totalPayout += refund;

        // Reset user position to prevent double claiming
        position.totalCredits = 0;
        position.usedCredits = 0;
        for (uint256 i = 1; i <= decision.proposalCount; i++) {
            position.proposalTokens[i] = 0;
        }

        // Transfer payout
        if (totalPayout > 0) {
            DEPOSIT_TOKEN.safeTransfer(msg.sender, totalPayout);
        }
    }

    /**
     * @inheritdoc IQMFactory
     */
    function getDecision(uint256 decisionId) external view override returns (Decision memory decision) {
        return decisions[decisionId];
    }

    /**
     * @inheritdoc IQMFactory
     */
    function getProposal(uint256 decisionId, uint256 proposalId)
        external
        view
        override
        returns (Proposal memory proposal)
    {
        return proposals[decisionId][proposalId];
    }

    /**
     * @inheritdoc IQMFactory
     */
    function getUserPosition(uint256 decisionId, address user)
        external
        view
        override
        returns (uint256 totalCredits, uint256 usedCredits)
    {
        UserPosition storage position = userPositions[decisionId][user];
        return (position.totalCredits, position.usedCredits);
    }

    /**
     * @inheritdoc IQMFactory
     */
    function getUserProposalTokens(uint256 decisionId, uint256 proposalId, address user)
        external
        view
        override
        returns (uint256 tokens)
    {
        return userPositions[decisionId][user].proposalTokens[proposalId];
    }

    /**
     * @inheritdoc IQMFactory
     */
    function getProposalPrice(uint256 decisionId, uint256 proposalId) external view override returns (uint256 price) {
        return proposals[decisionId][proposalId].currentPrice;
    }

    /**
     * @inheritdoc IQMFactory
     */
    function isDecisionSettled(uint256 decisionId) external view override returns (bool isSettled) {
        return decisions[decisionId].isSettled;
    }

    /**
     * @notice Get current supply of tokens for a proposal
     * @dev Queries the hook for actual token supply
     * @param decisionId The decision ID
     * @param proposalId The proposal ID
     * @return supply Current token supply
     */
    function getCurrentProposalSupply(uint256 decisionId, uint256 proposalId) public view returns (uint256 supply) {
        Proposal storage proposal = proposals[decisionId][proposalId];
        IQuantumHook.PoolMetadata memory metadata = QUANTUM_HOOK.getPoolMetadata(proposal.poolKey);
        return metadata.totalSupply;
    }

    /**
     * @notice Get pool ID for a proposal
     * @param decisionId The decision ID
     * @param proposalId The proposal ID
     * @return poolId The Uniswap v4 pool ID
     */
    function getProposalPoolId(uint256 decisionId, uint256 proposalId) external view returns (PoolId poolId) {
        return proposalPools[decisionId][proposalId];
    }

    /**
     * @notice Emergency function to recover stuck tokens
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function emergencyRecover(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }

    /**
     * @notice Get detailed trading information for a proposal
     * @param decisionId The decision ID
     * @param proposalId The proposal ID
     * @return totalSupply Total tokens minted
     * @return currentPrice Current token price
     * @return isActive Whether pool is active
     * @return creditsReserve Current credits in pool
     * @return tokensReserve Current tokens in pool
     */
    function getProposalDetails(uint256 decisionId, uint256 proposalId)
        external
        view
        returns (
            uint256 totalSupply,
            uint256 currentPrice,
            bool isActive,
            uint256 creditsReserve,
            uint256 tokensReserve
        )
    {
        Proposal storage proposal = proposals[decisionId][proposalId];
        IQuantumHook.PoolMetadata memory metadata = QUANTUM_HOOK.getPoolMetadata(proposal.poolKey);

        (creditsReserve, tokensReserve) = QUANTUM_HOOK.getPoolReserves(proposal.poolKey);

        return (
            metadata.totalSupply,
            metadata.currentPrice,
            metadata.isActive && !metadata.isFrozen,
            creditsReserve,
            tokensReserve
        );
    }

    /**
     * @notice Calculate expected tokens out for a trade
     * @param decisionId The decision ID
     * @param proposalId The proposal ID
     * @param creditsIn Amount of credits to trade
     * @return tokensOut Expected tokens to receive
     */
    function calculateTokensOut(uint256 decisionId, uint256 proposalId, uint256 creditsIn)
        external
        view
        returns (uint256 tokensOut)
    {
        Proposal storage proposal = proposals[decisionId][proposalId];
        return QUANTUM_HOOK.calculateTokensOut(proposal.poolKey, creditsIn);
    }
}
