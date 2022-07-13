// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IMarsswapStakingPool {
    function deposit(uint256 _amount, address _from) external;
    function withdraw(uint256 _amount, address _from) external;
    // function pendingReward(address _user) external view returns (uint256);
    function userState(address _user) external view returns (uint256 amount, uint256 rewardDebt);
}
