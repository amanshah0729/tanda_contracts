// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Tanda} from "./Tanda.sol";
import {Test} from "forge-std/Test.sol";

// Simple mock ERC20 token for testing
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;
    uint8 public decimals = 6;
    string public name = "Mock USDC";
    string public symbol = "USDC";

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

contract TandaTest is Test {
    Tanda tanda;
    MockERC20 usdc;
    
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);
    
    uint256 constant PAYMENT_AMOUNT = 100 * 10**6; // 100 USDC.e
    uint256 constant PAYMENT_FREQUENCY = 30 days; // 30 days in seconds
    
    function setUp() public {
        // Deploy mock USDC token
        usdc = new MockERC20();
        
        // Create initial participants array
        address[] memory initialParticipants = new address[](3);
        initialParticipants[0] = alice;
        initialParticipants[1] = bob;
        initialParticipants[2] = charlie;
        
        // Deploy Tanda contract with payment amount and frequency
        tanda = new Tanda(
            address(usdc),
            initialParticipants,
            PAYMENT_AMOUNT,
            PAYMENT_FREQUENCY
        );
        
        // Give each participant enough USDC
        usdc.mint(alice, 1000 * 10**6);
        usdc.mint(bob, 1000 * 10**6);
        usdc.mint(charlie, 1000 * 10**6);
        
        // Approve Tanda to spend their USDC
        vm.prank(alice);
        usdc.approve(address(tanda), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(tanda), type(uint256).max);
        vm.prank(charlie);
        usdc.approve(address(tanda), type(uint256).max);
    }
    
    function test_InitialState() public view {
        // Check initial recipient is first participant (alice)
        require(tanda.getCurrentRecipient() == alice, "First recipient should be alice");
        require(tanda.cycleNumber() == 1, "Initial cycle should be 1");
        require(tanda.getVaultBalance() == 0, "Initial vault should be empty");
        
        // Check payment parameters
        require(tanda.paymentAmount() == PAYMENT_AMOUNT, "Payment amount should match");
        require(tanda.paymentFrequency() == PAYMENT_FREQUENCY, "Payment frequency should match");
        require(tanda.cycleStartTime() > 0, "Cycle start time should be set");
        
        // Check all participants are registered
        address[] memory participants = tanda.getParticipants();
        require(participants.length == 3, "Should have 3 participants");
        require(participants[0] == alice, "First participant should be alice");
        require(participants[1] == bob, "Second participant should be bob");
        require(participants[2] == charlie, "Third participant should be charlie");
    }
    
    function test_Pay() public {
        // Alice pays
        vm.prank(alice);
        tanda.pay();
        
        // Check Alice is marked as paid
        require(tanda.hasPaidThisCycle(alice) == true, "Alice should be marked as paid");
        require(tanda.hasPaidThisCycle(bob) == false, "Bob should not be paid");
        require(tanda.hasPaidThisCycle(charlie) == false, "Charlie should not be paid");
        
        // Check vault balance increased
        require(tanda.getVaultBalance() == tanda.paymentAmount(), "Vault should have payment amount");
        
        // Check Alice's balance decreased
        require(usdc.balanceOf(alice) == 1000 * 10**6 - tanda.paymentAmount(), "Alice balance should decrease");
    }
    
    function test_PayTwiceShouldFail() public {
        vm.prank(alice);
        tanda.pay();
        
        // Try to pay again - should fail
        vm.prank(alice);
        vm.expectRevert();
        tanda.pay();
    }
    
    function test_NonParticipantCannotPay() public {
        address stranger = address(0x999);
        usdc.mint(stranger, 1000 * 10**6);
        
        vm.prank(stranger);
        usdc.approve(address(tanda), type(uint256).max);
        
        vm.prank(stranger);
        vm.expectRevert();
        tanda.pay();
    }
    
    function test_GetUnpaidParticipants() public {
        // Initially all are unpaid
        address[] memory unpaid = tanda.getUnpaidParticipants();
        require(unpaid.length == 3, "All should be unpaid initially");
        
        // Alice pays
        vm.prank(alice);
        tanda.pay();
        
        // Check unpaid list
        unpaid = tanda.getUnpaidParticipants();
        require(unpaid.length == 2, "Should have 2 unpaid");
        require(unpaid[0] == bob || unpaid[0] == charlie, "Should contain bob or charlie");
    }
    
    function test_FullCycle() public {
        // All participants pay
        vm.prank(alice);
        tanda.pay();
        vm.prank(bob);
        tanda.pay();
        vm.prank(charlie);
        tanda.pay();
        
        // Check all have paid
        require(tanda.allHavePaid() == true, "All should have paid");
        uint256 expectedBalance = tanda.paymentAmount() * 3;
        require(tanda.getVaultBalance() == expectedBalance, "Vault should have correct balance");
        
        // Get alice balance before claim
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        uint256 cycleStartTimeBefore = tanda.cycleStartTime();
        
        // Claim (should go to alice as first recipient)
        tanda.claim();
        
        // Check alice received funds
        uint256 aliceBalanceAfter = usdc.balanceOf(alice);
        require(
            aliceBalanceAfter == aliceBalanceBefore + expectedBalance,
            "Alice should receive all vault funds"
        );
        
        // Check vault is empty
        require(tanda.getVaultBalance() == 0, "Vault should be empty after claim");
        
        // Check cycle advanced
        require(tanda.cycleNumber() == 2, "Cycle should advance to 2");
        
        // Check next recipient is bob
        require(tanda.getCurrentRecipient() == bob, "Next recipient should be bob");
        
        // Check cycle start time was reset (should equal current block timestamp)
        require(tanda.cycleStartTime() == block.timestamp, "Cycle start time should be reset to current timestamp");
        require(tanda.cycleStartTime() >= cycleStartTimeBefore, "Cycle start time should be reset");
        
        // Check all payment statuses reset
        require(tanda.hasPaidThisCycle(alice) == false, "Alice should be reset");
        require(tanda.hasPaidThisCycle(bob) == false, "Bob should be reset");
        require(tanda.hasPaidThisCycle(charlie) == false, "Charlie should be reset");
    }
    
    function test_RotationWrapsAround() public {
        // Complete first cycle - alice gets funds
        vm.prank(alice);
        tanda.pay();
        vm.prank(bob);
        tanda.pay();
        vm.prank(charlie);
        tanda.pay();
        tanda.claim();
        
        // Complete second cycle - bob gets funds
        vm.prank(alice);
        tanda.pay();
        vm.prank(bob);
        tanda.pay();
        vm.prank(charlie);
        tanda.pay();
        tanda.claim();
        
        // Check next recipient is charlie (wrapped around)
        require(tanda.getCurrentRecipient() == charlie, "Next should be charlie");
        require(tanda.cycleNumber() == 3, "Should be cycle 3");
    }
    
    function test_AddParticipant() public {
        address dave = address(0x4);
        usdc.mint(dave, 1000 * 10**6);
        
        vm.prank(dave);
        usdc.approve(address(tanda), type(uint256).max);
        
        // Add dave
        tanda.addParticipant(dave);
        
        // Check dave is now a participant
        address[] memory participants = tanda.getParticipants();
        require(participants.length == 4, "Should have 4 participants");
        require(tanda.isParticipant(dave) == true, "Dave should be a participant");
        
        // Dave can now pay
        vm.prank(dave);
        tanda.pay();
        require(tanda.hasPaidThisCycle(dave) == true, "Dave should be marked as paid");
    }
    
    function test_RemoveParticipant() public {
        // Remove bob
        tanda.removeParticipant(bob);
        
        // Check bob is removed
        address[] memory participants = tanda.getParticipants();
        require(participants.length == 2, "Should have 2 participants");
        require(tanda.isParticipant(bob) == false, "Bob should not be a participant");
        
        // Bob cannot pay anymore
        vm.prank(bob);
        vm.expectRevert();
        tanda.pay();
    }
    
    function test_RemoveParticipantWhoPaidShouldFail() public {
        // Bob pays
        vm.prank(bob);
        tanda.pay();
        
        // Try to remove bob - should fail
        vm.expectRevert();
        tanda.removeParticipant(bob);
    }
    
    function test_PaymentWindowExpires() public {
        // Alice pays
        vm.prank(alice);
        tanda.pay();
        
        // Fast forward past payment frequency window
        vm.warp(block.timestamp + tanda.paymentFrequency() + 1);
        
        // Bob tries to pay - should fail because window expired
        vm.prank(bob);
        vm.expectRevert("Payment window for this cycle has expired");
        tanda.pay();
    }
    
    function test_ClaimAfterFrequencyPeriodEvenIfNotEveryonePaid() public {
        // Only Alice pays
        vm.prank(alice);
        tanda.pay();
        
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        uint256 vaultBalance = tanda.getVaultBalance();
        
        // Fast forward past payment frequency window
        vm.warp(block.timestamp + tanda.paymentFrequency() + 1);
        
        // Claim should succeed even though not everyone paid (frequency period passed)
        tanda.claim();
        
        // Alice should receive the funds
        uint256 aliceBalanceAfter = usdc.balanceOf(alice);
        require(
            aliceBalanceAfter == aliceBalanceBefore + vaultBalance,
            "Alice should receive vault funds"
        );
        
        // Check cycle advanced
        require(tanda.cycleNumber() == 2, "Cycle should advance");
        require(tanda.getCurrentRecipient() == bob, "Next recipient should be bob");
    }
    
    function test_CycleStartTimeResetsAfterClaim() public {
        uint256 initialCycleStartTime = tanda.cycleStartTime();
        
        // All participants pay and claim
        vm.prank(alice);
        tanda.pay();
        vm.prank(bob);
        tanda.pay();
        vm.prank(charlie);
        tanda.pay();
        
        // Fast forward a bit
        vm.warp(block.timestamp + 100);
        
        tanda.claim();
        
        // Check cycle start time was reset to current block timestamp
        require(tanda.cycleStartTime() >= initialCycleStartTime + 100, "Cycle start time should reset");
        require(tanda.cycleStartTime() == block.timestamp, "Cycle start time should be current timestamp");
    }
}

