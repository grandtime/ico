// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Asset is ERC20, ERC20Burnable, Ownable, ReentrancyGuard {
    address private _admin;
    uint256 public lastMintTimestamp;

    address public socialMining;
    address public teamAndDevelopment;
    address public charity;
    address public liquidityAndMarketing;

    //Minting limit per day
    uint256 public constant mintLimit = 1 * 10 ** 7 * 10 ** 18;
    uint256 public minted;
    //Seconds per day
    uint256 public constant secondsPerDay = 24 * 60 * 60;
    //Max amount of social mining
    uint256 public maxAmountSocialMining = 7000000 * 10 ** 18;
    uint256 public maxAmountTeamAndDevelopment = 1000000 * 10 ** 18;
    uint256 public maxAmountCharity = 1000000 * 10 ** 18;
    uint256 public maxAmountLiquidityAndMarketing = 1000000 * 10 ** 18;


    event AdministrationTransferred(address indexed previousAdmin, address indexed newAdmin);
    event SocialMiningChanged(address indexed socialMinting, address indexed newSocialMining);
    event TeamAndDevelopmentChanged(address indexed teamAndDevelopment, address indexed newTeamAndDevelopment);
    event CharityChanged(address indexed charity, address indexed newCharity);
    event LiquidityAndMarketingChanged(address indexed liquidityAndMarketing, address indexed newLiquidityAndMarketing);
    event MintLimitChanged(uint256 indexed previousLimit, uint256 indexed newLimit);
    event Distributed(uint256 indexed amount);

    constructor(
        string memory name_,
        string memory symbol_,
        address adminAddress,
        address owner,
        address socialMiningAddress,
        address charityAddress,
        address liquidityAndMarketingAddress,
        address teamAndDevelopmentAddress
    ) ERC20(name_, symbol_)  {
        lastMintTimestamp = block.timestamp - (block.timestamp % secondsPerDay);
        _mint(msg.sender, 2220220222 * 10 ** 18);
        transferAdministration(adminAddress);
        transferOwnership(owner);
        socialMining = socialMiningAddress;
        charity = charityAddress;
        liquidityAndMarketing = liquidityAndMarketingAddress;
        teamAndDevelopment = teamAndDevelopmentAddress;
    }

    /**
    * @dev Returns the address of the current admin.
     */
    function admin() public view virtual returns (address) {
        return _admin;
    }

    /**
    * @dev Throws if called by any account other than the admin.
     */
    modifier onlyAdmin() {
        require(admin() == _msgSender(), "Caller is not the admin");
        _;
    }

    /**
     * @dev Transfers administration of the contract to a new account (`newAdmin`).
     * Can only be called by the current owner.
     */
    function transferAdministration(address newAdmin) public virtual onlyOwner {
        require(newAdmin != address(0), "New admin is the zero address");
        emit AdministrationTransferred(_admin, newAdmin);
        _admin = newAdmin;
    }
    
    /**
     * @dev Changes amounts of tokens for the distribution.
     * Can only be called by the current admin.
     */
    function setDistributionAmounts(
        uint256 newLimitSM,
        uint256 newLimitLAM,
        uint256 newLimitTAD,
        uint256 newLimitC
    ) public virtual onlyAdmin {
        uint256 newMaxDistribution = newLimitC + newLimitLAM + newLimitSM + newLimitTAD;
        require(newMaxDistribution <= mintLimit, 'Mint limit can`t be less than distribution amount');
        maxAmountTeamAndDevelopment = newLimitTAD;
        maxAmountSocialMining = newLimitSM;
        maxAmountCharity = newLimitC;
        maxAmountLiquidityAndMarketing = newLimitLAM;
    }

    /**
   * @dev Changes social mining address for the tokens distribution (`newSocialMining`).
     * Can only be called by the current admin.
     */
    function setSocialMining(address newSocialMining) public virtual onlyOwner {
        emit SocialMiningChanged(socialMining, newSocialMining);
        socialMining = newSocialMining;
    }

    /**
   * @dev Changes team and development address for the tokens distribution (`newTeamAndDevelopment`).
     * Can only be called by the current admin.
     */
    function setTeamAndDevelopment(address newTeamAndDevelopment) public virtual onlyOwner {
        emit TeamAndDevelopmentChanged(teamAndDevelopment, newTeamAndDevelopment);
        teamAndDevelopment = newTeamAndDevelopment;
    }

    /**
   * @dev Changes charity address for the tokens distribution (`newCharity`).
     * Can only be called by the current admin.
     */
    function setCharity(address newCharity) public virtual onlyOwner {
        emit CharityChanged(charity, newCharity);
        charity = newCharity;
    }

    /**
   * @dev Changes liquidity and marketing address for the tokens distribution (`newLiquidityAndMarketing;`).
     * Can only be called by the current admin.
     */
    function setLiquidityAndMarketing(address newLiquidityAndMarketing) public virtual onlyOwner {
        emit LiquidityAndMarketingChanged(liquidityAndMarketing, newLiquidityAndMarketing);
        liquidityAndMarketing = newLiquidityAndMarketing;
    }


    function mint(address to, uint256 amount) public nonReentrant virtual onlyAdmin {
        uint256 secondsPassed = block.timestamp - lastMintTimestamp;
        if (secondsPassed < secondsPerDay) {
            require(minted < mintLimit, "Mint limit per day is reached");

            uint availableMint = mintLimit - minted;
            if (availableMint < amount) {
                amount = availableMint;
            }
            _mint(to, amount);
            minted = minted + amount;
        } else {
            if (mintLimit < amount) {
                amount = mintLimit;
            }
            _mint(to, amount);
            minted = amount;
            lastMintTimestamp = lastMintTimestamp + secondsPerDay;
        }
    }

    function socialMiningDistribution(uint256 socialMiningAmount) public nonReentrant virtual onlyAdmin {
        require(socialMiningAmount <= maxAmountSocialMining, "Max amount for social mining is reached");
        uint256 coefficient = (socialMiningAmount * 10 ** 18) / maxAmountSocialMining;
        uint256 teamAndDevelopmentAmount = (maxAmountTeamAndDevelopment * coefficient) / 10 ** 18;
        uint256 charityAmount = (maxAmountCharity * coefficient) / 10 ** 18;
        uint256 liquidityAndMarketingAmount = (maxAmountLiquidityAndMarketing * coefficient) / 10 ** 18;
        
        /* 
         * We need calculate total distribution and totalToBurn amount before transfer, to get information 
         * before starting burn. Else we will get situation when we trying substract from 0 totalDistributed
         * amount and getting reverted transaction
         */
        uint256 totalDistributed =
        teamAndDevelopmentAmount + charityAmount + liquidityAndMarketingAmount + socialMiningAmount;
        uint256 totalToBurn = balanceOf(_msgSender()) - totalDistributed;

        transfer(socialMining, socialMiningAmount);
        transfer(teamAndDevelopment, teamAndDevelopmentAmount);
        transfer(charity, charityAmount);
        transfer(liquidityAndMarketing, liquidityAndMarketingAmount);

        burn(totalToBurn);
        emit Distributed(totalDistributed);
    }

    // can be accessed only by owner
    function batchTransfer(address[] memory addresses, uint256[] memory amounts) public nonReentrant {
        require(addresses.length == amounts.length, 'Arrays must have the same length');
        require(addresses.length > 0, 'Arrays must have at least one element');
        for (uint256 i = 0; i < addresses.length; i++) {
            transfer(addresses[i], amounts[i]);
        }
    }
}
