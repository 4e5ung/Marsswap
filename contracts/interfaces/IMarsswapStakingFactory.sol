// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IMarsswapStakingFactory {
    event PoolCreated(address indexed token);

    function getPool(address token) external view returns (address pool);
    function allPools(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function deployPool(address _stakedToken,
        address _rewardToken,
        uint256 _rewardPerSecond,
        uint256 _startTimestamp,
        uint256 _bonusEndTimestamp,
        uint256 _poolLimitPerUser,
        address _admin
    ) external returns(address pool);
}
