// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IStaking.sol";
import "./kkToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

///实现 Stake 和 Unstake 方法，允许任何人质押ETH来赚钱 KK Token。
///其中 KK Token 是每一个区块产出 10 个，产出的 KK Token 需要根据质押时长和质押数量来公平分配


contract StakePool is IStaking {
    // 编译时常量
    uint8 public constant REWARD_PER_BLOCK = 10; // 每个区块产出10个 KK Token 数量

    // Solidity 0.8+
    uint256 constant PRECISION = 1e18;
    // 部署时常量
    IToken public immutable token;

    uint256 public totalStakedETH = 0; // 总质押的 ETH 数量
 
    uint256 private lastBlockRewardPerToken = 0; // 上一个区块的每质押代币可以分配的奖励之和
    uint256 private lastBlock = block.number; // 上一个区块号

    struct UserInfo {
        uint256 amount;  // 质押数量
        uint256 rewardPerTokenStoredAtStake; // 保存用户质押时刻区块的每质押代币可以分配的奖励之和
        uint256 settledReward; // 结算的奖励
    }
    mapping(address => UserInfo) public userInfo;

    constructor(IToken _token) {
        token = _token;
    }

    function stake()  payable external override {
        require(msg.value > 1, "stake amount must be greater than 1 ether");
        _calculateRewardPerBlock();   // 计算当前区块累积每质押代币可以分配的奖励之和
        _updateReward();              // 更新用户的奖励
        // 缓存 storage 数据到 memory
        UserInfo storage userInfo_ = userInfo[msg.sender];

        userInfo_.amount += msg.value;
        totalStakedETH += msg.value;
        userInfo_.rewardPerTokenStoredAtStake = lastBlockRewardPerToken;   // 保存用户质押时刻区块的每质押代币可以分配的奖励之和
    }

    function unstake(uint256 amount) external override {
        require(amount > 1 ether, "unstake amount must be greater than 1 ether");
        require(userInfo[msg.sender].amount >= amount, "insufficient balance");
        _calculateRewardPerBlock();
        _updateReward();
        // 缓存 storage 数据到 memory
        UserInfo storage userInfo_ = userInfo[msg.sender];
        userInfo_.amount -= amount;
        totalStakedETH -= amount;
        userInfo_.rewardPerTokenStoredAtStake = lastBlockRewardPerToken;
        // 转账ETH
        payable(msg.sender).transfer(amount);
    }

    function claim() external override {
        _calculateRewardPerBlock();
        _updateReward();
        uint256 reward = userInfo[msg.sender].settledReward;
        userInfo[msg.sender].settledReward = 0;
        userInfo[msg.sender].rewardPerTokenStoredAtStake = lastBlockRewardPerToken;
        token.mint(msg.sender, reward);
    }

    function balanceOf(address account) external view returns (uint256) {
        return userInfo[account].amount;
    }

    function earned(address account) external view returns (uint256) {
        return userInfo[account].settledReward;
    }

    function _updateReward() private {
        UserInfo storage user_info = userInfo[msg.sender];
        user_info.settledReward +=  
        user_info.amount*(lastBlockRewardPerToken - user_info.rewardPerTokenStoredAtStake)/PRECISION;
    }

    function _calculateRewardPerBlock() private {
        //获取当前区块号
        uint256 currentBlock = block.number;

        // 检查是否是同一区块
        if (currentBlock <= lastBlock) {
            return;
        }
        // 计算从上一个区块到当前区块的奖励
        uint256 rewardFromLastCheckpoint = 0;

        if (totalStakedETH == 0) {
            rewardFromLastCheckpoint = 0;
        } else {
            rewardFromLastCheckpoint = ((currentBlock - lastBlock) * REWARD_PER_BLOCK * PRECISION)/totalStakedETH;
        }
        
        // 计算当前区块的奖励
        lastBlockRewardPerToken = lastBlockRewardPerToken + rewardFromLastCheckpoint;
        
        lastBlock = currentBlock;

        return;
    }

    receive() external payable {
        require(msg.value >= 1 ether, "stake amount must be greater than 1 ether");
        _calculateRewardPerBlock();   // 计算当前区块累积每质押代币可以分配的奖励之和
        _updateReward();              // 更新用户的奖励
        // 缓存 storage 数据到 memory
        UserInfo storage userInfo_ = userInfo[msg.sender];

        userInfo_.amount += msg.value;
        totalStakedETH += msg.value;
        userInfo_.rewardPerTokenStoredAtStake = lastBlockRewardPerToken;   // 保存用户质押时刻区块的每质押代币可以分配的奖励之和
    }

}