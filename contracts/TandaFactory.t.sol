// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {TandaFactory} from "./TandaFactory.sol";
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

contract TandaFactoryTest is Test {
    TandaFactory factory;
    MockERC20 usdc;
    
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);
    address dave = address(0x4);
    
    uint256 constant PAYMENT_AMOUNT = 10 * 10**6; // 10 USDC.e
    uint256 constant PAYMENT_FREQUENCY = 30 days; // 30 days in seconds
    
    function setUp() public {
        // Deploy mock USDC token
        usdc = new MockERC20();
        
        // Deploy factory with USDC token address
        factory = new TandaFactory(address(usdc));
    }
    
    function test_FactoryDeployment() public view {
        // Check factory stores USDC token address correctly
        require(factory.usdcToken() == address(usdc), "Factory should store USDC token address");
    }
    
    function test_FactoryDeploymentWithZeroAddressShouldFail() public {
        vm.expectRevert("Invalid USDC token address");
        new TandaFactory(address(0));
    }
    
    function test_CreateTanda() public {
        // Create participants array
        address[] memory participants = new address[](3);
        participants[0] = alice;
        participants[1] = bob;
        participants[2] = charlie;
        
        // Create Tanda via factory
        address tandaAddress = factory.createTanda(
            participants,
            PAYMENT_AMOUNT,
            PAYMENT_FREQUENCY
        );
        
        // Check that address is not zero
        require(tandaAddress != address(0), "Tanda address should not be zero");
        
        // Get Tanda instance
        Tanda tanda = Tanda(tandaAddress);
        
        // Verify Tanda was created with correct parameters
        require(address(tanda.usdcToken()) == address(usdc), "Tanda should use correct USDC token");
        require(tanda.paymentAmount() == PAYMENT_AMOUNT, "Tanda should have correct payment amount");
        require(tanda.paymentFrequency() == PAYMENT_FREQUENCY, "Tanda should have correct payment frequency");
        
        // Verify participants
        address[] memory tandaParticipants = tanda.getParticipants();
        require(tandaParticipants.length == 3, "Should have 3 participants");
        require(tandaParticipants[0] == alice, "First participant should be alice");
        require(tandaParticipants[1] == bob, "Second participant should be bob");
        require(tandaParticipants[2] == charlie, "Third participant should be charlie");
        
        // Verify initial state
        require(tanda.cycleNumber() == 1, "Initial cycle should be 1");
        require(tanda.getCurrentRecipient() == alice, "First recipient should be alice");
        require(tanda.getVaultBalance() == 0, "Initial vault should be empty");
    }
    
    function test_CreateMultipleTandas() public {
        // Create first Tanda
        address[] memory participants1 = new address[](2);
        participants1[0] = alice;
        participants1[1] = bob;
        
        address tanda1 = factory.createTanda(
            participants1,
            10 * 10**6,  // 10 USDC
            30 days
        );
        
        // Create second Tanda with different parameters
        address[] memory participants2 = new address[](3);
        participants2[0] = charlie;
        participants2[1] = dave;
        participants2[2] = alice;
        
        address tanda2 = factory.createTanda(
            participants2,
            50 * 10**6,  // 50 USDC
            7 days        // Weekly
        );
        
        // Verify both Tandas exist and have different addresses
        require(tanda1 != tanda2, "Tandas should have different addresses");
        require(tanda1 != address(0), "Tanda1 should not be zero");
        require(tanda2 != address(0), "Tanda2 should not be zero");
        
        // Verify Tanda1 parameters
        Tanda tanda1Instance = Tanda(tanda1);
        require(tanda1Instance.paymentAmount() == 10 * 10**6, "Tanda1 should have 10 USDC payment");
        require(tanda1Instance.paymentFrequency() == 30 days, "Tanda1 should have 30 day frequency");
        require(tanda1Instance.getParticipants().length == 2, "Tanda1 should have 2 participants");
        
        // Verify Tanda2 parameters
        Tanda tanda2Instance = Tanda(tanda2);
        require(tanda2Instance.paymentAmount() == 50 * 10**6, "Tanda2 should have 50 USDC payment");
        require(tanda2Instance.paymentFrequency() == 7 days, "Tanda2 should have 7 day frequency");
        require(tanda2Instance.getParticipants().length == 3, "Tanda2 should have 3 participants");
    }
    
    function test_CreateTandaWithZeroPaymentAmountShouldFail() public {
        address[] memory participants = new address[](2);
        participants[0] = alice;
        participants[1] = bob;
        
        // This should fail because Tanda constructor requires paymentAmount > 0
        vm.expectRevert("Payment amount must be greater than 0");
        factory.createTanda(participants, 0, PAYMENT_FREQUENCY);
    }
    
    function test_CreateTandaWithZeroPaymentFrequencyShouldFail() public {
        address[] memory participants = new address[](2);
        participants[0] = alice;
        participants[1] = bob;
        
        // This should fail because Tanda constructor requires paymentFrequency > 0
        vm.expectRevert("Payment frequency must be greater than 0");
        factory.createTanda(participants, PAYMENT_AMOUNT, 0);
    }
    
    function test_CreateTandaWithEmptyParticipantsShouldFail() public {
        address[] memory participants = new address[](0);
        
        // This should fail because Tanda constructor requires at least one participant
        vm.expectRevert("Must have at least one participant");
        factory.createTanda(participants, PAYMENT_AMOUNT, PAYMENT_FREQUENCY);
    }
    
    function test_CreateTandaWithInvalidParticipantAddressShouldFail() public {
        address[] memory participants = new address[](2);
        participants[0] = alice;
        participants[1] = address(0); // Invalid address
        
        // This should fail because Tanda constructor requires valid addresses
        vm.expectRevert("Invalid address");
        factory.createTanda(participants, PAYMENT_AMOUNT, PAYMENT_FREQUENCY);
    }
    
    function test_CreatedTandaCanReceivePayments() public {
        // Create Tanda
        address[] memory participants = new address[](2);
        participants[0] = alice;
        participants[1] = bob;
        
        address tandaAddress = factory.createTanda(
            participants,
            PAYMENT_AMOUNT,
            PAYMENT_FREQUENCY
        );
        
        Tanda tanda = Tanda(tandaAddress);
        
        // Setup: Give Alice USDC and approve
        usdc.mint(alice, 1000 * 10**6);
        vm.prank(alice);
        usdc.approve(tandaAddress, type(uint256).max);
        
        // Alice pays
        vm.prank(alice);
        tanda.pay();
        
        // Verify payment was received
        require(tanda.hasPaidThisCycle(alice) == true, "Alice should be marked as paid");
        require(tanda.getVaultBalance() == PAYMENT_AMOUNT, "Vault should have payment amount");
        require(usdc.balanceOf(alice) == 1000 * 10**6 - PAYMENT_AMOUNT, "Alice balance should decrease");
    }
    
    function test_CreateTandaWithDifferentFrequencies() public {
        // Create Tanda with monthly frequency
        address[] memory monthlyParticipants = new address[](2);
        monthlyParticipants[0] = alice;
        monthlyParticipants[1] = bob;
        
        address monthlyTanda = factory.createTanda(
            monthlyParticipants,
            PAYMENT_AMOUNT,
            30 days
        );
        
        // Create Tanda with weekly frequency
        address[] memory weeklyParticipants = new address[](2);
        weeklyParticipants[0] = charlie;
        weeklyParticipants[1] = dave;
        
        address weeklyTanda = factory.createTanda(
            weeklyParticipants,
            PAYMENT_AMOUNT,
            7 days
        );
        
        // Verify frequencies are different
        require(
            Tanda(monthlyTanda).paymentFrequency() == 30 days,
            "Monthly Tanda should have 30 day frequency"
        );
        require(
            Tanda(weeklyTanda).paymentFrequency() == 7 days,
            "Weekly Tanda should have 7 day frequency"
        );
    }
}

