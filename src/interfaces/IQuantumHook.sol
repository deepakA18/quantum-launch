// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "v4-core/types/PoolKey.sol";

/**
 * @title IQuantumHook
 * @notice Interface for the Quantum Hook contract
 * @dev Defines the interface for quantum market operations
 */
interface IQuantumHook {
    /// @notice Pool metadata structure
    struct PoolMetadata {
        uint256 decisionId;
        uint256 proposalId;
        address factory;
        uint256 totalSupply;
        uint256 currentPrice;
        bool isActive;
        bool isFrozen;
    }

    /**
     * @notice Register a new proposal pool
     * @param poolKey The pool key
     * @param decisionId The decision ID
     * @param proposalId The proposal ID
     * @param factory The factory address
     */
    function registerProposalPool(PoolKey calldata poolKey, uint256 decisionId, uint256 proposalId, address factory)
        external;

    /**
     * @notice Execute a quantum trade
     * @param poolKey The pool key
     * @param trader The trader address
     * @param creditsIn Amount of credits to trade
     * @param minTokensOut Minimum tokens expected out
     * @return tokensOut Amount of tokens received
     */
    function executeQuantumTrade(PoolKey calldata poolKey, address trader, uint256 creditsIn, uint256 minTokensOut)
        external
        returns (uint256 tokensOut);

    /**
     * @notice Freeze a proposal pool
     * @param poolKey The pool key
     * @param isWinner Whether the proposal won
     */
    function freezeProposalPool(PoolKey calldata poolKey, bool isWinner) external;

    /**
     * @notice Get current price of a pool
     * @param poolKey The pool key
     * @return price Current price
     */
    function getCurrentPrice(PoolKey calldata poolKey) external view returns (uint256 price);

    /**
     * @notice Get pool metadata
     * @param poolKey The pool key
     * @return metadata Pool metadata
     */
    function getPoolMetadata(PoolKey calldata poolKey) external view returns (PoolMetadata memory metadata);

    /**
     * @notice Check if pool is active
     * @param poolKey The pool key
     * @return isActive Whether the pool is active
     */
    function isPoolActive(PoolKey calldata poolKey) external view returns (bool isActive);

    /**
     * @notice Get pool factory
     * @param poolKey The pool key
     * @return factory The factory address
     */
    function getPoolFactory(PoolKey calldata poolKey) external view returns (address factory);

    /**
     * @notice Get pool reserves
     * @param poolKey The pool key
     * @return creditsReserve Credits reserve
     * @return tokensReserve Tokens reserve
     */
    function getPoolReserves(PoolKey calldata poolKey)
        external
        view
        returns (uint256 creditsReserve, uint256 tokensReserve);

    /**
     * @notice Calculate tokens out for a given credits in
     * @param poolKey The pool key
     * @param creditsIn Amount of credits to trade
     * @return tokensOut Amount of tokens to receive
     */
    function calculateTokensOut(PoolKey calldata poolKey, uint256 creditsIn)
        external
        view
        returns (uint256 tokensOut);
}
