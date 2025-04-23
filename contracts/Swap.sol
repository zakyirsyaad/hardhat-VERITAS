// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract Swap {
    IERC20 public immutable tokenDAO;
    IERC20 public immutable idrx;

    uint256 public daoPool;
    uint256 public idrxPool;

    // Minimum liquidity of 1000 tokens (adjusted for decimals)
    // For 2 decimals: 1000 * 10^2 = 100,000 (1000.00 tokens)
    uint256 public constant MINIMUM_LIQUIDITY = 1000 * 10 ** 2;

    event LiquidityAdded(
        address indexed provider,
        uint256 daoAmount,
        uint256 idrxAmount
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 daoAmount,
        uint256 idrxAmount
    );
    event Swapped(
        address indexed user,
        address fromToken,
        address toToken,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor(address _tokenDAO, address _idrx) {
        require(
            _tokenDAO != address(0) && _idrx != address(0),
            "Invalid token address"
        );
        tokenDAO = IERC20(_tokenDAO);
        idrx = IERC20(_idrx);

        // Verify both tokens have same decimals
        require(
            IERC20Metadata(_tokenDAO).decimals() ==
                IERC20Metadata(_idrx).decimals(),
            "Tokens must have same decimals"
        );
    }

    function addLiquidity(uint256 daoAmount, uint256 idrxAmount) external {
        require(daoAmount > 0 && idrxAmount > 0, "Amounts required");
        require(
            daoAmount >= MINIMUM_LIQUIDITY && idrxAmount >= MINIMUM_LIQUIDITY,
            "Insufficient liquidity amount"
        );

        tokenDAO.transferFrom(msg.sender, address(this), daoAmount);
        idrx.transferFrom(msg.sender, address(this), idrxAmount);

        daoPool += daoAmount;
        idrxPool += idrxAmount;

        emit LiquidityAdded(msg.sender, daoAmount, idrxAmount);
    }

    function removeLiquidity(uint256 daoAmount, uint256 idrxAmount) external {
        require(daoPool >= daoAmount, "Insufficient DAO liquidity");
        require(idrxPool >= idrxAmount, "Insufficient IDRX liquidity");
        require(
            daoPool - daoAmount >= MINIMUM_LIQUIDITY &&
                idrxPool - idrxAmount >= MINIMUM_LIQUIDITY,
            "Cannot remove all liquidity"
        );

        daoPool -= daoAmount;
        idrxPool -= idrxAmount;

        tokenDAO.transfer(msg.sender, daoAmount);
        idrx.transfer(msg.sender, idrxAmount);

        emit LiquidityRemoved(msg.sender, daoAmount, idrxAmount);
    }

    function calculateSwap(
        address fromToken,
        uint256 amountIn
    ) public view returns (uint256) {
        require(
            fromToken == address(tokenDAO) || fromToken == address(idrx),
            "Invalid fromToken"
        );
        bool isDAOtoIDRX = fromToken == address(tokenDAO);
        uint256 reserveIn = isDAOtoIDRX ? daoPool : idrxPool;
        uint256 reserveOut = isDAOtoIDRX ? idrxPool : daoPool;
        require(reserveIn > 0 && reserveOut > 0, "No liquidity");

        // Constant product formula with 0.3% fee
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    function swap(
        address fromToken,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external {
        require(block.timestamp <= deadline, "Swap expired");
        require(amountIn > 0, "Invalid amount");
        require(
            fromToken == address(tokenDAO) || fromToken == address(idrx),
            "Invalid fromToken"
        );

        bool isDAOtoIDRX = fromToken == address(tokenDAO);
        address toToken = isDAOtoIDRX ? address(idrx) : address(tokenDAO);

        uint256 amountOut = calculateSwap(fromToken, amountIn);
        require(amountOut >= minAmountOut, "Insufficient output amount");
        require(amountOut > 0, "Zero output");

        if (isDAOtoIDRX) {
            tokenDAO.transferFrom(msg.sender, address(this), amountIn);
            daoPool += amountIn;
            require(idrxPool >= amountOut, "Insufficient liquidity");
            idrxPool -= amountOut;
            idrx.transfer(msg.sender, amountOut);
        } else {
            idrx.transferFrom(msg.sender, address(this), amountIn);
            idrxPool += amountIn;
            require(daoPool >= amountOut, "Insufficient liquidity");
            daoPool -= amountOut;
            tokenDAO.transfer(msg.sender, amountOut);
        }

        emit Swapped(msg.sender, fromToken, toToken, amountIn, amountOut);
    }

    // View functions to get current exchange rate
    function getExchangeRate(
        address fromToken,
        uint256 amountIn
    ) external view returns (uint256) {
        return calculateSwap(fromToken, amountIn);
    }
}
