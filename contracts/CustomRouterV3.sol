// SPDX-License-Identifier: MIT
pragma solidity =0.6.6;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

import "hardhat/console.sol";

/**
 * @author Softbinator Technologies
 * @notice This Contract is made after Uniswap V2 router contract
 * @notice DISCLAIMER - These contracts are not audited, use at your own risk!
 */
contract CustomRouterV3 is IUniswapV2Router02 {
    /// @notice Factory contract that creates pairs of lp
    address public override factory;

    /// @notice WETH represents a token that wraps eth, 1 WETH = 1 eth at any moment
    address public override WETH;

    /// @notice Event triggered when liquidity is added as 2 tokens
    event Liq(uint256);

    /// @notice Event triggered when liquidity is added as a token and eth
    event LiqETH(uint256);

    /// @notice Event triggered when liquidity is removed from a token-token pair
    event RemoveLiquidity(address, uint256, uint256);

    /// @notice Event triggered when liquidity is removed from a token-eth pair
    event RemoveLiquidityETH(address, uint256, uint256);

    /// @notice Event triggered when a swap with a fixed amount of input tokens and flexible output amount is made
    event SwapExactTokensForTokens(uint256 amountIn, uint256 amountOut);

    /// @notice Event triggered when a swap where input amount(token1) is flexible and the output amount(token2) is fixed
    event SwapTokensForExactTokens(uint256 amountIn, uint256 amountOut);

    /// @notice Event triggered when a swap where input amount(token) is flexible and the output amount(WETH/eth) is fixed
    event SwapTokensForExactETH(uint256 amountIn, uint256 amountOut);

    /// @notice Event triggered when a swap where input amount(eth) is fixed and the output amount(WETH/eth) is flexible
    event SwapExactETHForTokens(uint256 amountIn, uint256 amountOut);

    /// @notice Event triggered when a swap where input amount(token) is fixed and the output amount(WETH/eth) is flexible
    event SwapExactTokensForETH(uint256 amountIn, uint256 amountOut);

    /// @notice Event triggered when a swap where input amount(eth) is flexible and the output amount(token) is fixed
    event SwapETHForExactTokens(uint256 amountIn, uint256 amountOut);

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
    }

    /**
     * @notice Function that calculates the amount needed for adding liquidity
     * @param tokenA represents the address of the first token
     * @param tokenB represents the address of the second token
     * @param amountADesired represents the amount of first token to be deposited
     * @param amountBDesired represents the amount of second token to be deposited
     * @param amountAMin represents the minimum amount of the first token to be deposited
     * @param amountBMin represents the minimum amount of the first token to be deposited
     * @param to represents address that will receive the liquidity tokens
     */
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) internal returns (uint256 amountA, uint256 amountB) {
        if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IUniswapV2Factory(factory).createPair(tokenA, tokenB);
        }

        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);

        /// @dev if the reserves are 0, then the pool wasn't initialize and there is no rate between the 2 tokens
        /// @dev so the user can deposit any amount
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            /// @dev if the reserves are != 0, then we need to check the rate of the tokens

            /// @dev quote function returns us the echivalent amount of a token in another token depending on reserves
            uint256 expectedAmountB = UniswapV2Library.quote(amountADesired, reserveA, reserveB);

            if (expectedAmountB < amountBMin || expectedAmountB > amountBDesired) {
                uint256 expectedAmountA = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);
                require(expectedAmountA >= amountAMin, "expected amount A < amountAMin");
                require(expectedAmountA <= amountADesired, "expected amount A > amountADesired");
                (amountA, amountB) = (expectedAmountA, amountBDesired);
            } else {
                (amountA, amountB) = (amountADesired, expectedAmountB);
            }
        }
    }

    /**
     * @notice Add liqudity to a pair of tokens
     * @param tokenA represents the address of the first token
     * @param tokenB represents the address of the second token
     * @param amountADesired represents the amount of first token to be deposited
     * @param amountBDesired represents the amount of second token to be deposited
     * @param amountAMin represents the minimum amount of the first token to be deposited
     * @param amountBMin represents the minimum amount of the first token to be deposited
     * @param to represents address that will receive the liquidity tokens
     * @param deadline represents the timestamp
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to);

        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);

        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);

        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);

        liquidity = IUniswapV2Pair(pair).mint(to);
        emit Liq(liquidity);
    }

    /**
     * @notice Add liqudity to a pair made of token and WETH
     * @notice This case need a separate function because the user will send eth and we will convert it to token - WETH
     * @param token represents the address of the token
     * @param amountTokenDesired represents the token amount to be deposited
     * @param amountTokenMin represents the minimum amount of the token to be deposited
     * @param to represents address that will receive the liquidity tokens
     * @param deadline represents the timestamp
     */
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin,
            to
        );
        address pair = UniswapV2Library.pairFor(factory, token, WETH);

        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);

        /// @dev convert eth to WETH
        IWETH(WETH).deposit{ value: amountETH }();
        IWETH(WETH).transfer(pair, amountETH);

        /// @dev send back remaining eth
        if (amountETH < msg.value) {
            TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
        }

        liquidity = IUniswapV2Pair(pair).mint(to);
        emit LiqETH(liquidity);
    }

    /**
     * @notice Remove liquidity and return tokens from pair
     * @param tokenA represents the address of the first token
     * @param tokenB represents the address of the second token
     * @param liquidity represents liquidity that will be converted to tokens
     * @param amountAMin represents the minimum amount of the first token to be received
     * @param amountBMin represents the minimum amount of the second token to be received
     * @param to represents the address that will consume liquidity
     * @param deadline represents the timestamp
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);

        /// @dev transfer liquidity from msg.sender to pair
        /// @dev because burn function uses reserve and balance to determin waht liquidity is burned
        IUniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity);

        /// @dev burn the liquidity that we just sent
        (amountA, amountB) = IUniswapV2Pair(pair).burn(to);

        /// @dev sort tokens to know what amount is corresponding to tokenA and tokenB
        (address token1, ) = UniswapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = token1 == tokenA ? (amountA, amountB) : (amountB, amountA);

        require(amountA >= amountAMin, "Amount of first token is less than expected");
        require(amountB >= amountBMin, "Amount of second token is less than expected");

        emit RemoveLiquidity(to, amountA, amountB);
    }

    /**
     * @notice Remove liquidity and return tokens from pair
     * @param token represents the address of the token
     * @param liquidity represents liquidity that will be converted to tokens
     * @param amountTokenMin represents the minimum amount of tokens to be received
     * @param amountETHMin represents the minimum amount of eth to be received
     * @param to represents the address that will consume liquidity
     * @param deadline represents the timestamp
     */
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override returns (uint256 amountToken, uint256 amountETH) {
        address pair = UniswapV2Library.pairFor(factory, token, WETH);

        /// @dev transfer liquidity from msg.sender to pair
        /// @dev because burn function uses reserve and balance to determin waht liquidity is burned
        IUniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity);

        /// @dev use burn function with this contract address because we want to convert WET in eth
        (uint256 amount1, uint256 amount2) = IUniswapV2Pair(pair).burn(address(this));

        /// @dev sort tokens to know what amount is corresponding to token and what to WETH
        (address token1, ) = UniswapV2Library.sortTokens(token, WETH);
        (amountToken, amountETH) = token1 == token ? (amount1, amount2) : (amount2, amount1);

        require(amountToken >= amountTokenMin, "Amount of token is less than expected");
        require(amountETH >= amountETHMin, "Eth amount is less than expected");

        /// @dev send tokens to "to"
        TransferHelper.safeTransfer(token, to, amountToken);

        /// @dev change the WETH amount to eth(withdraw) and send to "to"
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);

        emit RemoveLiquidityETH(to, amountToken, amountETH);
    }

    /**
     * @notice Swap functionality
     * @param path represents an array with addresses that are the tokens between the swap is made
     * @param to represents the address that will consume liquidity
     * @param amounts represents the amounts for each pair
     */
    function _swap(
        address[] memory path,
        address to,
        uint256[] memory amounts
    ) internal {
        /// @dev iterate through path and swap tokens
        for (uint256 i; i < path.length - 1; ++i) {
            /// @dev sort token to know what value to attribute to amount0Out and amount1Out.
            /// @dev check swap function from Pair contract
            (address input, ) = UniswapV2Library.sortTokens(path[i], path[i + 1]);

            /// @dev it is known that the path indicate the input token and output token,
            /// @dev so the output amount will correspond to i + 1
            uint256 amountOut = amounts[i + 1];

            /// @dev we use uint256(0) because the we need to get only one amount of tokens from swap
            (uint256 amount0Out, uint256 amount1Out) = input == path[i]
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));

            address pair = UniswapV2Library.pairFor(factory, path[i], path[i + 1]);

            /// @dev move funds from pair to pair and last to "to"
            address destination = i < path.length - 2
                ? UniswapV2Library.pairFor(factory, path[i + 1], path[i + 2])
                : to;

            IUniswapV2Pair(pair).swap(amount0Out, amount1Out, destination, new bytes(0));
        }
    }

    /**
     * @notice Swap a fixed amount of input tokens and expect flexible output amount of tokens
     * @param amountIn represents the amount of input token
     * @param amountOutMin represents the minnimum amount of output token
     * @param path represents an array with addresses that are the tokens between the swap is made
     * @param to represents the address that will consume liquidity
     * @param deadline represents the timestamp
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override returns (uint256[] memory amounts) {
        require(
            IUniswapV2Factory(factory).getPair(path[path.length - 2], path[path.length - 1]) != address(0),
            "No output pair"
        );
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Output amount is less than the minimum amount");

        /// @dev send the input token to first pair
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );

        // IERC20(path[0]).transferFrom(msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);

        _swap(path, to, amounts);

        emit SwapExactTokensForTokens(amountIn, amounts[amounts.length - 1]);
    }

    /**
     * @notice Swap a fixed amount of eth and expect flexible output amount of tokens
     * @param amountOutMin represents the minnimum amount of output token
     * @param path represents an array with addresses that are the tokens between the swap is made
     * @param to represents the address that will consume liquidity
     * @param deadline represents the timestamp
     */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable override returns (uint256[] memory amounts) {
        /// @dev check if first address in the path corresponds to WETH
        require(path[0] == WETH, "First address have to be WETH");
        amounts = UniswapV2Library.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Output amount is less than the minimum amount");

        /// @dev convert eth to WETH
        IWETH(WETH).deposit{ value: msg.value }();

        /// @dev send the WETH to first pair
        IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);

        _swap(path, to, amounts);

        emit SwapExactETHForTokens(msg.value, amounts[amounts.length - 1]);
    }

    /**
     * @notice Swap a flexible amount of input tokens to obtain a fixed amount of output tokens
     * @param amountOut represents the amount of output token
     * @param amountInMax represents the maximum amount of input token
     * @param path represents an array with addresses that are the tokens between the swap is made
     * @param to represents the address that will consume liquidity
     * @param deadline represents the timestamp
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "Input amount is greater than the maximum amount");

        /// @dev send the input tokens to first pair
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );

        _swap(path, to, amounts);

        emit SwapTokensForExactTokens(amounts[0], amountOut);
    }

    /**
     * @notice Swap a flexible amount of input tokens to obtain a fixed amount of eth
     * @param amountOut represents the amount of output token
     * @param amountInMax represents the maximum amount of input token
     * @param path represents an array with addresses that are the tokens between the swap is made
     * @param to represents the address that will consume liquidity
     * @param deadline represents the timestamp
     */
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override returns (uint256[] memory amounts) {
        /// @dev check if last address in the path corresponds to WETH
        require(path[path.length - 1] == WETH, "Last address have to be WETH");
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "To much amount required");

        /// @dev send the input tokens to first pair
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );

        _swap(path, address(this), amounts);

        /// @dev change the WETH amount to eth(withdraw) and send to "to"
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);

        emit SwapTokensForExactETH(amounts[0], amountOut);
    }

    /**
     * @notice Remove liquidity by setting the allowance for a spender where approval is granted via a signature.
     * @param tokenA represents the address of the first token
     * @param tokenB represents the address of the second token
     * @param liquidity represents liquidity that will be converted to tokens
     * @param amountAMin represents the minimum amount of the first token to be received
     * @param amountBMin represents the minimum amount of the second token to be received
     * @param to represents the address that will consume liquidity
     * @param deadline represents the timestamp
     * @param approveMax represents the maximum approval
     * @param v required for checking signature
     * @param r required for checking signature
     * @param s required for checking signature
     */
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? 2**256 - 1 : liquidity;
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    /**
     * @notice Remove liquidity by setting the allowance for a spender where approval is granted via a signature.
     * @param token represents the address of the token
     * @param liquidity represents liquidity that will be converted to tokens
     * @param amountTokenMin represents the minimum amount of the token to be received
     * @param amountETHMin represents the minimum eth amount to be received
     * @param to represents the address that will consume liquidity
     * @param deadline represents the timestamp
     * @param approveMax represents the maximum approval
     * @param v required for checking signature
     * @param r required for checking signature
     * @param s required for checking signature
     */
    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountToken, uint256 amountETH) {
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    /**
     * @notice Swap a fixed amount of input tokens to eth
     * @param amountIn represents the amount of input token
     * @param amountOutMin represents the minimum amount of eth
     * @param path represents an array with addresses that are the tokens between the swap is made
     * @param to represents the address that will consume liquidity
     * @param deadline represents the timestamp
     */
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override returns (uint256[] memory amounts) {
        /// @dev check if last address in the path corresponds to WETH
        require(path[path.length - 1] == WETH, "Last address have to be WETH");
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Output amount is less than min");

        /// @dev send the input tokens to first pair
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(path, address(this), amounts);

        /// @dev change the WETH amount to eth(withdraw) and send to "to"
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);

        emit SwapExactTokensForETH(amountIn, amounts[amounts.length - 1]);
    }

    /**
     * @notice Swap eth to a fixed amount of output token
     * @param amountOut represents the amount of output token
     * @param path represents an array with addresses that are the tokens between the swap is made
     * @param to represents the address that will consume liquidity
     * @param deadline represents the timestamp
     */
    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override returns (uint256[] memory amounts) {
        /// @dev check if first address in the path corresponds to WETH
        require(path[0] == WETH, "First address in path have to be WETH");
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, "Required input is less than msg.value");

        /// @dev convert eth to WETH, because we need a token to make the swap
        IWETH(WETH).deposit{ value: amounts[0] }();

        /// @dev send the WETH to first pair
        IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, WETH, path[1]), amounts[0]);

        _swap(path, to, amounts);

        /// @dev send back extra eth
        if (amounts[0] < msg.value) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);

        emit SwapETHForExactTokens(amounts[0], amountOut);
    }

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure virtual override returns (uint256 amountB) {}

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure virtual override returns (uint256 amountOut) {}

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure virtual override returns (uint256 amountIn) {}

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {}

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {}

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external virtual override returns (uint256 amountETH) {}

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountETH) {}

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override {}

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override {}

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override {}

    receive() external payable {
        /// @notice only accept ETH via fallback from the WETH contract
        assert(msg.sender == WETH);
    }
}
