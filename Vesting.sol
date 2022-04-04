// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract Vesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    struct VestingInfo {
        uint256 startDate;
        uint256 amount;
        uint256 releasedAmount;
        uint256 amountPerMonth;
        uint256 lastReleaseDate;
    }

    uint256 public constant SECONDS_IN_MONTH = (365.255 * 24 * 60 * 60) / 12;
    uint256 public constant COUNT_OF_MONTH = 18;

    address public tokenAddress;
    mapping(address => mapping(uint256 => VestingInfo)) public usersVestings;
    mapping(address => uint256) public usersIndexes;

    event Released(address userAddress, uint256 amount, uint256 iteration);

    constructor(address _tokenAddress, address owner) {
        require(_tokenAddress != address(0) && owner != address(0), "Incorrect addresses");
        tokenAddress = _tokenAddress;
        transferOwnership(owner);
    }

    /**
     * @dev Starts the vesting process for each buyer in the ICO contract when buying in rounds 101-201,
     * called automatically by the ICO contract
     */
    function startVesting(address memberAddress, uint256 amount) public onlyOwner {
        VestingInfo memory vestingInfo =
        VestingInfo(block.timestamp, amount, 0, amount / COUNT_OF_MONTH, block.timestamp);
        usersVestings[memberAddress][usersIndexes[memberAddress]] = vestingInfo;
        usersIndexes[memberAddress] = usersIndexes[memberAddress] + 1;
    }

    /**
    * @dev Returns the amount that is available for withdrawal at the time of the call
    */

    function getReleaseReadyAmount() public view returns (uint256 releaseReadyAmount) {
        for (uint i = 0; i < usersIndexes[msg.sender]; i++) {
            if (
                usersVestings[msg.sender][i].startDate > 0
                && getDiffMonth(usersVestings[msg.sender][i].startDate, usersVestings[msg.sender][i].lastReleaseDate)
            <= COUNT_OF_MONTH
            ) {
                if (
                    usersVestings[msg.sender][i].amount - usersVestings[msg.sender][i].releasedAmount
                    >= usersVestings[msg.sender][i].amountPerMonth
                ) {
                    uint256 month = getDiffMonth(usersVestings[msg.sender][i].lastReleaseDate, block.timestamp);

                    if (month > 18) {
                        month = 18 - getDiffMonth(usersVestings[msg.sender][i].startDate, usersVestings[msg.sender][i].lastReleaseDate);
                    }
                    uint256 availableReleaseAmount = usersVestings[msg.sender][i].amountPerMonth * month;

                    if (
                        usersVestings[msg.sender][i].amount
                        - (usersVestings[msg.sender][i].releasedAmount + availableReleaseAmount)
                        < usersVestings[msg.sender][i].amountPerMonth
                    ) {
                        availableReleaseAmount +=
                        usersVestings[msg.sender][i].amount
                        - (usersVestings[msg.sender][i].releasedAmount + availableReleaseAmount);
                    }

                    releaseReadyAmount += availableReleaseAmount;
                } else {
                    releaseReadyAmount +=
                    usersVestings[msg.sender][i].amount
                    - usersVestings[msg.sender][i].releasedAmount;
                }
            }
        }
    }

    /**
    * @dev Sends to the user tokens that are available for withdrawal at the time of the call
    */
    function release() public nonReentrant {
        uint256 totalAmount;
        for (uint i = 0; i < usersIndexes[msg.sender]; i++) {
            if (
                usersVestings[msg.sender][i].startDate > 0
                && getDiffMonth(usersVestings[msg.sender][i].startDate, usersVestings[msg.sender][i].lastReleaseDate)
            <= COUNT_OF_MONTH
            ) {
                uint256 releaseReadyAmount;
                uint256 month = getDiffMonth(usersVestings[msg.sender][i].lastReleaseDate, block.timestamp);
                if (
                    usersVestings[msg.sender][i].amount - usersVestings[msg.sender][i].releasedAmount
                    >= usersVestings[msg.sender][i].amountPerMonth
                ) {
                    if (month > 18) {
                        month = 18 - getDiffMonth(usersVestings[msg.sender][i].startDate, usersVestings[msg.sender][i].lastReleaseDate);
                    }
                    uint256 availableReleaseAmount = usersVestings[msg.sender][i].amountPerMonth * month;

                    if (
                        usersVestings[msg.sender][i].amount
                        - (usersVestings[msg.sender][i].releasedAmount + availableReleaseAmount)
                        < usersVestings[msg.sender][i].amountPerMonth
                    ) {
                        availableReleaseAmount +=
                        usersVestings[msg.sender][i].amount
                        - (usersVestings[msg.sender][i].releasedAmount + availableReleaseAmount);
                    }
                    releaseReadyAmount += availableReleaseAmount;
                } else {
                    releaseReadyAmount +=
                    usersVestings[msg.sender][i].amount
                    - usersVestings[msg.sender][i].releasedAmount;
                }
                if (releaseReadyAmount > 0) {
                    usersVestings[msg.sender][i].releasedAmount += releaseReadyAmount;
                    usersVestings[msg.sender][i].lastReleaseDate += SECONDS_IN_MONTH * month;
                    totalAmount += releaseReadyAmount;
                    emit Released(msg.sender, releaseReadyAmount, i);
                }
            }
        }
        require(totalAmount > 0, 'Vesting not available now');
        IERC20(tokenAddress).transfer(msg.sender, totalAmount);
    }

    function getDiffMonth(uint256 previouseTimestamp, uint256 currentTimestamp) internal pure returns (uint256) {
        return (currentTimestamp - previouseTimestamp) / SECONDS_IN_MONTH;
    }

}