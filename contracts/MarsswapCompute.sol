// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './libraries/Babylonian.sol';
import './libraries/FullMath.sol';
import './libraries/MarsswapLibrary.sol';
import './interfaces/IMarsswapPair.sol';
import './interfaces/IMarsswapFactory.sol';

contract MarsCompute {
    address public factory;

    constructor(address factory_) {
        factory = factory_;
    }

    // computes liquidity value given all the parameters of the pair
    function computeLiquidityValue(
        uint256 reservesA,
        uint256 reservesB,
        uint256 totalSupply,
        uint256 liquidityAmount,
        bool feeOn,
        uint kLast
    ) internal pure returns (uint256 tokenAAmount, uint256 tokenBAmount) {
        if (feeOn && kLast > 0) {
            uint rootK = Babylonian.sqrt(reservesA * reservesB);
            uint rootKLast = Babylonian.sqrt(kLast);
            if (rootK > rootKLast) {
                uint numerator1 = totalSupply;
                uint numerator2 = rootK-rootKLast;
                uint denominator = (rootK*5) + rootKLast;
                uint feeLiquidity = FullMath.mulDiv(numerator1, numerator2, denominator);
                totalSupply = totalSupply+feeLiquidity;
            }
        }
        return ((reservesA*liquidityAmount) / totalSupply, (reservesB*liquidityAmount) / totalSupply);
    }

    function getLiquidityValue(
        address tokenA,
        address tokenB,
        uint256 liquidityAmount
    ) external view returns (
        uint256 tokenAAmount,
        uint256 tokenBAmount
    ) {
        (uint256 reservesA, uint256 reservesB) = MarsswapLibrary.getReserves(factory, tokenA, tokenB);
        IMarsswapPair pair = IMarsswapPair(MarsswapLibrary.pairFor(factory, tokenA, tokenB));
        bool feeOn = IMarsswapFactory(factory).feeTo() != address(0);
        uint kLast = feeOn ? pair.kLast() : 0;
        uint totalSupply = pair.totalSupply();
        return computeLiquidityValue(reservesA, reservesB, totalSupply, liquidityAmount, feeOn, kLast);
    }


    function _getAmounts(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal view virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        require(IMarsswapFactory(factory).getPair(tokenA, tokenB) != address(0), 'MarsCompute: ZERO_ADDRESS');

        (uint reserveA, uint reserveB) = MarsswapLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = MarsswapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'MarsCompute: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = MarsswapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'MarsCompute: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function getShareOfPool(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, bool owned)
        public
        view
        returns (uint poolRatio)
    {
        uint precision = 4;

        address pair = MarsswapLibrary.pairFor(factory, tokenA, tokenB);
        uint totalLiquidity = IMarsswapPair(pair).totalSupply();
        require( totalLiquidity > 0, 'MarsCompute, ZERO SUPPLY');

        uint liquidity;

        if( owned ){
            liquidity = IMarsswapPair(pair).balanceOf(msg.sender);
        }else{
            (uint amountA, uint amountB) = _getAmounts(tokenA, tokenB, amountADesired, amountBDesired, 0, 0);
            (uint amount0, uint amount1) = tokenA < tokenB ? (amountA, amountB) : (amountB, amountA);
            liquidity = IMarsswapPair(pair).getLiquidity(amount0, amount1);
            totalLiquidity = totalLiquidity+liquidity;
        }

        uint _numerator  = liquidity * (10 ** (precision+1));
        uint _quotient =  ((_numerator / (totalLiquidity)) + 5) / 10;

        if( liquidity > 0 )
            return _quotient >= 10000 ? 10000 : _quotient;
        else
            return 0;
    }
}