// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "v4-core/types/PoolKey.sol";

/**
 * @title IQMFactory
 * @notice Interface for the Quantum Markets Factory contract
 * @dev Manages decisions, proposals, and the quantum market lifecycle
 */
interface IQMFactory {
    /// @notice Emitted when a new decision is created
    event DecisionCreated(uint256 indexed decisionId, address indexed creator, string metadata, uint256 timestamp);

    /// @notice Emitted when a new proposal is added to a decision
    event ProposalCreated(
        uint256 indexed decisionId,
        uint256 indexed proposalId,
        address indexed poolAddress,
        PoolKey poolKey,
        string metadata
    );

    /// @notice Emitted when a user deposits into a decision
    event DepositMade(uint256 indexed decisionId, address indexed user, uint256 amount, uint256 credits);

    /// @notice Emitted when a trade is executed
    event TradeExecuted(
        uint256 indexed decisionId,
        uint256 indexed proposalId,
        address indexed trader,
        uint256 creditsIn,
        uint256 tokensOut,
        uint256 newPrice
    );

    /// @notice Emitted when a decision is settled
    event DecisionSettled(
        uint256 indexed decisionId, uint256 indexed winningProposalId, address indexed settler, uint256 totalPayout
    );

    /// @notice Structure representing a decision
    struct Decision {
        uint256 id;
        address creator;
        string metadata;
        uint256 totalDeposits;
        uint256 totalCredits;
        uint256 proposalCount;
        bool isSettled;
        uint256 winningProposal;
        uint256 createdAt;
    }

    /// @notice Structure representing a proposal within a decision
    struct Proposal {
        uint256 id;
        uint256 decisionId;
        address poolAddress;
        PoolKey poolKey;
        string metadata;
        uint256 totalTrades;
        uint256 currentPrice;
        bool isActive;
    }

    /// @notice Structure tracking user positions
    struct UserPosition {
        uint256 totalCredits;
        uint256 usedCredits;
        mapping(uint256 => uint256) proposalTokens; // proposalId => token amount
    }

    /// @notice Create a new decision
    /// @param metadata IPFS hash or JSON metadata for the decision
    /// @return decisionId The ID of the newly created decision
    function createDecision(string calldata metadata) external returns (uint256 decisionId);

    /// @notice Create a new proposal within a decision
    /// @param decisionId The decision to add the proposal to
    /// @param metadata IPFS hash or JSON metadata for the proposal
    /// @return proposalId The ID of the newly created proposal
    function createProposal(uint256 decisionId, string calldata metadata) external returns (uint256 proposalId);

    /// @notice Deposit funds and receive credits for a decision
    /// @param decisionId The decision to deposit into
    /// @param amount The amount to deposit
    function deposit(uint256 decisionId, uint256 amount) external;

    /// @notice Execute a trade within a proposal
    /// @param decisionId The decision containing the proposal
    /// @param proposalId The proposal to trade in
    /// @param creditsIn Amount of credits to trade
    /// @param minTokensOut Minimum tokens expected (slippage protection)
    function trade(uint256 decisionId, uint256 proposalId, uint256 creditsIn, uint256 minTokensOut) external;

    /// @notice Settle a decision by selecting the winning proposal
    /// @param decisionId The decision to settle
    /// @param winningProposalId The proposal that wins
    function settle(uint256 decisionId, uint256 winningProposalId) external;

    /// @notice Claim winnings after settlement
    /// @param decisionId The settled decision
    function claimWinnings(uint256 decisionId) external;

    /// @notice Get decision details
    /// @param decisionId The decision ID
    /// @return decision The decision struct
    function getDecision(uint256 decisionId) external view returns (Decision memory decision);

    /// @notice Get proposal details
    /// @param decisionId The decision ID
    /// @param proposalId The proposal ID
    /// @return proposal The proposal struct
    function getProposal(uint256 decisionId, uint256 proposalId) external view returns (Proposal memory proposal);

    /// @notice Get user's position in a decision
    /// @param decisionId The decision ID
    /// @param user The user address
    /// @return totalCredits Total credits available
    /// @return usedCredits Credits already used in trades
    function getUserPosition(uint256 decisionId, address user)
        external
        view
        returns (uint256 totalCredits, uint256 usedCredits);

    /// @notice Get user's token balance for a specific proposal
    /// @param decisionId The decision ID
    /// @param proposalId The proposal ID
    /// @param user The user address
    /// @return tokens Number of proposal tokens held
    function getUserProposalTokens(uint256 decisionId, uint256 proposalId, address user)
        external
        view
        returns (uint256 tokens);

    /// @notice Get the current price for a proposal
    /// @param decisionId The decision ID
    /// @param proposalId The proposal ID
    /// @return price Current price of the proposal token
    function getProposalPrice(uint256 decisionId, uint256 proposalId) external view returns (uint256 price);

    /// @notice Check if a decision is settled
    /// @param decisionId The decision ID
    /// @return isSettled Whether the decision has been settled
    function isDecisionSettled(uint256 decisionId) external view returns (bool isSettled);
}
