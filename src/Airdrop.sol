//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title AirDrop
 * @dev Secure contract for distributing ETH and ERC20 tokens to multiple recipients
 */
contract AirDrop is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // State variables
    uint256 private _serviceFee;
    address payable private _feeReceiver;

    // Timelock for emergency functions
    uint256 private constant EMERGENCY_TIMELOCK = 24 hours;
    uint256 private _emergencyActionTimestamp;
    address private _pendingFeeReceiver;

    // Tracking distributions in progress
    mapping(address => bool) private _tokenDistributionInProgress;

    // Events
    event ServiceFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeReceiverUpdateInitiated(address indexed currentReceiver, address indexed pendingReceiver);
    event FeeReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);
    event EtherDistributed(address indexed sender, uint256 totalAmount, uint256 recipientCount);
    event TokenDistributed(
        address indexed sender, address indexed tokenAddress, uint256 totalAmount, uint256 recipientCount
    );
    event EmergencyTokenWithdrawal(address indexed token, address indexed receiver, uint256 amount);
    event ExcessEthRefunded(address indexed receiver, uint256 amount);
    event EmergencyActionScheduled(address indexed initiator, uint256 executionTime);
    event ContractPaused(address indexed pauser);
    event ContractUnpaused(address indexed unpauser);

    /**
     * @dev Sets the contract owner and fee receiver
     * @param feeReceiver Address to receive service fees
     * @param initialServiceFee Initial service fee in wei
     */
    constructor(address payable feeReceiver, uint256 initialServiceFee) Ownable(msg.sender) {
        require(feeReceiver != address(0), "Fee receiver cannot be zero address");
        _feeReceiver = feeReceiver;
        _serviceFee = initialServiceFee;

        emit ServiceFeeUpdated(0, initialServiceFee);
        emit FeeReceiverUpdated(address(0), feeReceiver);
    }

    /**
     * @dev Validates input parameters to ensure they meet requirements
     * @param recipients Array of recipient addresses
     * @param values Array of amounts to send to each recipient
     */
    function _validateInputs(address[] calldata recipients, uint256[] calldata values) internal pure {
        require(recipients.length > 0, "Empty recipients array");
        require(recipients.length == values.length, "Length mismatch");
        require(recipients.length <= 1000, "Too many recipients");

        for (uint256 i = 0; i < recipients.length; i++) {
            require(values[i] > 0, "Zero value transfer");
            require(recipients[i] != address(0), "Invalid recipient address");
        }
    }

    /**
     * @dev Internal function to transfer service fee
     * @return bool True if fee was successfully sent
     */
    function _sendFee() internal returns (bool) {
        if (_serviceFee == 0) return true;

        (bool feeSent,) = _feeReceiver.call{value: _serviceFee}("");
        return feeSent;
    }

    /**
     * @dev Calculate total value from an array of amounts
     * @param values Array of amounts
     * @return total Total sum of all amounts
     */
    function _calculateTotal(uint256[] calldata values) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < values.length; i++) {
            total += values[i];
            // This will revert on overflow since we're using Solidity 0.8+
        }
        return total;
    }

    /**
     * @dev Distributes ETH to multiple recipients
     * @param recipients Array of recipient addresses
     * @param values Array of ETH amounts (in wei) to send to each recipient
     * @notice Total ETH sent must cover all distributions plus the service fee
     */
    function distributeEther(address[] calldata recipients, uint256[] calldata values)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        _validateInputs(recipients, values);

        uint256 totalValue = _calculateTotal(values);

        require(msg.value >= totalValue + _serviceFee, "Insufficient ETH sent");

        // Send fee first to protect against reentrancy
        bool feeSent = _sendFee();
        require(feeSent, "Failed to send fee");

        // Distribute ETH using a pull pattern to avoid reentrancy issues
        for (uint256 i = 0; i < recipients.length; i++) {
            (bool sent,) = payable(recipients[i]).call{value: values[i]}("");
            require(sent, "ETH transfer failed");
        }

        // Return excess ETH to sender
        uint256 remainingBalance = address(this).balance;
        if (remainingBalance > 0) {
            (bool refunded,) = payable(msg.sender).call{value: remainingBalance}("");
            require(refunded, "Failed to refund excess ETH");
            emit ExcessEthRefunded(msg.sender, remainingBalance);
        }

        emit EtherDistributed(msg.sender, totalValue, recipients.length);
    }

    /**
     * @dev Distributes ERC20 tokens through contract (tokens transferred to contract first)
     * @param token The ERC20 token contract address
     * @param recipients Array of recipient addresses
     * @param values Array of token amounts to send to each recipient
     */
    function distributeToken(IERC20 token, address[] calldata recipients, uint256[] calldata values)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        require(address(token) != address(0), "Invalid token address");
        _validateInputs(recipients, values);
        require(msg.value >= _serviceFee, "Insufficient fee");

        uint256 totalTokens = _calculateTotal(values);

        // Mark distribution as in progress
        _tokenDistributionInProgress[address(token)] = true;

        // Check allowance before taking fee
        require(token.allowance(msg.sender, address(this)) >= totalTokens, "Insufficient token allowance");

        // Check sender balance before taking fee
        require(token.balanceOf(msg.sender) >= totalTokens, "Insufficient token balance");

        // Send fee only after validations
        bool feeSent = _sendFee();
        require(feeSent, "Failed to send fee");

        // Transfer all tokens at once from sender to this contract
        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), totalTokens);
        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter - balanceBefore >= totalTokens, "Token transfer amount mismatch");

        // Distribute tokens to recipients
        for (uint256 i = 0; i < recipients.length; i++) {
            token.safeTransfer(recipients[i], values[i]);
        }

        // Distribution completed
        _tokenDistributionInProgress[address(token)] = false;

        // Return excess ETH to sender
        uint256 remainingBalance = address(this).balance;
        if (remainingBalance > 0) {
            (bool refunded,) = payable(msg.sender).call{value: remainingBalance}("");
            require(refunded, "Failed to refund excess ETH");
            emit ExcessEthRefunded(msg.sender, remainingBalance);
        }

        emit TokenDistributed(msg.sender, address(token), totalTokens, recipients.length);
    }

    /**
     * @dev Distributes ERC20 tokens directly from sender to recipients (more gas efficient)
     * @param token The ERC20 token contract address
     * @param recipients Array of recipient addresses
     * @param values Array of token amounts to send to each recipient
     */
    function distributeTokenSimple(IERC20 token, address[] calldata recipients, uint256[] calldata values)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        require(address(token) != address(0), "Invalid token address");
        _validateInputs(recipients, values);
        require(msg.value >= _serviceFee, "Insufficient fee");

        uint256 totalTokens = _calculateTotal(values);

        // Check allowance before taking fee
        require(token.allowance(msg.sender, address(this)) >= totalTokens, "Insufficient token allowance");

        // Check sender balance before taking fee
        require(token.balanceOf(msg.sender) >= totalTokens, "Insufficient token balance");

        // Send fee only after validations
        bool feeSent = _sendFee();
        require(feeSent, "Failed to send fee");

        // Transfer tokens directly from sender to each recipient
        for (uint256 i = 0; i < recipients.length; i++) {
            token.safeTransferFrom(msg.sender, recipients[i], values[i]);
        }

        // Return excess ETH to sender
        uint256 remainingBalance = address(this).balance;
        if (remainingBalance > 0) {
            (bool refunded,) = payable(msg.sender).call{value: remainingBalance}("");
            require(refunded, "Failed to refund excess ETH");
            emit ExcessEthRefunded(msg.sender, remainingBalance);
        }

        emit TokenDistributed(msg.sender, address(token), totalTokens, recipients.length);
    }

    /**
     * @dev Updates the service fee
     * @param newFee The new service fee amount in wei
     */
    function setServiceFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = _serviceFee;
        _serviceFee = newFee;
        emit ServiceFeeUpdated(oldFee, newFee);
    }

    /**
     * @dev Initiates the process to update fee receiver address (with timelock)
     * @param newReceiver The new fee receiver address
     */
    function initiateFeeReceiverUpdate(address payable newReceiver) external onlyOwner {
        require(newReceiver != address(0), "Fee receiver cannot be zero address");
        _pendingFeeReceiver = newReceiver;
        _emergencyActionTimestamp = block.timestamp + EMERGENCY_TIMELOCK;

        emit FeeReceiverUpdateInitiated(_feeReceiver, newReceiver);
        emit EmergencyActionScheduled(msg.sender, _emergencyActionTimestamp);
    }

    /**
     * @dev Completes the fee receiver update after timelock expires
     */
    function completeFeeReceiverUpdate() external onlyOwner {
        require(_pendingFeeReceiver != address(0), "No pending fee receiver");
        require(block.timestamp >= _emergencyActionTimestamp, "Timelock not expired");

        address oldReceiver = _feeReceiver;
        _feeReceiver = payable(_pendingFeeReceiver);
        _pendingFeeReceiver = payable(address(0));
        _emergencyActionTimestamp = 0;

        emit FeeReceiverUpdated(oldReceiver, _feeReceiver);
    }

    /**
     * @dev Emergency function to withdraw any stuck tokens in the contract
     * @param token The ERC20 token to withdraw
     * @param amount The amount to withdraw, or 0 for all
     */
    function emergencyTokenWithdrawal(IERC20 token, uint256 amount) external onlyOwner nonReentrant {
        require(address(token) != address(0), "Invalid token address");
        require(!_tokenDistributionInProgress[address(token)], "Token distribution in progress");

        uint256 tokenBalance = token.balanceOf(address(this));
        require(tokenBalance > 0, "No tokens to withdraw");

        uint256 withdrawAmount = amount == 0 ? tokenBalance : amount;
        require(withdrawAmount <= tokenBalance, "Amount exceeds balance");

        token.safeTransfer(owner(), withdrawAmount);
        emit EmergencyTokenWithdrawal(address(token), owner(), withdrawAmount);
    }

    /**
     * @dev Returns the address of the fee receiver
     * @return address Current fee receiver address
     */
    function getFeeReceiver() external view returns (address) {
        return _feeReceiver;
    }

    /**
     * @dev Returns the current service fee
     * @return uint256 Current service fee in wei
     */
    function getServiceFee() external view returns (uint256) {
        return _serviceFee;
    }

    /**
     * @dev Returns information about pending fee receiver update
     * @return pendingReceiver Address of the pending fee receiver
     * @return timestamp Timestamp when the update can be executed
     */
    function getPendingFeeReceiverUpdate() external view returns (address pendingReceiver, uint256 timestamp) {
        return (_pendingFeeReceiver, _emergencyActionTimestamp);
    }

    /**
     * @dev Pauses all distributions (emergency function)
     */
    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(msg.sender);
    }

    /**
     * @dev Unpauses the contract to resume distributions
     */
    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }

    /**
     * @dev Checks if a token distribution is in progress
     * @param token Address of the token to check
     * @return bool True if distribution is in progress
     */
    function isDistributionInProgress(address token) external view returns (bool) {
        return _tokenDistributionInProgress[token];
    }
}
