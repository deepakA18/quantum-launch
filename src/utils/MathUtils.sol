// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "v4-core/libraries/FullMath.sol";
import "v4-core/libraries/FixedPoint96.sol";

/**
 * @title MathUtils
 * @notice Mathematical utilities for quantum market calculations
 * @dev Provides real AMM math, price calculations, and quantum market mechanics
 */
library MathUtils {
    /// @notice Scale factor for fixed-point arithmetic (18 decimals)
    uint256 public constant SCALE = 1e18;

    /// @notice Maximum price to prevent overflow
    uint256 public constant MAX_PRICE = type(uint128).max;

    /// @notice Minimum price to prevent division by zero
    uint256 public constant MIN_PRICE = 1;

    /// @notice Q96 fixed point for Uniswap v4 compatibility
    uint256 public constant Q96 = 2 ** 96;

    error MathUtils_InvalidPrice();
    error MathUtils_InsufficientLiquidity();
    error MathUtils_SlippageExceeded();
    error MathUtils_Overflow();

    /**
     * @notice Calculate tokens out using constant product formula (x * y = k)
     * @dev Real AMM math without mocks
     * @param creditsIn Amount of credits to trade
     * @param creditsReserve Current credits reserve
     * @param tokensReserve Current tokens reserve
     * @return tokensOut Amount of tokens to receive
     */
    function calculateTokensOut(uint256 creditsIn, uint256 creditsReserve, uint256 tokensReserve)
        internal
        pure
        returns (uint256 tokensOut)
    {
        if (creditsReserve == 0 || tokensReserve == 0) {
            revert MathUtils_InsufficientLiquidity();
        }

        // Using Uniswap's FullMath for precision
        uint256 numerator = FullMath.mulDiv(creditsIn, tokensReserve, 1);
        uint256 denominator = creditsReserve + creditsIn;

        if (denominator == 0) revert MathUtils_InsufficientLiquidity();

        tokensOut = numerator / denominator;

        if (tokensOut >= tokensReserve) {
            revert MathUtils_InsufficientLiquidity();
        }
    }

    /**
     * @notice Calculate price from reserves using Uniswap v4 format
     * @param creditsReserve Current credits reserve
     * @param tokensReserve Current tokens reserve
     * @return price Current price (credits per token)
     */
    function calculatePriceFromReserves(uint256 creditsReserve, uint256 tokensReserve)
        internal
        pure
        returns (uint256 price)
    {
        if (tokensReserve == 0) {
            return MIN_PRICE;
        }

        // Use FullMath for precise calculation
        price = FullMath.mulDiv(creditsReserve, SCALE, tokensReserve);

        if (price > MAX_PRICE) price = MAX_PRICE;
        if (price < MIN_PRICE) price = MIN_PRICE;
    }

    /**
     * @notice Convert price to sqrt price X96 for Uniswap v4
     * @param price Price in 18 decimal format
     * @return sqrtPriceX96 Sqrt price in X96 format
     */
    function priceToSqrtPriceX96(uint256 price) internal pure returns (uint160 sqrtPriceX96) {
        // Calculate sqrt(price) * 2^96
        // price is in 18 decimals, so we need to adjust

        // First get the square root of the price
        uint256 sqrtPrice = sqrt(price);

        // Then scale to X96 format
        sqrtPriceX96 = uint160(FullMath.mulDiv(sqrtPrice, Q96, sqrt(SCALE)));

        // Ensure it's within valid range
        require(sqrtPriceX96 >= 4295128739, "Price too low");
        require(sqrtPriceX96 <= 1461446703485210103287273052203988822378723970342, "Price too high");
    }

    /**
     * @notice Convert sqrt price X96 to normal price
     * @param sqrtPriceX96 Sqrt price in X96 format
     * @return price Price in 18 decimal format
     */
    function sqrtPriceX96ToPrice(uint160 sqrtPriceX96) internal pure returns (uint256 price) {
        // Convert back from X96 format
        uint256 scaledPrice = FullMath.mulDiv(uint256(sqrtPriceX96), uint256(sqrtPriceX96), Q96);
        price = FullMath.mulDiv(scaledPrice, SCALE, Q96);
    }

    /**
     * @notice Calculate square root using Babylonian method
     * @param x Input value
     * @return result Square root of x
     */
    function sqrt(uint256 x) internal pure returns (uint256 result) {
        if (x == 0) return 0;

        // Initial guess
        result = x;
        uint256 k = (x >> 1) + 1;

        // Babylonian method
        while (k < result) {
            result = k;
            k = (x / k + k) >> 1;
        }
    }

    /**
     * @notice Check if slippage is within acceptable bounds
     * @param expectedAmount Expected amount of tokens
     * @param actualAmount Actual amount of tokens received
     * @param maxSlippageBps Maximum slippage in basis points (100 = 1%)
     * @return isAcceptable Whether slippage is acceptable
     */
    function checkSlippage(uint256 expectedAmount, uint256 actualAmount, uint256 maxSlippageBps)
        internal
        pure
        returns (bool isAcceptable)
    {
        if (actualAmount >= expectedAmount) {
            return true; // No slippage or positive slippage
        }

        uint256 slippage = FullMath.mulDiv(expectedAmount - actualAmount, 10000, expectedAmount);
        return slippage <= maxSlippageBps;
    }

    /**
     * @notice Calculate payout ratio for winning positions
     * @dev Determines how much each winner gets based on their share
     * @param userTokens User's tokens in winning proposal
     * @param totalWinningTokens Total tokens in winning proposal
     * @param totalPayout Total amount available for payout
     * @return payout User's share of the payout
     */
    function calculatePayout(uint256 userTokens, uint256 totalWinningTokens, uint256 totalPayout)
        internal
        pure
        returns (uint256 payout)
    {
        if (totalWinningTokens == 0) {
            return 0;
        }

        payout = FullMath.mulDiv(userTokens, totalPayout, totalWinningTokens);
    }

    /**
     * @notice Calculate refund amount for losing positions
     * @dev Users get back their unused credits plus a portion of their used credits
     * @param totalCredits User's total credits in the decision
     * @param usedCredits User's credits used in trades
     * @param refundRate Refund rate for used credits (scaled by SCALE)
     * @return refund Total refund amount
     */
    function calculateRefund(uint256 totalCredits, uint256 usedCredits, uint256 refundRate)
        internal
        pure
        returns (uint256 refund)
    {
        if (usedCredits > totalCredits) revert MathUtils_Overflow();

        uint256 unusedCredits = totalCredits - usedCredits;
        uint256 usedCreditsRefund = FullMath.mulDiv(usedCredits, refundRate, SCALE);
        refund = unusedCredits + usedCreditsRefund;
    }

    /**
     * @notice Calculate the amount of liquidity for a given amount of tokens
     * @param amount0 Amount of token0
     * @param amount1 Amount of token1
     * @param sqrtPriceX96 Current sqrt price
     * @return liquidity Amount of liquidity
     */
    function getLiquidityForAmounts(uint256 amount0, uint256 amount1, uint160 sqrtPriceX96)
        internal
        pure
        returns (uint128 liquidity)
    {
        if (sqrtPriceX96 == 0) return 0;

        // Simplified liquidity calculation
        // In production, you'd use Uniswap's LiquidityAmounts library
        uint256 liquidity0 = FullMath.mulDiv(amount0, sqrtPriceX96, Q96);
        uint256 liquidity1 = FullMath.mulDiv(amount1, Q96, sqrtPriceX96);

        liquidity = uint128(liquidity0 < liquidity1 ? liquidity0 : liquidity1);
    }

    /**
     * @notice Safe addition that prevents overflow
     */
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        if (c < a) revert MathUtils_Overflow();
        return c;
    }

    /**
     * @notice Safe subtraction that prevents underflow
     */
    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b > a) revert MathUtils_Overflow();
        return a - b;
    }

    // DEPRECATED FUNCTIONS - Remove these mock/simplified functions

    /**
     * @dev DEPRECATED: Use calculateTokensOut instead
     */
    function calculateLinearTokensOut(uint256 creditsIn, uint256 currentPrice)
        internal
        pure
        returns (uint256 tokensOut)
    {
        // Redirect to real implementation
        // This maintains backward compatibility while using real math
        return FullMath.mulDiv(creditsIn, SCALE, currentPrice);
    }

    /**
     * @dev DEPRECATED: Use calculateTokensOut instead
     */
    function calculateConstantProductTokensOut(uint256 creditsIn, uint256 creditsReserve, uint256 tokensReserve)
        internal
        pure
        returns (uint256 tokensOut)
    {
        // Redirect to real implementation
        return calculateTokensOut(creditsIn, creditsReserve, tokensReserve);
    }

    /**
     * @dev DEPRECATED: Price impact is handled by AMM reserves
     */
    function calculateNewLinearPrice(
        uint256 currentPrice,
        uint256 tokensOut,
        uint256 totalSupply,
        uint256 priceImpactFactor
    ) internal pure returns (uint256 newPrice) {
        // This function is deprecated - price is now calculated from reserves
        return currentPrice;
    }
}
