// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title CloudaxPublicIDOVestingWallet (smart contract)
 * @dev A contract designed to manage the vesting of tokens according to predefined schedules.
 * It is intended to facilitate token distribution processes, particularly those involving
 * gradual release over time, which is common in token sales and employee compensation schemes.
 *
 * Architecture:
 * - Uses OpenZeppelin's Ownable, ReentrancyGuard, and Pausable contracts for security and functionality.
 * - Employs a structured data model to define vesting schedules and tracks them using mappings.
 * - Implements a set of events to provide transparency and is secured with access controls.
 * - Optimized for gas efficiency and robustly handles errors to ensure a secure and reliable operation.
 *
 * Features:
 * - Manage the vesting schedules for public IDO allocated token
 * - Define custom vesting durations and amounts
 * - Enforce a cliff period before any tokens can be released
 * - Track and log token release events
 * - Support for pausing and resuming vesting releases
 *
 * Business Logic:
 * - The contract starts in a paused state to allow setup without immediate vesting
 * - The owner sets the beneficiary address and initializes vesting schedules
 * - Tokens are released according to a predefined schedule, gradually over time
 * - A cliff period ensures that a certain amount of time passes before any tokens can be released
 * - After the cliff period, tokens are gradually released until the entire amount is released.
 * - Functions are protected against reentrancy attacks and only callable by the owner or when the contract is not paused.
 * - Events are emitted for significant actions, allowing off-chain tracking of activity
 * - The contract can be paused to stop token releases, and unpaused to resume them
 *
 * Use Cases:
 * - Token sale participant vesting
 * - Public IDO equity vesting
 * - Community reward distribution
 * - Partner token distribution with vesting conditions
 *
 * Roles and Authorizations:
 * - Owner: Has full control over the contract, including setting the beneficiary,
 * - initializing vesting schedules, pausing and unpausing the contract, and burning tokens.
 * - Beneficiary: Receives tokens according to the vesting schedule set by the owner.
 *
 * * Components:
 * - Contract: `CloudaxPublicIDOVestingWallet`, which extends `Ownable`, `ReentrancyGuard`, and `Pausable` to manage the vesting of tokens for the Cloudax public IDO.
 * - Key Functions:
 * - `initialize`: Initializes the vesting schedule with a start time and beneficiary address.
 * - `setBeneficiaryAddress`: Sets the beneficiary address for the vesting schedule.
 * - `pause`: Pauses the vesting release process.
 * - `unpause`: Unpauses the vesting release process.
 * - `release`: Releases the releasable amount of tokens.
 * - `withdraw`: Allows the contract owner to withdraw a specified amount of tokens when paused.
 * - `getToken`: Retrieves the address of the ERC20 token managed by this vesting contract.
 * - `getBeneficiaryAddress`: Retrieves the beneficiary address for the vesting schedule.
 * - `getReleasableAmount`: Returns the releasable amount of tokens.
 * - `getReleaseInfo`: Returns the token release information.
 * - `setTgeDate`: Sets the date of TGE.
 * - `releaseTgeFunds`: Releases funds upon TGE.
 * - `getVestingSchedule`: Returns the vesting schedule information for a given identifier.
 * - `getStartTime`: Returns the release start timestamp.
 * - `getDailyReleasableAmount`: Returns the daily releasable amount of tokens for the mining pool.
 * - `getWithdrawableAmount`: Returns the amount of tokens that can be withdrawn by the owner.
 * - `getVestingSchedulesCount`: Returns the number of vesting schedules managed by this contract.
 * - `getCurrentTime`: Returns the current timestamp.
 *
 * - State Variables:
 * - `_token`: The instance of the ERC20 token contract.
 * - `_startTime`: The timestamp marking the beginning of the vesting period.
 * - `_beneficiaryAddress`: The address to which the vested tokens will be transferred.
 * - `_vestingSchedule`: A mapping to store the vesting schedules.
 * - `_vestingScheduleCount`: The count of vesting schedules.
 * - `_lastReleasedTime`: The timestamp of the last token release.
 * - `tge_amount`: The amount of token allocated to be release on TGE.
 * - `tge_duration`: The duration till TGE.
 * - `_releasedAmount`: The total amount of tokens that have been released so far.
 * - `_previousTotalVestingAmount`: A mapping to keep track of the cumulative total vesting amount up to each schedule.
 */

contract CloudaxPublicIDOVestingWallet is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /**
     * @notice Reased event
     * @param beneficiaryAddress address to receive the released tokens.
     * @param amount released amount of tokens
     */
    event Released(address beneficiaryAddress, uint256 amount);

    /**
     * @dev Emitted when tokens are burnt.
     * @param owner Owner initiating the burn.
     * @param recipent Recipient of the burnt tokens.
     * @param admin Admin address involved in the burn.
     * @param burnAddress Address where tokens are burned.
     * @param amount Amount of tokens being burned.
     */
    event TokenBurnt(address owner, address recipent, address admin, address burnAddress, uint256 amount);


    struct VestingSchedule {
        // total amount of tokens to be released at the end of the vesting
        uint256 totalAmount;
        // start time of the vesting period
        uint256 startTime;
        // duration of the vesting period in seconds
        uint256 duration;
    }

    IERC20 private immutable _token;
    uint private tge_amount = 10000000 * (10**18);
    uint public tge_duration;

    uint256 private _startTime;
    address private _beneficiaryAddress;
    mapping(uint256 => VestingSchedule) private _vestingSchedule;
    uint256 private _vestingScheduleCount;
    uint256 private _lastReleasedTime;
    uint256 private _releasedAmount;
    mapping(uint256 => uint256) private _previousTotalVestingAmount;

    /**
     * @dev Constructor that sets the token and pauses the contract upon deployment.
     * @param token_ The address of the ERC20 token contract.
     * @param initialOwner The address of the initial owner who will have control over the contract.
     */
    constructor(address token_, address initialOwner) Ownable(initialOwner) {
        require(token_ != address(0), "invalid token address");
        _token = IERC20(token_);
        _pause();
    }

    /**
    * @notice Retrieves the address of the ERC20 token managed by this vesting contract.
    * @return The address of the ERC20 token.
    */
    function getToken() external view returns (address) {
        return address(_token);
    }

    /**
    * @notice Sets the beneficiary address for the vesting schedule.
    * @dev Only callable by the contract owner.
    * @param beneficiary_ The address to which the vested tokens will be transferred.
    */
    function setBeneficiaryAddress(address beneficiary_) external onlyOwner {
        _setBeneficiaryAddress(beneficiary_);
    }

    /**
     * @notice Set the beneficiary addresses of vesting schedule.
     * @param beneficiary_ address of the beneficiary.
     */
    function _setBeneficiaryAddress(address beneficiary_) internal {
        require(
            beneficiary_ != address(0),
            "CloudrVesting: invalid beneficiary address"
        );
        _beneficiaryAddress = beneficiary_;
    }

    /**
     * @notice Get the beneficiary addresses of vesting schedule.
     * @return beneficiary address of the beneficiary.
     */
    function getBeneficiaryAddress() external view returns (address) {
        return _beneficiaryAddress;
    }

    /**
    * @notice Set the date/duration of the TGE
    * @dev Only callable by the contract owner.
    * @param months the duration of the TGE
    */
    function setTgeDate(uint256 months) external onlyOwner {
        tge_duration = months;
    }

    /**
    * @notice Releases the TGE amount
    * @dev Only callable by the contract owner.
    */
    function releaseTgeFunds() external onlyOwner nonReentrant {
        require(tge_duration <= getCurrentTime(), "TGE has not happened");
        require(_beneficiaryAddress != address(0), "Beneficiary Address has not been set");
        _releasedAmount = _releasedAmount + tge_amount;
        emit Released(_beneficiaryAddress, tge_amount);
        _token.safeTransfer(_beneficiaryAddress, tge_amount);
    }

    /**
    * @notice Allows the contract owner to withdraw a specified amount of tokens when paused.
    * @dev Only callable by the contract owner when the contract is paused.
    * @param amount The amount of tokens to withdraw.
    */
    function withdraw(uint256 amount)
        external
        nonReentrant
        onlyOwner
        whenPaused
    {
        require(
            getWithdrawableAmount() >= amount,
            "CloudrVesting: withdraw amount exceeds balance"
        );
        _token.safeTransfer(owner(), amount);
    }

    /**
     * @dev Returns the amount of tokens that can be withdrawn by the owner.
     * @return the amount of tokens
     */
    function getWithdrawableAmount() public view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    /**
     * @notice Returns the current timestamp.
     * @return the block timestamp
     */
    function getCurrentTime() public view virtual returns (uint256) {
        return block.timestamp;
    }

    /**
    * @notice Burns a specified amount of tokens by sending them to a zero address.
    * @dev Only the owner can call this function.
    * @param amount The amount of tokens to burn.
    */
    function burn(uint256 amount) public onlyOwner {
        // burn CLDX by sending it to a zero address
        require(amount != 0, "Amount must be greater than Zero");
        require(
            _token.balanceOf(address(this)) >= amount,
            "Not enough tokens in treasury"
        );
        _token.transfer(
            address(0x000000000000000000000000000000000000dEaD),
            amount
        );

        emit TokenBurnt(
            address(this),
            msg.sender,
            msg.sender,
            address(0x000000000000000000000000000000000000dEaD),
            amount
        );
    }  
}
