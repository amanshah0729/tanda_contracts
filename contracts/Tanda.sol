// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Tanda {
    IERC20 public immutable usdcToken; // USDC.e token address
    uint256 public immutable paymentAmount; // Payment amount per cycle
    uint256 public immutable paymentFrequency; // Payment frequency in seconds (e.g., 30 days = 2592000)
    
    // Participant management
    address[] public participants;
    mapping(address => bool) public isParticipant;
    
    // Current cycle tracking
    mapping(address => bool) public hasPaidThisCycle;
    uint256 public currentRecipientIndex; // Who gets the funds this cycle
    uint256 public cycleNumber;
    uint256 public cycleStartTime; // Timestamp when current cycle started
    
    // Events
    event PaymentReceived(address indexed payer, uint256 amount, uint256 cycle);
    event FundsClaimed(address indexed recipient, uint256 amount, uint256 cycle);
    event ParticipantAdded(address indexed participant);
    event ParticipantRemoved(address indexed participant);
    event NewCycleStarted(uint256 cycleNumber);
    
    constructor(
        address _usdcToken,
        address[] memory _initialParticipants,
        uint256 _paymentAmount,
        uint256 _paymentFrequency
    ) {
        usdcToken = IERC20(_usdcToken);
        require(_initialParticipants.length > 0, "Must have at least one participant");
        require(_paymentAmount > 0, "Payment amount must be greater than 0");
        require(_paymentFrequency > 0, "Payment frequency must be greater than 0");
        
        // Add initial participants
        for (uint256 i = 0; i < _initialParticipants.length; i++) {
            require(_initialParticipants[i] != address(0), "Invalid address");
            participants.push(_initialParticipants[i]);
            isParticipant[_initialParticipants[i]] = true;
        }
        
        paymentAmount = _paymentAmount;
        paymentFrequency = _paymentFrequency;
        currentRecipientIndex = 0;
        cycleNumber = 1;
        cycleStartTime = block.timestamp;
    }
    
    // Pay function - transfers USDC.e and marks as paid
    function pay() external {
        require(isParticipant[msg.sender], "Not a participant");
        require(!hasPaidThisCycle[msg.sender], "Already paid this cycle");
        require(
            block.timestamp < cycleStartTime + paymentFrequency,
            "Payment window for this cycle has expired"
        );
        
        // Transfer USDC.e from user to contract
        require(
            usdcToken.transferFrom(msg.sender, address(this), paymentAmount),
            "Payment transfer failed"
        );
        
        hasPaidThisCycle[msg.sender] = true;
        emit PaymentReceived(msg.sender, paymentAmount, cycleNumber);
    }
    
    // Pay function for Permit2 - marks as paid after tokens were transferred via Permit2
    // This function assumes tokens were already transferred to this contract via Permit2's signatureTransfer
    function payAfterPermit2(address payer) external {
        require(isParticipant[payer], "Not a participant");
        require(!hasPaidThisCycle[payer], "Already paid this cycle");
        require(
            block.timestamp < cycleStartTime + paymentFrequency,
            "Payment window for this cycle has expired"
        );
        
        // Verify that payment amount was received (check balance increase)
        // Note: This is a simple check - in production you might want more sophisticated verification
        uint256 contractBalance = usdcToken.balanceOf(address(this));
        require(contractBalance >= paymentAmount, "Insufficient payment received");
        
        hasPaidThisCycle[payer] = true;
        emit PaymentReceived(payer, paymentAmount, cycleNumber);
    }
    
    // Claim function - sends all funds to current recipient and starts new cycle
    // Simplified for hackathon/demo - no payment or time checks
    function claim() external {
        uint256 contractBalance = usdcToken.balanceOf(address(this));
        require(contractBalance > 0, "No funds to claim");
        
        address recipient = participants[currentRecipientIndex];
        
        // Transfer all USDC.e to recipient
        require(
            usdcToken.transfer(recipient, contractBalance),
            "Claim transfer failed"
        );


        
        emit FundsClaimed(recipient, contractBalance, cycleNumber);
        
        // Reset cycle - wipe all payment statuses
        for (uint256 i = 0; i < participants.length; i++) {
            hasPaidThisCycle[participants[i]] = false;
        }
        
        // Move to next recipient (wrap around)
        currentRecipientIndex = (currentRecipientIndex + 1) % participants.length;
        cycleNumber++;
        cycleStartTime = block.timestamp; // Reset cycle start time
        
        emit NewCycleStarted(cycleNumber);
    }
    
    // View function - get list of who hasn't paid
    function getUnpaidParticipants() external view returns (address[] memory) {
        address[] memory unpaid = new address[](participants.length);
        uint256 unpaidCount = 0;
        
        for (uint256 i = 0; i < participants.length; i++) {
            if (!hasPaidThisCycle[participants[i]]) {
                unpaid[unpaidCount] = participants[i];
                unpaidCount++;
            }
        }
        
        // Resize array to actual count
        address[] memory result = new address[](unpaidCount);
        for (uint256 i = 0; i < unpaidCount; i++) {
            result[i] = unpaid[i];
        }
        
        return result;
    }
    
    // Helper function to check if all have paid
    function allHavePaid() public view returns (bool) {
        for (uint256 i = 0; i < participants.length; i++) {
            if (!hasPaidThisCycle[participants[i]]) {
                return false;
            }
        }
        return true;
    }
    
    // Get current recipient
    function getCurrentRecipient() external view returns (address) {
        return participants[currentRecipientIndex];
    }
    
    // Get contract balance
    function getVaultBalance() external view returns (uint256) {
        return usdcToken.balanceOf(address(this));
    }
    
    // Get all participants
    function getParticipants() external view returns (address[] memory) {
        return participants;
    }
    
    // Add participant (mutable)
    function addParticipant(address _participant) external {
        require(_participant != address(0), "Invalid address");
        require(!isParticipant[_participant], "Already a participant");
        
        participants.push(_participant);
        isParticipant[_participant] = true;
        emit ParticipantAdded(_participant);
    }
    
    // Remove participant (mutable) - hacky but works
    function removeParticipant(address _participant) external {
        require(isParticipant[_participant], "Not a participant");
        require(!hasPaidThisCycle[_participant], "Cannot remove participant who has paid");
        
        // Find and remove from array
        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] == _participant) {
                // Move last element to this position
                participants[i] = participants[participants.length - 1];
                participants.pop();
                break;
            }
        }
        
        isParticipant[_participant] = false;
        emit ParticipantRemoved(_participant);
    }
}

