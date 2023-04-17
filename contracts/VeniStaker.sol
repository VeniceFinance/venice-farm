// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import './interface/IVenice.sol';

contract VeniStaker is ReentrancyGuard, Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    struct Reward {
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }
    struct Balances {
        uint256 total;
        uint256 unlocked;
        uint256 locked;
        uint256 earned;
    }
    struct LockedBalance {
        uint256 amount;
        uint256 unlockTime;
    }
    struct RewardData {
        address token;
        uint256 amount;
    }

    address public immutable stakingToken;
    address[] public rewardTokens;
    mapping(address => Reward) public rewardData;

    // Duration that rewards are streamed over
    uint256 public constant rewardsDuration = 7 days;

    // Duration of lock/earned penalty period
    uint256 public constant lockDuration = 13 weeks;

    // Addresses approved to call mint
    mapping(address => bool) public minters;
    // reward token -> distributor -> is approved to add rewards
    mapping(address=> mapping(address => bool)) public rewardDistributors;

    // user -> reward token -> amount
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;

    uint256 public totalSupply;
    uint256 public lockedSupply;

    uint256 public penaltyScale = 50;

    // Private mappings for balance data
    mapping(address => Balances) public balances;
    // 
    mapping(address => uint256) private userLocksStart;
    mapping(address => uint256) private userLocksEnd;
    mapping(address => mapping(uint256 => LockedBalance)) private userLocks;
    mapping(address => uint256) private userEarningsStart;
    mapping(address => uint256) private userEarningsEnd;
    mapping(address => mapping(uint256 => LockedBalance)) private userEarnings;

    uint256 public constant maxLockLength = 15;

    // penalty share
    uint256 public penaltyRatio;
    // treasury
    uint256 public treasuryRatio;
    uint256 public totalRatio;
    address public treasuryAddr;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _stakingToken
    ) public {
        stakingToken = _stakingToken;
        // First reward MUST be the staking token or things will break
        // related to the 50% penalty and distribution to locked balances
        rewardTokens.push(_stakingToken);
        rewardData[_stakingToken].lastUpdateTime = block.timestamp;
    }

    /* ========== ADMIN CONFIGURATION ========== */

    function setMinters(address[] calldata _minters) external onlyOwner {
        for (uint i; i < _minters.length; i++) {
            minters[_minters[i]] = true;
        }
        emit SetMinters(msg.sender, _minters);
    }

    function setTreasuryAddr(
        address _treasuryAddr
    ) external onlyOwner {
        emit SetTreasuryAddr(msg.sender, treasuryAddr, _treasuryAddr);
        treasuryAddr = _treasuryAddr;
    }

    function setRatios(
        uint256 _penaltyRatio,
        uint256 _treasuryRatio
    ) external onlyOwner {
        emit SetRatios(msg.sender, 
            penaltyRatio, _penaltyRatio, 
            treasuryRatio, _treasuryRatio
        );
        penaltyRatio = _penaltyRatio;
        treasuryRatio = _treasuryRatio;
        totalRatio = _penaltyRatio.add(_treasuryRatio);
    }

    // Add a new reward token to be distributed to stakers
    function addReward(
        address _rewardsToken,
        address _distributor
    )
        external
        onlyOwner
    {
        require(rewardData[_rewardsToken].lastUpdateTime == 0);
        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken].periodFinish = block.timestamp;
        rewardDistributors[_rewardsToken][_distributor] = true;
        emit AddReward(msg.sender, _rewardsToken, _distributor);
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != stakingToken, 'Cannot withdraw staking token');
        require(rewardData[_tokenAddress].lastUpdateTime == 0, 'Cannot withdraw reward token');
        IERC20(_tokenAddress).safeTransfer(msg.sender, _tokenAmount);
        emit Recovered(_tokenAddress, _tokenAmount);
    }

    // Modify approval for an address to call notifyRewardAmount
    function approveRewardDistributor(
        address _rewardsToken,
        address _distributor,
        bool _approved
    ) external onlyOwner {
        require(rewardData[_rewardsToken].lastUpdateTime > 0);
        rewardDistributors[_rewardsToken][_distributor] = _approved;
        emit ApproveRewardDistributor(msg.sender, _rewardsToken, _distributor, _approved);
    }

    function notifyRewardAmount(address _rewardsToken, uint256 _reward) external updateReward(address(0)) {
        require(rewardDistributors[_rewardsToken][msg.sender]);
        require(_reward > 0, 'No reward');
        // handle the transfer of reward tokens via `transferFrom` to reduce the number
        // of transactions required and ensure correctness of the reward amount
        IERC20(_rewardsToken).safeTransferFrom(msg.sender, address(this), _reward);
        _notifyReward(_rewardsToken, _reward);
        emit RewardAdded(_reward);
    }

    /* ========== VIEWS ========== */

    // rewardPerToken
    function rewardPerToken(address _rewardsToken) external view returns (uint256) {
        uint256 supply = _rewardsToken == stakingToken ? lockedSupply : totalSupply;
        return _rewardPerToken(_rewardsToken, supply);
    }

    // rewardForDuration
    function rewardForDuration(address _rewardsToken) external view returns (uint256) {
        return rewardData[_rewardsToken].rewardRate.mul(rewardsDuration);
    }

    // Address and claimable amount of all reward tokens for the given account
    function getRewards(address _account) external view returns (RewardData[] memory rewardsData) {
        rewardsData = new RewardData[](rewardTokens.length);
        for (uint256 i = 0; i < rewardsData.length; i++) {
            // If i == 0 this is the stakingReward, distribution is based on locked balances
            uint256 balance = i == 0 ? balances[_account].locked : balances[_account].total;
            uint256 supply = i == 0 ? lockedSupply : totalSupply;
            rewardsData[i].token = rewardTokens[i];
            rewardsData[i].amount = _earned(_account, rewardsData[i].token, balance, supply);
        }
    }

    // Information on the 'earned' balances of a user
    // Earned balances may be withdrawn immediately for a 50% penalty
    function getChefEarned(
        address _user
    ) external view returns (
        uint256 total,
        LockedBalance[] memory earningsData
    ) {
        uint256 idx;
        for (uint i = userEarningsStart[_user]; i < userEarningsEnd[_user]; i++) {
            if (userEarnings[_user][i].unlockTime > block.timestamp) {
                if (idx == 0) {
                    earningsData = new LockedBalance[](userEarningsEnd[_user] - i);
                }
                earningsData[idx] = userEarnings[_user][i];
                idx++;
                total = total.add(userEarnings[_user][i].amount);
            }
        }
        return (total, earningsData);
    }

    // Total withdrawable balance for an account to which no penalty is applied
    function getChefUnlocked(address _user) external view returns (uint256 amount) {
        amount = balances[_user].unlocked;
        for (uint i = userEarningsStart[_user]; i < userEarningsEnd[_user]; i++) {
            if (userEarnings[_user][i].unlockTime > block.timestamp) {
                break;
            }
            amount = amount.add(userEarnings[_user][i].amount);
        }
        return amount;
    }

    // Information on a user's locked balances
    function getStakeLocked(
        address _user
    ) external view returns (
        uint256 total,
        uint256 unlockable,
        uint256 locked,
        LockedBalance[] memory lockData
    ) {
        uint256 idx;
        for (uint i = userLocksStart[_user]; i < userLocksEnd[_user]; i++) {
            if (userLocks[_user][i].unlockTime > block.timestamp) {
                if (idx == 0) {
                    lockData = new LockedBalance[](userLocksEnd[_user] - i);
                }
                lockData[idx] = userLocks[_user][i];
                idx++;
                locked = locked.add(userLocks[_user][i].amount);
            } else {
                unlockable = unlockable.add(userLocks[_user][i].amount);
            }
        }
        return (balances[_user].locked, unlockable, locked, lockData);
    }

    // Final balance received and penalty balance paid by user upon calling exit
    function getChefLockedWithdraw(
        address _user
    ) public view returns (
        uint256 amount,
        uint256 penaltyAmount,
        uint256 treasuryAmount
    ) {
        uint256 realPenaltyAmount;
        Balances storage bal = balances[_user];
        if (bal.earned > 0) {
            uint256 amountWithoutPenalty;
            for (uint i = userEarningsStart[_user]; i < userEarningsEnd[_user]; i++) {
                uint256 earnedAmount = userEarnings[_user][i].amount;
                if (userEarnings[_user][i].unlockTime > block.timestamp) {
                    break;
                }
                amountWithoutPenalty = amountWithoutPenalty.add(earnedAmount);
            }
            // penalty
            realPenaltyAmount = penaltyAmount = bal.earned.sub(amountWithoutPenalty).mul(penaltyScale).div(100);
            if(totalRatio > 0){
                penaltyAmount = realPenaltyAmount.mul(penaltyRatio).div(totalRatio);
                treasuryAmount = realPenaltyAmount.mul(treasuryRatio).div(totalRatio);
            }
        }
        amount = bal.unlocked.add(bal.earned).sub(realPenaltyAmount);
        return (amount, penaltyAmount, treasuryAmount);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    // Stake tokens to receive rewards
    // Locked tokens cannot be withdrawn for lockDuration and are eligible to receive stakingReward rewards
    function stake(uint256 _amount, bool _lock) external nonReentrant updateReward(msg.sender) {
        require(_amount > 0, "Cannot stake 0");
        require(userLocksEnd[msg.sender] - userLocksStart[msg.sender] < maxLockLength, 'exceeding maximum length');
        totalSupply = totalSupply.add(_amount);
        Balances storage bal = balances[msg.sender];
        bal.total = bal.total.add(_amount);
        if (_lock) {
            lockedSupply = lockedSupply.add(_amount);
            bal.locked = bal.locked.add(_amount);
            uint256 unlockTime = block.timestamp.div(rewardsDuration).mul(rewardsDuration).add(lockDuration);
            uint256 idx = userLocksEnd[msg.sender];
            if (idx == 0 || userLocks[msg.sender][idx - 1].unlockTime < unlockTime) {
                userLocks[msg.sender][idx] = LockedBalance({amount: _amount, unlockTime: unlockTime});
                idx += 1;
                userLocksEnd[msg.sender] = idx;
            } else {
                userLocks[msg.sender][idx - 1].amount = userLocks[msg.sender][idx - 1].amount.add(_amount);
            }
        } else {
            bal.unlocked = bal.unlocked.add(_amount);
        }
        IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    // Withdraw all currently locked tokens where the unlock time has passed
    function withdrawExpiredLocks() external nonReentrant {
        require(userLocksEnd[msg.sender] - userLocksStart[msg.sender] > 0, 'no data');
        Balances storage bal = balances[msg.sender];
        uint256 amount;
        if (userLocks[msg.sender][userLocksEnd[msg.sender] - 1].unlockTime <= block.timestamp) {
            amount = bal.locked;
            for (uint i = userLocksStart[msg.sender]; i < userLocksEnd[msg.sender]; i++) {
                delete userLocks[msg.sender][i];
            }
            delete userLocksStart[msg.sender];
            delete userLocksEnd[msg.sender];
        } else {
            for (uint i = userLocksStart[msg.sender]; i < userLocksEnd[msg.sender]; i++) {
                if (userLocks[msg.sender][i].unlockTime > block.timestamp) break;
                amount = amount.add(userLocks[msg.sender][i].amount);
                delete userLocks[msg.sender][i];
                userLocksStart[msg.sender] = i + 1;
            }
        }
        bal.locked = bal.locked.sub(amount);
        bal.total = bal.total.sub(amount);
        totalSupply = totalSupply.sub(amount);
        lockedSupply = lockedSupply.sub(amount);
        IERC20(stakingToken).safeTransfer(msg.sender, amount);
    }

    // Mint new tokens
    // Minted tokens receive rewards normally but incur a 50% penalty when
    // withdrawn before lockDuration has passed.
    function chefStake(address _user, uint256 _amount) external updateReward(_user) {
        require(minters[msg.sender], 'not minter');
        require(userEarningsEnd[_user] - userEarningsStart[_user] < maxLockLength, 'exceeding maximum length');
        totalSupply = totalSupply.add(_amount);
        Balances storage bal = balances[_user];
        bal.total = bal.total.add(_amount);
        bal.earned = bal.earned.add(_amount);
        uint256 unlockTime = block.timestamp.div(rewardsDuration).mul(rewardsDuration).add(lockDuration);
        uint256 idx = userEarningsEnd[_user];
        if (idx == 0 || userEarnings[_user][idx - 1].unlockTime < unlockTime) {
            userEarnings[_user][idx] = LockedBalance({amount: _amount, unlockTime: unlockTime});
            idx += 1;
            userEarningsEnd[_user] = idx;
        } else {
            userEarnings[_user][idx - 1].amount = userEarnings[_user][idx - 1].amount.add(_amount);
        }
        IVenice(stakingToken).mintTo(address(this), _amount);
        emit Staked(_user, _amount);
    }

    // Withdraw staked tokens
    // First withdraws unlocked tokens, then earned tokens. Withdrawing earned tokens
    // incurs a 50% penalty which is distributed based on locked balances.
    function chefWithdraw(uint256 _amount) external nonReentrant updateReward(msg.sender) {
        require(_amount > 0, 'Cannot withdraw 0');
        Balances storage bal = balances[msg.sender];
        uint256 realPenaltyAmount;
        if (_amount <= bal.unlocked) {
            bal.unlocked = bal.unlocked.sub(_amount);
        } else {
            uint256 remaining = _amount.sub(bal.unlocked);
            require(bal.earned >= remaining, "Insufficient unlocked balance");
            bal.unlocked = 0;
            bal.earned = bal.earned.sub(remaining);
            for (uint i = userEarningsStart[msg.sender]; i < userEarningsEnd[msg.sender]; i++) {
                uint256 earnedAmount = userEarnings[msg.sender][i].amount;
                if (realPenaltyAmount == 0 && userEarnings[msg.sender][i].unlockTime > block.timestamp) {
                    realPenaltyAmount = remaining;
                    require(bal.earned >= remaining, "Insufficient balance after penalty");
                    bal.earned = bal.earned.sub(remaining);
                    if (bal.earned == 0) {
                        delete userEarningsStart[msg.sender];
                        delete userEarningsEnd[msg.sender];
                        delete userEarnings[msg.sender][i];
                        break;
                    }
                    remaining = remaining.mul(100).div(penaltyScale);
                }
                if(remaining == earnedAmount) {
                    if(i + 1 == userEarningsEnd[msg.sender]){
                        delete userEarningsStart[msg.sender];
                        delete userEarningsEnd[msg.sender];
                        delete userEarnings[msg.sender][i];
                    }else{
                        delete userEarnings[msg.sender][i];
                        userEarningsStart[msg.sender] = i + 1;
                        break;
                    }
                }else if (remaining < earnedAmount) {
                    userEarnings[msg.sender][i].amount = earnedAmount.sub(remaining);
                    break;
                } else {
                    delete userEarnings[msg.sender][i];
                    userEarningsStart[msg.sender] = i + 1;
                    remaining = remaining.sub(earnedAmount);
                }
            }
        }

        uint256 adjustedAmount = _amount.add(realPenaltyAmount);
        bal.total = bal.total.sub(adjustedAmount);
        totalSupply = totalSupply.sub(adjustedAmount);
        IERC20(stakingToken).safeTransfer(msg.sender, _amount);
        uint256 penaltyAmount = realPenaltyAmount.mul(penaltyRatio).div(totalRatio);
        uint256 treasuryAmount = realPenaltyAmount.mul(treasuryRatio).div(totalRatio);
        IERC20(stakingToken).safeTransfer(treasuryAddr, treasuryAmount);
        if (penaltyAmount > 0) {
            _notifyReward(stakingToken, penaltyAmount);
        }
        emit Withdrawn(msg.sender, _amount);
    }

    // Withdraw full unlocked balance and claim pending rewards
    function chefWithdrawAll() external updateReward(msg.sender) {
        (uint256 amount, uint256 penaltyAmount, uint256 treasuryAmount) = getChefLockedWithdraw(msg.sender);
        for (uint i = userEarningsStart[msg.sender]; i < userEarningsEnd[msg.sender]; i++) {
            delete userEarnings[msg.sender][i];
        }
        delete userEarningsStart[msg.sender];
        delete userEarningsEnd[msg.sender];
        Balances storage bal = balances[msg.sender];
        bal.total = bal.total.sub(bal.unlocked).sub(bal.earned);
        bal.unlocked = 0;
        bal.earned = 0;

        totalSupply = totalSupply.sub(amount.add(penaltyAmount).add(treasuryAmount));
        IERC20(stakingToken).safeTransfer(msg.sender, amount);
        if(treasuryAmount > 0){
            require(treasuryAddr != address(0), 'no treasury addr');
            IERC20(stakingToken).safeTransfer(treasuryAddr, treasuryAmount);
        }
        if (penaltyAmount > 0) {
            _notifyReward(stakingToken, penaltyAmount);
        }
        claimReward();
    }

    // Claim all pending staking rewards
    function claimReward() public nonReentrant updateReward(msg.sender) {
        for (uint i; i < rewardTokens.length; i++) {
            address _rewardsToken = rewardTokens[i];
            uint256 reward = rewards[msg.sender][_rewardsToken];
            if (reward > 0) {
                rewards[msg.sender][_rewardsToken] = 0;
                IERC20(_rewardsToken).safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, _rewardsToken, reward);
            }
        }
    }

    /* ========== INTERNAL ========== */

    function _lastTimeRewardApplicable(address _rewardsToken) internal view returns (uint256) {
        return Math.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

    function _rewardPerToken(address _rewardsToken, uint256 _supply) internal view returns (uint256) {
        if (_supply == 0) {
            return rewardData[_rewardsToken].rewardPerTokenStored;
        }
        return
            rewardData[_rewardsToken].rewardPerTokenStored.add(
                _lastTimeRewardApplicable(_rewardsToken).sub(
                    rewardData[_rewardsToken].lastUpdateTime).mul(
                        rewardData[_rewardsToken].rewardRate).mul(1e18).div(_supply)
            );
    }

    function _earned(
        address _user,
        address _rewardsToken,
        uint256 _balance,
        uint256 _supply
    ) internal view returns (uint256) {
        return _balance.mul(
            _rewardPerToken(_rewardsToken, _supply).sub(userRewardPerTokenPaid[_user][_rewardsToken])
        ).div(1e18).add(rewards[_user][_rewardsToken]);
    }

    function _notifyReward(address _rewardsToken, uint256 reward) internal {
        if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
            rewardData[_rewardsToken].rewardRate = reward.div(rewardsDuration);
        } else {
            uint256 remaining = rewardData[_rewardsToken].periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardData[_rewardsToken].rewardRate);
            rewardData[_rewardsToken].rewardRate = reward.add(leftover).div(rewardsDuration);
        }

        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken].periodFinish = block.timestamp.add(rewardsDuration);

    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address _account) {
        address token = stakingToken;
        uint256 balance;
        uint256 supply = lockedSupply;
        rewardData[token].rewardPerTokenStored = _rewardPerToken(token, supply);
        rewardData[token].lastUpdateTime = _lastTimeRewardApplicable(token);
        if (_account != address(0)) {
            // Special case, use the locked balances and supply for stakingReward rewards
            rewards[_account][token] = _earned(_account, token, balances[_account].locked, supply);
            userRewardPerTokenPaid[_account][token] = rewardData[token].rewardPerTokenStored;
            balance = balances[_account].total;
        }

        supply = totalSupply;
        for (uint i = 1; i < rewardTokens.length; i++) {
            token = rewardTokens[i];
            rewardData[token].rewardPerTokenStored = _rewardPerToken(token, supply);
            rewardData[token].lastUpdateTime = _lastTimeRewardApplicable(token);
            if (_account != address(0)) {
                rewards[_account][token] = _earned(_account, token, balance, supply);
                userRewardPerTokenPaid[_account][token] = rewardData[token].rewardPerTokenStored;
            }
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, address indexed rewardsToken, uint256 reward);
    event RewardsDurationUpdated(address token, uint256 newDuration);
    event Recovered(address token, uint256 amount);
    event SetMinters(address indexed user, address[] minters);
    event SetTreasuryAddr(address indexed user, address oldAddr, address newAddr);
    event SetRatios(address indexed user, 
        uint256 oldPenaltyRatio, uint256 newPenaltyRatio, 
        uint256 oldTreasuryRatio, uint256 newTreasuryRatio
    );
    event AddReward(address indexed user, address rewardsToken, address distributor);
    event ApproveRewardDistributor(address indexed user, address rewardsToken, address distributor, bool approved);
}