// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title CloudaxAdvisoryVestingWallet (smart contract)
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
 * - Manage the vesting schedules for advisory/partners allocated token
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
 * - Advisory/partners equity vesting
 * - Community reward distribution
 * - Partner token distribution with vesting conditions
 *
 * Roles and Authorizations:
 * - Owner: Has full control over the contract, including setting the beneficiary,
 * - initializing vesting schedules, pausing and unpausing the contract, and burning tokens.
 * - Beneficiary: Receives tokens according to the vesting schedule set by the owner.
 *
 * * Components:
 * - Contract: `CloudaxAdvisoryVestingWallet`, which extends `Ownable`, `ReentrancyGuard`, and `Pausable` to manage the vesting of tokens for the Cloudax Advisory team.
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
 * - `_releasedAmount`: The total amount of tokens that have been released so far.
 * - `_previousTotalVestingAmount`: A mapping to keep track of the cumulative total vesting amount up to each schedule.
 */

contract CloudaxAdvisoryVestingWallet is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /**
     * @notice Reased event
     * @param beneficiaryAddress address to receive the released tokens.
     * @param amount released amount of tokens
     */
    event Released(address beneficiaryAddress, uint256 amount);

    struct VestingSchedule {
        // total amount of tokens to be released at the end of the vesting
        uint256 totalAmount;
        // start time of the vesting period
        uint256 startTime;
        // duration of the vesting period in seconds
        uint256 duration;
    }
    uint256 private constant _RELEASE_TIME_UNIT = 30 days;
    uint256 private _CLIFF_PEROID;
    IERC20 private immutable _token;

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
    constructor(address token_, address initialOwner, uint256 cliffPeroid) Ownable(initialOwner) {
        require(token_ != address(0), "invalid token address");
        _token = IERC20(token_);
        // 0 for test and 6 for main deployment
        _CLIFF_PEROID = cliffPeroid * 30 days;
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
     * @notice Initializes the vesting schedule with a start time and beneficiary address.
     * @dev Only callable by the contract owner. The start time is set to the current time plus the cliff period.
     * @param beneficiary_ The address to which the vested tokens will be transferred.
     */
    function initialize(address beneficiary_) external onlyOwner {
        _startTime = block.timestamp + _CLIFF_PEROID;
        uint256 userAllocation = ((_token.totalSupply() * 5) / 100);
        uint256 RELEASE_AMOUNT_UNIT = userAllocation / 100;
        _setBeneficiaryAddress(beneficiary_);
        uint8[48] memory vestingSchedule = [
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            3,
            3,
            3,
            3
        ];
        for (uint256 i = 0; i < 48; i++) {
            _createVestingSchedule(vestingSchedule[i] * RELEASE_AMOUNT_UNIT);
        }
        _unpause();
    }

    /**
     * @notice Pauses the vesting release process.
     * @dev Only callable by the contract owner.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the vesting release process.
     * @dev Only callable by the contract owner.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Creates a new vesting schedule for a beneficiary.
     * @param amount total amount of tokens to be released at the end of the vesting
     */
    function _createVestingSchedule(uint256 amount) internal {
        uint256 scheduleId = _vestingScheduleCount;
        _vestingSchedule[scheduleId].startTime =
            _startTime +
            scheduleId *
            _RELEASE_TIME_UNIT;
        _vestingSchedule[scheduleId].duration = _RELEASE_TIME_UNIT;
        _vestingSchedule[scheduleId].totalAmount = amount;
        uint256 nextScheduleId = scheduleId + 1;
        _vestingScheduleCount = nextScheduleId;
        _previousTotalVestingAmount[nextScheduleId] =
            _previousTotalVestingAmount[scheduleId] +
            amount;
    }

    /**
     * @dev Computes the releasable amount of tokens for a vesting schedule.
     * @param currentTime current timestamp
     * @return releasable the current releasable amount
     * @return released the amount already released to the beneficiary
     * @return total the total amount of token for the beneficiary
     */
    function _computeReleasableAmount(
        uint256 currentTime
    )
        internal
        view
        returns (uint256 releasable, uint256 released, uint256 total)
    {
        require(
            currentTime >= _startTime,
            "CloudrVesting: no vesting is available now"
        );
        require(
            _vestingScheduleCount == 48,
            "CloudrVesting: vesting schedule is not set"
        );

        uint256 duration = currentTime + _startTime;
        uint256 scheduleCount = duration / _RELEASE_TIME_UNIT;
        uint256 remainTime = (duration - (_RELEASE_TIME_UNIT * scheduleCount));
        uint256 releasableAmountTotal;

        if (scheduleCount > _vestingScheduleCount) {
            releasableAmountTotal = _previousTotalVestingAmount[
                _vestingScheduleCount
            ];
        } else {
            uint256 previousVestingTotal = _previousTotalVestingAmount[
                scheduleCount
            ];
            releasableAmountTotal = (previousVestingTotal +
                ((_vestingSchedule[scheduleCount].totalAmount * remainTime) /
                    _RELEASE_TIME_UNIT));
        }

        uint256 releasableAmount = releasableAmountTotal - _releasedAmount;
        return (releasableAmount, _releasedAmount, releasableAmountTotal);
    }

    /**
     * @notice Returns the releasable amount of tokens.
     * @return _releasable the releasable amount
     */
    function getReleasableAmount() external view returns (uint256 _releasable) {
        uint256 currentTime = getCurrentTime();
        (_releasable, , ) = _computeReleasableAmount(currentTime);
    }

    /**
     * @notice Returns the token release info.
     * @return releasable the current releasable amount
     * @return released the amount already released to the beneficiary
     * @return total the total amount of token for the beneficiary
     */
    function getReleaseInfo()
        public
        view
        returns (uint256 releasable, uint256 released, uint256 total)
    {
        uint256 currentTime = getCurrentTime();
        (releasable, released, total) = _computeReleasableAmount(currentTime);
    }

    /**
     * @dev Internal function to release the releasable amount of tokens.
     * @param currentTime The current timestamp.
     * @return True if the release was successful, false otherwise.
     */
    function _release(uint256 currentTime) internal returns (bool) {
        require(
            currentTime >= _startTime,
            "CloudrVesting: vesting schedule is not initialized"
        );
        (uint256 releaseAmount, , ) = _computeReleasableAmount(currentTime);
        _token.safeTransfer(_beneficiaryAddress, releaseAmount);
        _releasedAmount = _releasedAmount + releaseAmount;
        emit Released(_beneficiaryAddress, releaseAmount);
        return true;
    }

    /**
     * @notice Release the releasable amount of tokens.
     * @return the success or failure
     */
    function release() external whenNotPaused nonReentrant returns (bool) {
        require(_release(getCurrentTime()), "CloudrVesting: release failed");
        return true;
    }

    /**
     * @notice Allows the contract owner to withdraw a specified amount of tokens when paused.
     * @dev Only callable by the contract owner when the contract is paused.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(
        uint256 amount
    ) external nonReentrant onlyOwner whenPaused {
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
     * @dev Returns the number of vesting schedules managed by this contract.
     * @return the number of vesting schedules
     */
    function getVestingSchedulesCount() external view returns (uint256) {
        return _vestingScheduleCount;
    }

    /**
     * @notice Returns the vesting schedule information for a given identifier.
     * @param scheduleId vesting schedule index: 0, 1, 2, ...
     * @return the vesting schedule structure information
     */
    function getVestingSchedule(
        uint256 scheduleId
    ) external view returns (VestingSchedule memory) {
        return _vestingSchedule[scheduleId];
    }

    /**
     * @notice Returns the release start timestamp.
     * @return the block timestamp
     */
    function getStartTime() external view returns (uint256) {
        return _startTime;
    }

    /**
     * @notice Returns the daily releasable amount of tokens for the mining pool.
     * @param currentTime current timestamp
     * @return the amount of token
     */
    function getDailyReleasableAmount(
        uint256 currentTime
    ) external view whenNotPaused returns (uint256) {
        require(
            currentTime >= _startTime,
            "CloudrVesting: no vesting is available now"
        );
        require(
            _vestingScheduleCount == 48,
            "CloudrVesting: vesting schedule is not set"
        );

        uint256 duration = currentTime - _startTime;
        uint256 scheduleCount = duration / _RELEASE_TIME_UNIT;
        if (scheduleCount > _vestingScheduleCount) return 0;
        return _vestingSchedule[scheduleCount].totalAmount / 30;
    }

    /**
     * @notice Returns the current timestamp.
     * @return the block timestamp
     */
    function getCurrentTime() public view virtual returns (uint256) {
        return block.timestamp;
    }
}
