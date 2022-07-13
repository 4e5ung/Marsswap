// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IMarsswapFactory.sol";
import "./MarsswapPair.sol";
import "./console.sol";

contract MarsswapFactory  {
    address public feeTo;
    address public feeToSetter;
    
    uint8 public constant MIN_SWAP_FEE = 1;
    uint8 public constant MAX_SWAP_FEE = 100;
    uint8 public constant MIN_PROTOCOL_FEE = 1;
    uint8 public constant MAX_PROTOCOL_FEE = 10;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(MarsswapPair).creationCode);
    }

    function createPair(address tokenA, address tokenB, uint8 swapFee, uint8 protocolFee) external returns (MarsswapPair pair) {
        require(tokenA != tokenB, 'MarsswapFactory: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'MarsswapFactory: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'MarsswapFactory: PAIR_EXISTS'); // single check is sufficient

        pair = new MarsswapPair();

        // bytes memory bytecode = type(MarsswapPair).creationCode;
        // bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        // assembly {
        //     pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        // }

        pair.initialize(token0, token1, swapFee, protocolFee);
        getPair[token0][token1] = address(pair);
        getPair[token1][token0] = address(pair); // populate mapping in the reverse direction
        allPairs.push(address(pair));
        emit PairCreated(token0, token1, address(pair), allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'MarsswapFactory: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'MarsswapFactory: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setSwapFee(address tokenA, address tokenB, uint8 newFee ) external {
        require(msg.sender == feeToSetter, 'MarsswapFactory: FORBIDDEN');
        require(newFee >= MIN_SWAP_FEE && newFee <= MAX_SWAP_FEE, "MarsswapFactory: INVALID_SWAP_FEE");
        IMarsswapPair(getPair[tokenA][tokenB]).updateSwapFee(newFee);
    }

    function setProtocolFee(address tokenA, address tokenB, uint8 newFee ) external {
        require(msg.sender == feeToSetter, 'MarsswapFactory: FORBIDDEN');
        require(newFee >= MIN_PROTOCOL_FEE && newFee <= MAX_PROTOCOL_FEE, "MarsswapFactory: INVALID_SWAP_FEE");
        IMarsswapPair(getPair[tokenA][tokenB]).updateProtocolFee(newFee);
    }
}