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
    
    function setUp() public {
        // Deploy mock USDC token
        usdc = new MockERC20();
        
        // Create initial participants array
        address[] memory initialParticipants = new address[](3);
        initialParticipants[0] = alice;
        initialParticipants[1] = bob;
        initialParticipants[2] = charlie;
        
        // Deploy Tanda contract
        tanda = new Tanda(address(usdc), initialParticipants);
        
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
        require(tanda.getVaultBalance() == PAYMENT_AMOUNT, "Vault should have 100 USDC");
        
        // Check Alice's balance decreased
        require(usdc.balanceOf(alice) == 900 * 10**6, "Alice should have 900 USDC left");
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
    
    function test_ClaimRequiresAllPaid() public {
        // Only Alice paid - claim should fail
        vm.prank(alice);
        tanda.pay();
        
        vm.expectRevert();
        tanda.claim();
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
        require(tanda.getVaultBalance() == PAYMENT_AMOUNT * 3, "Vault should have 300 USDC");
        
        // Get alice balance before claim
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        
        // Claim (should go to alice as first recipient)
        tanda.claim();
        
        // Check alice received funds
        uint256 aliceBalanceAfter = usdc.balanceOf(alice);
        require(
            aliceBalanceAfter == aliceBalanceBefore + (PAYMENT_AMOUNT * 3),
            "Alice should receive all vault funds"
        );
        
        // Check vault is empty
        require(tanda.getVaultBalance() == 0, "Vault should be empty after claim");
        
        // Check cycle advanced
        require(tanda.cycleNumber() == 2, "Cycle should advance to 2");
        
        // Check next recipient is bob
        require(tanda.getCurrentRecipient() == bob, "Next recipient should be bob");
        
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
}

