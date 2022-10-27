// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "../../abstract/AccessControlledAndUpgradeable.sol";

import "../../interfaces/IGEMS.sol";

/** Contract giving user GEMS*/

// Inspired by https://github.com/andrecronje/rarity/blob/main/rarity.sol

/** @title GEMS */
contract GEMS is AccessControlledAndUpgradeable, IGEMS {
  bytes32 public constant GEM_ROLE = keccak256("GEM_ROLE");

  uint200 constant gems_per_day = 250e18;
  uint40 constant DAY = 1 days;

  /// @notice Number of gems for each user (deprecated variable)
  mapping(address => uint256) public gems_deprecated;
  /// @notice Length of gem streak for each user (deprecated variable)
  mapping(address => uint256) public streak_deprecated;
  /// @notice Timestamp of user's last interaction in the system (deprecated variable)
  mapping(address => uint256) public lastActionTimestamp_deprecated;

  // Pack all this data into a single struct.
  struct UserGemData {
    uint16 streak; // max 179 years - if someone reaches this streack, go them 🚀
    uint40 lastActionTimestamp; // will run out on February 20, 36812 (yes, the year 36812 - btw uint32 lasts untill the year 2106)
    uint200 gems; // this is big enough to last 6.4277522e+39 (=2^200/250e18) days 😆
  }
  mapping(address => UserGemData) userGemData;

  event GemsCollected(address user, uint256 gems, uint256 streak);

  /// @notice Creates an instance of the contract.
  function initialize() public initializer {
    // The below function ensures that this contract can't be re-initialized!
    _AccessControlledAndUpgradeable_init(msg.sender);

    _setupRole(GEM_ROLE, msg.sender);
  }

  /// @dev Only called once per user
  function attemptUserUpgrade(address user) internal returns (UserGemData memory transferedUserGemData) {
    uint256 usersCurrentGems = gems_deprecated[user];
    if (usersCurrentGems > 0) {
      transferedUserGemData = UserGemData(uint16(streak_deprecated[user]), uint40(lastActionTimestamp_deprecated[user]), uint200(usersCurrentGems));

      // reset old data (save some gas 😇)
      streak_deprecated[user] = 0;
      lastActionTimestamp_deprecated[user] = 0;
      gems_deprecated[user] = 0;
    }
  }

  // Say gm and get gems_deprecated by performing an action in market contract
  function gm(address user) external {
    UserGemData memory userData = userGemData[user];
    uint256 userslastActionTimestamp = uint256(userData.lastActionTimestamp);
    if (userslastActionTimestamp == 0) {
      // this is either a user migrating to the more efficient struct OR a brand new user.
      //      in both cases, this branch will only ever execute once!
      userData = attemptUserUpgrade(user);
      userslastActionTimestamp = uint256(userData.lastActionTimestamp);
    }

    uint256 blocktimestamp = block.timestamp;

    unchecked {
      if (blocktimestamp - userslastActionTimestamp >= DAY) {
        if (hasRole(GEM_ROLE, msg.sender)) {
          // Award gems_deprecated
          userData.gems += gems_per_day;

          // Increment streak_deprecated
          if (blocktimestamp - userslastActionTimestamp < 2 * DAY) {
            userData.streak += 1;
          } else {
            userData.streak = 1; // reset streak_deprecated to 1
          }

          userData.lastActionTimestamp = uint40(blocktimestamp);
          userGemData[user] = userData; // update storage once all updates are complete!

          emit GemsCollected(user, uint256(userData.gems), uint256(userData.streak));
        }
      }
    }
  }

  function balanceOf(address account) public view returns (uint256 balance) {
    balance = uint256(userGemData[account].gems);
    if (balance == 0) {
      balance = gems_deprecated[account];
    }
  }

  /// @notice Read the data stored in this contract for a particular user.
  /// @param account User who's data is to be returned
  /// @return gemData All user's data that is stored in the contract
  function getGemData(address account) public view returns (UserGemData memory gemData) {
    gemData = userGemData[account];
    if (gemData.gems == 0) {
      gemData = UserGemData(uint16(streak_deprecated[account]), uint40(lastActionTimestamp_deprecated[account]), uint200(gems_deprecated[account]));
    }
  }
}
