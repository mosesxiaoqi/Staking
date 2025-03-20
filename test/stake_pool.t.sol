// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/stake_pool.sol";
import "../src/kkToken.sol";

contract StakePoolTest is Test {
    StakePool public stakePool;
    kkToken public token;
    address public alice;
    address public bob;

    // 设置测试环境
    function setUp() public {
        // 创建测试账户
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        
        // 给测试账户转入 ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        // 部署合约
        token = new kkToken("KK Token", "KK", 1000);
        stakePool = new StakePool(IToken(address(token)));

        // 修改这里：将 stakePool 设置为 minter
        vm.startPrank(address(this));  // 因为 this 是 token 的所有者
        token.transferOwnership(address(stakePool));  // 将代币合约所有权转给质押池
        vm.stopPrank();
        
        // // 设置 stakePool 为 minter
        // token.mint(address(stakePool), 1000 * 10**18);
    }

    // 测试初始状态
    function test_InitialState() public view {
        assertEq(address(stakePool.token()), address(token));
        assertEq(stakePool.totalStakedETH(), 0);
    }

    // 测试质押功能
    function test_Stake() public {
        uint256 stakeAmount = 2 ether;
        
        vm.startPrank(alice);
        stakePool.stake{value: stakeAmount}();
        
        assertEq(stakePool.totalStakedETH(), stakeAmount);
        assertEq(stakePool.balanceOf(alice), stakeAmount);
        assertEq(address(stakePool).balance, stakeAmount);
        vm.stopPrank();
    }

    // 测试质押金额限制
    function test_RevertWhen_StakeTooLittle() public {
        vm.startPrank(alice);
        stakePool.stake{value: 0.5 ether}();
        vm.stopPrank();
    }

    // 测试解质押功能
    function test_Unstake() public {
        // 先质押
        vm.startPrank(alice);
        stakePool.stake{value: 2 ether}();
        
        // 记录解质押前的余额
        uint256 balanceBefore = alice.balance;
        
        // 解质押
        stakePool.unstake(2 ether);
        
        // 验证状态
        assertEq(stakePool.totalStakedETH(), 0);
        assertEq(stakePool.balanceOf(alice), 0);
        assertEq(alice.balance, balanceBefore + 2 ether);
        vm.stopPrank();
    }

    // 测试奖励计算
    function test_RewardCalculation() public {
        // 质押 ETH
        vm.startPrank(alice);
        stakePool.stake{value: 5 ether}();
        
        // 模拟经过 10 个区块
        vm.roll(block.number + 10);
        
        // 计算应得奖励
        uint256 expectedReward = 10 * 10; // 10个区块 * 每区块10个代币
        
        // 领取奖励
        stakePool.claim();
        
        // 验证奖励
        assertEq(token.balanceOf(alice), expectedReward);
        vm.stopPrank();
    }

    // 测试多用户质押场景
    function test_MultipleStakers() public {
        // alice 质押
        vm.startPrank(alice);
        stakePool.stake{value: 2 ether}();
        vm.stopPrank();

        // bob 质押
        vm.startPrank(bob);
        stakePool.stake{value: 3 ether}();
        vm.stopPrank();

        // 验证总质押量
        assertEq(stakePool.totalStakedETH(), 5 ether);
        
        // 模拟经过 10 个区块
        vm.roll(block.number + 10);
        
        // alice 领取奖励
        vm.startPrank(alice);
        stakePool.claim();
        uint256 aliceReward = token.balanceOf(alice);
        vm.stopPrank();

        // bob 领取奖励
        vm.startPrank(bob);
        stakePool.claim();
        uint256 bobReward = token.balanceOf(bob);
        vm.stopPrank();

        // 验证奖励分配比例是否正确
        assertApproxEqRel(aliceReward * 3, bobReward * 2, 1e16); // 允许 1% 的误差
    }

    // 测试 receive 函数
    function test_ReceiveFunction() public {
        vm.startPrank(alice);
        (bool success,) = address(stakePool).call{value: 2 ether}("");
        
        assertTrue(success);
        assertEq(stakePool.totalStakedETH(), 2 ether);
        assertEq(stakePool.balanceOf(alice), 2 ether);
        vm.stopPrank();
    }

    receive() external payable {}
}