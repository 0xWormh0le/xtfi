//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

interface IEthPool {
  event RewardDeposited(address indexed depositor, uint256 amount);

  event Deposited(address indexed depositor, uint256 amount);

  event Withdrawn(address indexed withdrawer, uint256 amount);

  function depositRewards() payable external;

  function deposit() payable external;

  function rewardBalanceOf(address user) external view returns (uint256);

  function withdrawBalanceOf(address user) external view returns (uint256);

  function withdraw(address payable recipient) external;
}
