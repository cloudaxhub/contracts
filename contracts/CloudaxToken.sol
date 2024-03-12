// SPDX-License-Identifier: MIT
pragma solidity  0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

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
 *   - `_update`: Checks whether the sender and receiver are blacklisted and ensures trading is enabled.
 *   - `sendTokens`: Transfers tokens from the caller to another address.
 *   - `receiveTokens`: Transfers tokens from another address to the caller.
 *   - `setBlacklisted`: Allows the owner to add or remove addresses from the blacklist.
 *   - `setupPresaleAddress`: Sets the address allowed to participate in presales.
 *   - `setTradingEnabled`: Toggles the ability to trade tokens.
 *   - `withdrawEther`: Withdraws Ether from the contract to the specified recipient.
 *   - `withdrawTokens`: Withdraws tokens from the contract to the specified recipient.
 * - State Variables:
 *   - `_isBlacklisted`: A mapping to check if an address is blacklisted.
 *   - `presaleAddress`: The address allowed to participate in presales.
 *   - `_totalSupply`: The total supply of tokens minted upon deployment.
 *   - `isTradingEnabled`: A boolean indicating if trading is enabled.
 */
contract Cloudax is ERC20, Ownable {
    using SafeERC20 for ERC20;

    mapping(address => bool) public _isBlacklisted;
    address public presaleAddress;

    uint256 private _totalSupply =  200000000 * (10**18);
    bool public isTradingEnabled = false;

    event Blacklisted(address account, bool status);

    /**
     * @dev Constructor that mints the total supply of tokens to the contract creator.
     * @param initialOwner The address of the initial owner of the contract.
     */
    constructor(address initialOwner) Ownable(initialOwner) ERC20("Cloudax", "CLDX") {
        _mint(msg.sender, _totalSupply);
    }

    /**
     * @dev Updates the state by checking if the sender and receiver are blacklisted and if trading is enabled.
     * @param from The address sending tokens.
     * @param to The address receiving tokens.
     * @param amount The amount of tokens to transfer.
     */
    function _update(address from, address to, uint256 amount) internal override {
        require(!_isBlacklisted[from] && !_isBlacklisted[to], "An address is blacklisted");
        if (from != owner() && from != presaleAddress) {
            require(isTradingEnabled, "Trading is not enabled yet");
        }
        super._update(from, to, amount);
    }

    /**
     * @notice Transfers tokens from the caller to another address.
     * @param to The address to send tokens to.
     * @param amount The amount of tokens to send.
     */
    function sendTokens(address to, uint256 amount) external {
        _update(msg.sender, to, amount);
    }

    /**
     * @notice Transfers tokens from another address to the caller.
     * @param from The address to receive tokens from.
     * @param amount The amount of tokens to receive.
     */
    function receiveTokens(address from, uint256 amount) external {
        ERC20.transferFrom(from, msg.sender, amount);
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
        require(recipient != address(0), "Can't be the zero address");
        ERC20 token = ERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        if (amount > balance) {
            amount = balance;
        }
        token.safeTransfer(recipient, amount);
    }
}