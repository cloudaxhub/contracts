// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step} from "./Ownable2Step.sol";
import "./CloudaxTresuary.sol"; // Adjust the import path as necessary

/**
 * @title Cloudax Token
 * @dev Implements the Cloudax token, a custom ERC20 token with added functionalities for managing a token sale and blacklisting addresses.
 *
 * The contract includes features such as:
 * - Blacklisting addresses to prevent certain transactions.
 * - Setting up a pre-sale address to manage presales.
 * - Enabling or disabling trading.
 * - Withdrawing Ether and tokens from the contract.
 *
 * The contract follows an architectural design where the ownership of the contract is managed through the OpenZeppelin's Ownable contract.
 * The token supply is minted upon deployment and can be transferred between accounts according to the rules defined in the contract.
 *
 * Use Cases:
 * - Initial token distribution after launch.
 * - Management of token sales and presales.
 * - Prevention of fraudulent activities by blacklisting malicious addresses.
 * - Secure withdrawal of funds from the contract.
 *
 * Roles and Authorizations:
 * - Owner: Has full control over the contract, including setting blacklists, enabling trading, and withdrawing funds.
 * - Presale Address: An authorized address that can transfer tokens during the presale period.
 * - Blacklisted Addresses: Addresses that are restricted from performing certain transactions due to being blacklisted.
 *
 * Components:
 * - Contract: The main contract that extends ERC20 and Ownable to implement the token and ownership functionalities.
 * - Key Functions:
 *   - `setupTresuaryAddress`: Sets the address of the CloudaxTresuary contract.
 *   - `transfer`: Overrides the ERC20 transfer function to include blacklist checks and trading enablement checks.
 *   - `transferFrom`: Overrides the ERC20 transferFrom function to include blacklist checks and trading enablement checks.
 *   - `setBlacklisted`: Allows the owner to add or remove addresses from the blacklist.
 *   - `setupPresaleAddress`: Sets the address allowed to participate in presales.
 *   - `setTradingEnabled`: Toggles the ability to trade tokens.
 *   - `withdrawTokens`: Withdraws tokens from the contract to the specified recipient.
 * - State Variables:
 *   - `tresuary`: The address of the CloudaxTresuary contract.
 *   - `_isBlacklisted`: A mapping to check if an address is blacklisted.
 *   - `presaleAddress`: The address allowed to participate in presales.
 *   - `_totalSupply`: The total supply of tokens minted upon deployment.
 *   - `isTradingEnabled`: A boolean indicating if trading is enabled.
 */
contract Cloudax is ERC20, Ownable2Step {
    using SafeERC20 for ERC20;
    CloudaxTresuary public tresuary;
    event TreasuryUpdated(address oldAddress, address newAddress);
    event SwapCompleted(uint256 amount, address sender, address recipient);

    mapping(address => bool) public _isBlacklisted;
    address public presaleAddress;

    uint256 private _totalSupply =  200_000_000 * (10**18);
    bool public isTradingEnabled;

    error AddressIsBlacklisted();
    error TradingNotEnabled();
    error ZeroAddress();

    event Blacklisted(address account, bool status);

    /**
     * @dev Constructor that mints the total supply of tokens to the contract creator.
     */
    constructor() ERC20("Cloudax", "CLDX") {
        _mint(msg.sender, _totalSupply);
    }

    /**
     * @dev Sets the address of the CloudaxTresuary contract.
     * @param _tresuary The address of the CloudaxTresuary contract.
     */
    function setupTresuaryAddress(address _tresuary) external onlyOwner {
        CloudaxTresuary oldTresuary = tresuary;
        tresuary = CloudaxTresuary(_tresuary);
        emit TreasuryUpdated(address(oldTresuary), address(tresuary));
    }

    /**
     * @dev Overrides the ERC20 transfer function to include blacklist checks and trading enablement checks.
     * @param recipient The address to receive the tokens.
     * @param amount The amount of tokens to transfer.
     * @return true if the transfer was successful.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        if (_isBlacklisted[msg.sender] || _isBlacklisted[recipient])
            revert AddressIsBlacklisted();
        if (msg.sender != owner() && msg.sender != presaleAddress) {
            if (!isTradingEnabled) revert TradingNotEnabled();
        }
        // Check if there's a pending swap operation for the sender and amount
        (CloudaxTresuary.SwapStatus status, uint256 operationAmount) = tresuary.getSwapOperation(msg.sender);
        if (status == CloudaxTresuary.SwapStatus.Pending && operationAmount == amount) {
            // Proceed with the normal transfer
            super.transfer(recipient, amount);
            // Trigger the swap operation
            tresuary.swapCldxToEco(amount, msg.sender);
            emit SwapCompleted(amount, msg.sender, recipient);
            // Optionally, remove or update the swap operation in the tresuary contract
        } else {
            // Proceed with the normal transfer
            super.transfer(recipient, amount);
        }
        return true;
    }

    /**
     * @dev Overrides the ERC20 transferFrom function to include blacklist checks and trading enablement checks.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param value The amount of tokens to transfer.
     * @return true if the transfer was successful.
     */
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (_isBlacklisted[from] || _isBlacklisted[to])
            revert AddressIsBlacklisted();
        if (from != owner() && from != presaleAddress) {
            if (!isTradingEnabled) revert TradingNotEnabled();
        }
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        super.transferFrom(from, to, value);
        return true;
    }

    /**
     * @notice Sets the blacklist status of an address.
     * @dev Can only be called by the owner.
     * @param account The address to set the blacklist status for.
     * @param status True if the address should be blacklisted, false otherwise.
     */
    function setBlacklisted(address account, bool status) external onlyOwner {
        _isBlacklisted[account] = status;
        emit Blacklisted(account, status);
    }

    /**
     * @dev Function to set the presale address.
     * @param _presaleAddress Address associated with the presale.
     */
    function setupPresaleAddress(address _presaleAddress) external onlyOwner {
        presaleAddress = _presaleAddress;
    }

    /**
    * @notice Enables or disables the trading of tokens.
    * @dev Can only be called by the owner.
    * @param _status True if trading should be enabled, false otherwise.
    */
    function setTradingEnabled(bool _status) external onlyOwner {
        isTradingEnabled = _status;
    }

    /**
    * @notice Withdraws tokens from the contract to the specified recipient.
    * @dev Can only be called by the owner.
    * @param tokenAddress The address of the token contract.
    * @param recipient The address to receive the tokens.
    * @param amount The amount of tokens to withdraw.
    */
    function withdrawTokens(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        ERC20 token = ERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        if (amount > balance) {
            amount = balance;
        }
        token.safeTransfer(recipient, amount);
    }
}
