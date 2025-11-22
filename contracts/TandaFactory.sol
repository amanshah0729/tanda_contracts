// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./Tanda.sol";

contract TandaFactory {
    address public immutable usdcToken; // USDC.e token address (hardcoded per factory instance)
    
    event TandaCreated(address indexed tandaAddress, address indexed creator, address[] participants, uint256 paymentAmount, uint256 paymentFrequency);
    
    constructor(address _usdcToken) {
        require(_usdcToken != address(0), "Invalid USDC token address");
        usdcToken = _usdcToken;
    }
    
    /**
     * @notice Creates a new Tanda contract with specified parameters
     * @param _participants Array of participant addresses
     * @param _paymentAmount Payment amount per cycle (in USDC.e decimals, e.g., 10 * 10**6 for 10 USDC)
     * @param _paymentFrequency Payment frequency in seconds (e.g., 30 days = 2592000)
     * @return tandaAddress Address of the newly deployed Tanda contract
     */
    function createTanda(
        address[] memory _participants,
        uint256 _paymentAmount,
        uint256 _paymentFrequency
    ) external returns (address tandaAddress) {
        // Deploy new Tanda contract
        Tanda tanda = new Tanda(
            usdcToken,
            _participants,
            _paymentAmount,
            _paymentFrequency
        );
        
        tandaAddress = address(tanda);
        
        // Emit event for easy tracking
        emit TandaCreated(tandaAddress, msg.sender, _participants, _paymentAmount, _paymentFrequency);
        
        return tandaAddress;
    }
}

