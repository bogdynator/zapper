// SPDX-License-Identifier: MIT
pragma solidity =0.6.6;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-periphery/contracts/UniswapV2Router02.sol";
import "./CustomRouterV3.sol";
import "@uniswap/v2-periphery/contracts/libraries/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

import "hardhat/console.sol";

/**
 * @author Softbinator Technologies
 * @notice This contract is an example of Zapper using Uniswap
 * @notice DISCLAIMER - These contracts are not audited, use at your own risk!
 */
contract Zapper {
    using SafeMath for uint256;

    /// @notice Address of Ethereum Wrapper
    address public WETH;
    /// @notice Address of UniswapV2 router
    CustomRouterV3 public router;

    /// @notice Event triggered on zapping into a pool where input token is part of
    event Zap(uint256, uint256, uint256);
    /// @notice Event triggered on zapping into a pool where input token is not part of the pool
    event ZapTokenToTokens(uint256, uint256, uint256);
    /// @notice Event triggered on zapping into a pool where WETH is part of
    event ZapETH(uint256, uint256, uint256);
    /// @notice Event triggered on zapping into a pool where WETH is not part of the pool
    event ZapETHToTokens(uint256, uint256, uint256);

    constructor(address _WETH, CustomRouterV3 _router) public {
        WETH = _WETH;
        router = _router;
    }

    /**
     * @notice This function is used to invest in a pair that contains the input token(ERC20)
     * @param token input token
     * @param pair pair where to add liquidity
     * @param amount amount of input token to invest
     * @return liq amount of liquidity resulted from adding tokens
     */
    function zapToken(
        address token,
        address pair,
        uint256 amount
    ) external returns (uint256 liq) {
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        require(token == token0 || token == token1, "Invalid pair");

        IERC20(token).transferFrom(msg.sender, address(this), amount); /// @notice bring all tokens to contract

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();

        address swapToken = token == token0 ? token1 : token0;
        uint256 swapReserve = token == token0 ? reserve1 : reserve0;

        uint256 amountToSwap = getSwapAmount(amount, swapReserve); /// @notice get the amount of neccessary token to be swapped in order to add Liq

        IERC20(token).approve(address(router), amount);

        address[] memory path = new address[](2); /// @notice create pair
        path[0] = token;
        path[1] = swapToken;

        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountToSwap,
            1,
            path,
            address(this),
            block.timestamp
        ); /// @notice swap amount and send to this contract the new tokens
        uint256 token0Bought = amount - amountToSwap;
        uint256 token1Bought = amounts[1];

        IERC20(swapToken).approve(address(router), token1Bought);

        (, , uint256 liq) = router.addLiquidity(
            token0,
            token1,
            token0Bought,
            token1Bought,
            1,
            1,
            msg.sender,
            block.timestamp
        );

        emit Zap(liq, token0Bought, amountToSwap);

        return liq;
    }

    /**
     * @notice This function is used to invest in a pair that input token is not part of
     * @param token input token
     * @param pair pair where to add liquidity
     * @param amount amount of input token to invest
     * @return liq amount of liquidity resulted from adding tokens
     */
    function zapTokenForTokens(
        address token,
        address pair,
        uint256 amount
    ) external returns (uint256 liq) {
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        require(token != token0 && token != token1, "Invalid pair");

        IERC20(token).transferFrom(msg.sender, address(this), amount); /// @notice bring all tokens to contract

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves(); /// @notice get reserves

        IERC20(token).approve(address(router), amount);

        IERC20(token0).approve(address(router), amount);

        address[] memory path = new address[](2); /// @notice create pair
        path[0] = token;
        path[1] = token0;

        uint256[] memory amounts = router.swapExactTokensForTokens(amount, 1, path, address(this), block.timestamp); /// @notice swap amount and send to this contract the new tokens
        uint256 tokenAmount = amounts[1];

        uint256 amountToSwap = getSwapAmount(tokenAmount, reserve1); /// @notice get the amount of neccessary token to be swapped in order to add Liq

        IERC20(token1).approve(address(router), amountToSwap);

        path[0] = token0;
        path[1] = token1;

        uint256[] memory amountsToken1 = router.swapExactTokensForTokens(
            amountToSwap,
            1,
            path,
            address(this),
            block.timestamp
        ); /// @notice swap amount and send to this contract the new tokens

        uint256 token0Amount = tokenAmount - amountToSwap;
        uint256 token1Bought = amountsToken1[1];

        (, , uint256 liq) = router.addLiquidity(
            token0,
            token1,
            token0Amount,
            token1Bought,
            1,
            1,
            msg.sender,
            block.timestamp
        );

        emit ZapTokenToTokens(liq, token0Amount, amountToSwap);
        return liq;
    }

    /**
     * @notice This function is used to invest eth in a pair that contains the WETH
     * @param pair pair where to add liquidity
     * @return liq amount of liquidity resulted from adding tokens
     */
    function zapEth(address pair) external payable returns (uint256 liq) {
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        require(token0 == WETH || token1 == WETH, "Invalid pair");
        IWETH(WETH).deposit{ value: msg.value }();

        IWETH(WETH).transfer(address(this), msg.value); /// @notice transfer to this contract the WETH

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves(); /// @notice get reserves

        /// @notice get swap amount

        address swapToken = WETH == token0 ? token1 : token0;
        uint256 swapReserve = WETH == token0 ? reserve1 : reserve0;

        /// @notice swap

        uint256 amountToSwap = getSwapAmount(msg.value, swapReserve); /// @notice get the amount of neccessary token to be swapped in order to add Liq

        IWETH(WETH).approve(address(router), msg.value);

        address[] memory path = new address[](2); /// @notice create pair
        path[0] = WETH;
        path[1] = swapToken;

        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountToSwap,
            1,
            path,
            address(this),
            block.timestamp
        ); /// @notice swap amount and send to this contract the new tokens
        uint256 token0Bought = msg.value - amountToSwap;
        uint256 token1Bought = amounts[1];

        IERC20(swapToken).approve(address(router), token1Bought);

        (, , uint256 liq) = router.addLiquidity(
            token0,
            token1,
            token0Bought,
            token1Bought,
            1,
            1,
            msg.sender,
            block.timestamp
        );

        emit ZapETH(liq, token0Bought, amountToSwap);

        return liq;
    }

    /**
     * @notice This function is used to invest eth in a pair where WETH is not part of
     * @param pair pair where to add liquidity
     * @return liq amount of liquidity resulted from adding tokens
     */
    function zapEthToTokens(address pair) external payable returns (uint256 liq) {
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        require(WETH != token0 && WETH != token1, "Invalid pair");

        /// @notice transfrom eth to weth
        IWETH(WETH).deposit{ value: msg.value }();

        IWETH(WETH).transfer(address(this), msg.value); /// @notice transfer to this contract the WETH

        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves(); /// @notice get reserves
        uint256 amount = msg.value;

        IWETH(WETH).approve(address(router), amount);

        IERC20(token0).approve(address(router), amount);

        address[] memory path = new address[](2); /// @notice create pair
        path[0] = WETH;
        path[1] = token0;

        uint256[] memory amounts = router.swapExactTokensForTokens(amount, 1, path, address(this), block.timestamp); /// @notice swap amount and send to this contract the new tokens
        uint256 tokenAmount = amounts[1];

        uint256 amountToSwap = getSwapAmount(tokenAmount, reserve1); /// @notice get the amount of neccessary token to be swapped in order to add Liq

        IERC20(token1).approve(address(router), amountToSwap);

        path[0] = token0;
        path[1] = token1;

        uint256[] memory amountsToken1 = router.swapExactTokensForTokens(
            amountToSwap,
            1,
            path,
            address(this),
            block.timestamp
        ); /// @notice swap amount and send to this contract the new tokens

        uint256 token0Amount = tokenAmount - amountToSwap;
        uint256 token1Bought = amountsToken1[1];

        (, , uint256 liq) = router.addLiquidity(
            token0,
            token1,
            token0Amount,
            token1Bought,
            1,
            1,
            msg.sender,
            block.timestamp
        );

        emit ZapETHToTokens(liq, token0Amount, amountToSwap);
        return liq;
    }

    function getSwapAmount(uint256 amount, uint256 reserve) public pure returns (uint256) {
        return sqrt(reserve.mul(amount.mul(3988000) + reserve.mul(3988009))).sub(reserve.mul(1997)) / 1994;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
