//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IEthPool.sol";


/**
 *  d: user deposit
 *  r: reward deposit
 *  w: first user withdrawl
 *  w*: user withdrawl now
 *
 *  timeline:
 *  ---- d ---- r ---- w ---- d ---- r ---- d ---- w* ---->
 *
 *  ---------------------------------------->                total deposit
 *  --------------------------------->                       rewards
 *  ------------------->                                     reward on last withdrawl
 *  ------------------->                                     deposit before last withdrawl
 *                                   +------>                deposit after last reward
 *                     +------------->                       deposits applicable to this part participates in user reward calculation
 *
 *  user reward =
 *     (rewards - reward on last withdrawl) *
 *     (total deposit -  deposit before last withdraw - deposit after last withdrawl) /
 *     total deposit before last rewards
 *
 */
contract EthPool is IEthPool, AccessControl, ReentrancyGuard {

  struct UserInfo {
    uint256 totalDeposit;
    uint256 depositAfterLastReward;
    uint256 depositBeforeLastWithdraw;
    uint256 lastDepositBlock;
    uint256 lastWithdrawBlock;
    /// @dev rewards deposited until the user's last withdrawal
    uint256 rewardOnLastWithdraw;
    /// @dev total deposit made from all users until the user's last withdrawl
    uint256 totalDepositBeforeLastWithdraw;
  }

  bytes32 constant TEAM_ROLE = DEFAULT_ADMIN_ROLE;

  /// @dev total rewards deposited by team members
  uint256 public rewards;

  /// @dev total deposit made by users
  uint256 public totalDeposit;

  /// @dev block where the last reward is deposited
  uint256 public lastRewardBlock;

  /// @dev total deposit made by all users until the last reward deposit
  uint256 public totalDepositBeforeLastReward;

  /// @dev user address => user info
  mapping(address => UserInfo) public userInfos;


  receive() external payable { }

  constructor() ReentrancyGuard() {
    _setupRole(TEAM_ROLE, msg.sender);
  }

  /**
   * @dev check if he is a team member
   */
  modifier onlyTeamMember() {
    require(hasRole(TEAM_ROLE, msg.sender), "Not team member");
    _;
  }

  /**
   * @dev put reward to pool
   */
  function depositRewards() payable external override onlyTeamMember {
    rewards += msg.value;
    totalDepositBeforeLastReward = totalDeposit;
    lastRewardBlock = block.number;

    emit RewardDeposited(msg.sender, msg.value);
  }

  /**
   * @dev make user deposit
   */
  function deposit() payable external override {
    UserInfo storage userInfo = userInfos[msg.sender];

    totalDeposit += msg.value; 
    userInfo.totalDeposit += msg.value;

    if (userInfo.lastWithdrawBlock < lastRewardBlock) {

      // note: this should be EQUAL or less than
      // otherwise depositAfterLastReward will never be reset
      // if reward and deposit happens on the same block
      if (userInfo.lastDepositBlock <= lastRewardBlock) {
        userInfo.depositAfterLastReward = 0;
      }

      userInfo.depositAfterLastReward += msg.value;
      userInfo.lastDepositBlock = block.number;
    }

    emit Deposited(msg.sender, msg.value);
  }

  /**
   * @dev get reward amount of user (except deposit)
   * @param user address of user
   * @return reward
   */
  function rewardBalanceOf(address user) public override view returns (uint256) {
    UserInfo storage userInfo = userInfos[user];
    uint256 depositAfterLastReward = userInfo.depositAfterLastReward;
    uint256 totalDepositSinceLastWithdraw = totalDepositBeforeLastReward - userInfo.totalDepositBeforeLastWithdraw;
    uint256 userDeposit;

    if (userInfo.lastDepositBlock < lastRewardBlock) {
      // no user deposit is made after the last reward deposit
      // hence user.depositAFterReward is not updated, we use 0
      depositAfterLastReward = 0;
    }

    // calcualte user deposit made between his last withdrawl and the last reward deposit
    // since user reward is calulated from user deposit made before the reward deposit
    if (userInfo.lastWithdrawBlock < lastRewardBlock) {
      userDeposit = userInfo.totalDeposit - userInfo.depositBeforeLastWithdraw - depositAfterLastReward;
    }

    if (totalDepositSinceLastWithdraw == 0) {
      return 0;
    }

    // if the above condition does not meet, it is when no reward deposit is made after the last withdrawl
    // we leave user deposit as 0 though user deposits are made after the last withdrawl
    // because they don't participate in user reward calculation

    // A = reward deposit after the last user withdrawl *
    // B = user deposit between his last withdrawl and the last reward deposit
    //     (user deposit made after the last reward deposit won't affect on reward calculation)
    // C = total deposit made from all users between the user's last withdrawl and the last reward deposit
    // user reward = A * B / C
    return (rewards - userInfo.rewardOnLastWithdraw) * userDeposit / totalDepositSinceLastWithdraw;
  }

  /**
   * @dev get amount available to withdraw
   * @param user address of user
   * @return value
   */
  function withdrawBalanceOf(address user) public override view returns (uint256) {
    UserInfo storage userInfo = userInfos[user];
    return userInfo.totalDeposit - userInfo.depositBeforeLastWithdraw + rewardBalanceOf(user);
  }

  /**
   * @dev withdraw user deposit and reward to recipient
   * @param recipient recipient address
   */
  function withdraw(address payable recipient) external override nonReentrant {
    uint256 amount = withdrawBalanceOf(msg.sender);

    if (amount > 0) {
      UserInfo storage userInfo = userInfos[msg.sender];

      userInfo.depositBeforeLastWithdraw = userInfo.totalDeposit;
      userInfo.lastWithdrawBlock = block.number;
      userInfo.rewardOnLastWithdraw = rewards;
      userInfo.totalDepositBeforeLastWithdraw = totalDepositBeforeLastReward;

      (bool success, ) = recipient.call{value: amount}("");
      require(success, "Failed to withdraw");
    }

    emit Withdrawn(msg.sender, amount);
  }
}
