// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable2Step } from "./Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title CloudaxTresuaryVesting (smart contract)
 * @dev The CloudaxTresuaryVesting contract is designed to manage the vesting of Cloudax (CLDX) tokens. 
 * It provides a secure and transparent mechanism for releasing tokens over time, 
 * ensuring that beneficiaries receive their tokens according to a predefined schedule. 
 * The contract also includes functionality for pausing and unpausing the release process, 
 * allowing for flexibility in managing the token release schedule.
 *
 * Architecture:
 * The contract is designed with security and transparency in mind. 
 * It utilizes OpenZeppelin's ERC20, SafeERC20, Ownable2Step, ReentrancyGuard, Pausable, and Initializable contracts to ensure secure and reliable token management. 
 * The contract includes custom errors to handle various failure conditions and events to log significant actions such as token releases and beneficiary address changes.
 *
 * Features:
 * - Token Vesting: Allows for the release of tokens over time according to a predefined schedule.
 * - Pause and Unpause: Provides the ability to pause and unpause the token release process, offering flexibility in managing the release schedule.
 * - Withdrawal: Enables the contract owner to withdraw tokens from the contract, which can be useful for managing the contract's funds.
 * - Releasable Amount Calculation: Calculates the amount of tokens that can be released at any given time, ensuring that tokens are released according to the vesting schedule.
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
 * - The contract's business logic revolves around the management of token vesting. 
 * - It includes mechanisms for setting up vesting schedules, calculating the releasable amount of tokens, and releasing tokens according to the schedule. 
 * - The contract also allows for the pausing and unpausing of the token release process, providing flexibility in managing the release schedule.
 *
 * Use Cases:
 * - Token Vesting: Users can receive their tokens over time according to a predefined schedule.
 * - Pause and Unpause: The contract owner can pause and unpause the token release process, offering flexibility in managing the release schedule.
 * - Withdrawal: The contract owner can withdraw tokens from the contract, which can be useful for managing the contract's funds.
 *
 * Roles and Authorizations:
 * - Owner: The owner of the contract has the ability to set the beneficiary address, initialize the vesting schedule, pause and unpause the token release process, and withdraw tokens from the contract.
 * - Beneficiary: The beneficiary is the address that receives the vested tokens according to the vesting schedule.
 *
 * Key Functions:
 * - initialize(uint256 months, address beneficiary_, uint256 vestingAllocation, uint8 cliffPeriod): Initializes the vesting schedule with a given duration and allocation.
 * - pause(): Pauses the vesting release process.
 * - unpause(): Unpauses the vesting release process.
 * - release(): Releases the releasable amount of tokens to the beneficiary.
 * - withdraw(uint256 amount): Withdraws the specified amount of tokens if possible.
 * - getReleasableAmount(): Retrieves the current releasable amount of tokens.
 * - getReleaseInfo(): Retrieves the token release information for the beneficiary.
 * - getWithdrawableAmount(): Returns the amount of tokens that can be withdrawn by the owner.
 * - getVestingSchedulesCount(): Returns the number of vesting schedules managed by this contract.
 * - getVestingSchedule(uint256 scheduleId): Returns the vesting schedule information for a given identifier.
 * - getStartTime(): Returns the release start timestamp.
 * - getDailyReleasableAmount(uint256 currentTime): Returns the daily releasable amount of tokens for the mining pool.
 * - getCliff(): Returns the cliff period in months.
 *
 * State Variables:
 * - _token: The ERC20 token managed by this contract.
 * - cliffPeroidinMonths: Cliff period for vesting in months.
 * - _vestingDuration: Vesting duration in months.
 * - _startTime: Start time of the contract.
 * - _beneficiaryAddress: Address of the beneficiary.
 * - _vestingSchedule: Mapping of vesting schedules.
 * - _vestingScheduleCount: Counter for vesting schedules.
 * - _releasedAmount: Total amount of released tokens.
 * - _previousTotalVestingAmount: Mapping of previous total vesting amounts.
 *
 */

contract CloudaxTresuaryVesting is
    Ownable2Step,
    ReentrancyGuard,
    Initializable,
    Pausable
{
    using SafeERC20 for ERC20;

    // Custom errors
    error InvalidTokenAddress();
    error InvalidBeneficiaryAddress();
    error VestingreleaseHasNotReached();
    error ReleaseFailed();
    error VestingScheduleNotSet();
    error InsufficientAmount();
    error InvalidMonthsValue();
    error VestingAllocationZero();

    // Structure to represent a vesting schedule
    struct VestingSchedule {
        uint256 totalAmount; // Total amount of tokens to be released at the end of the vesting
        uint256 startTime; // Start time of the vesting period
        uint256 duration; // Duration of the vesting period in seconds
    }

    // Events
    /**
     * @dev Emitted when tokens are released.
     * @param beneficiaryAddress Address to receive the released tokens.
     * @param amount Released amount of tokens.
     */
    event Released(address beneficiaryAddress, uint256 amount);

    /**
     * @dev Emitted when beneficiary address is set.
     * @param oldBeneficiaryAddress Old beneficiary address.
     * @param newBeneficiaryAddress New beneficiary address.
     */
    event BeneficiarySet(
        address oldBeneficiaryAddress,
        address newBeneficiaryAddress
    );

    /**
     * @dev Emitted when vesting is initialized.
     * @param durationInMonths Duration of the vesting period in months.
     * @param beneficiary Address of the beneficiary.
     * @param projectToken Address of the project token.
     * @param vestingAllocation Allocation for vesting.
     */
    event VestingInitialized(
        uint256 durationInMonths,
        address beneficiary,
        address projectToken,
        uint256 vestingAllocation
    );

    // Constants
    uint256 private constant _RELEASE_TIME_UNIT = 30 days; // Originally 30 days, changed to 1 minute for test purposes

    // State variables
    ERC20 private immutable _token; // The ERC20 token managed by this contract
    uint256 private cliffPeroidinMonths; // Cliff period for vesting in months
    uint256 private _vestingDuration; // vesting duration in months

    uint256 private _startTime; // Start time of the contract
    address private _beneficiaryAddress; // Address of the beneficiary
    mapping(uint256 => VestingSchedule) private _vestingSchedule; // Mapping of vesting schedules
    uint256 private _vestingScheduleCount; // Counter for vesting schedules
    uint256 private _releasedAmount; // Total amount of released tokens
    mapping(uint256 => uint256) private _previousTotalVestingAmount; // Mapping of previous total vesting amounts

    /**
     * @dev Constructor to initialize the contract.
     * @param token_ Address of the ERC20 token.
     */
    constructor(address token_) {
        if (token_ == address(0)) revert InvalidTokenAddress();
        _token = ERC20(token_);
        _pause(); // Pause the contract initially
    }

    /**
     * @notice Retrieves the ERC20 token address managed by the vesting contract.
     * @dev This function is read-only and does not modify the state.
     * @return The address of the ERC20 token contract.
     */
    function getToken() external view returns (address) {
        return address(_token);
    }

    /**
     * @notice Sets the beneficiary address for the vesting schedule.
     * @dev Only the owner can call this function.
     * @param beneficiary_ The address to set as the beneficiary.
     */
    function setBeneficiaryAddress(address beneficiary_) external onlyOwner {
        _setBeneficiaryAddress(beneficiary_);
    }

    /**
     * @dev Internal function to set the beneficiary address.
     * @param beneficiary_ New beneficiary address.
     */
    function _setBeneficiaryAddress(address beneficiary_) internal {
        if (beneficiary_ == address(0)) revert InvalidBeneficiaryAddress();
        emit BeneficiarySet(_beneficiaryAddress, beneficiary_);
        _beneficiaryAddress = beneficiary_;
    }

    /**
     * @dev Get the current beneficiary address.
     * @return Current beneficiary address.
     */
    function getBeneficiaryAddress() external view returns (address) {
        return _beneficiaryAddress;
    }

    /**
     * @notice Initializes the vesting schedule with a given duration and allocation.
     * @dev This function can only be called by the owner of the contract.
     * @param months Duration of the vesting schedule in months.
     * @param beneficiary_ Address of the beneficiary receiving the tokens.
     * @param vestingAllocation Total amount allocated for vesting.
     * @param cliffPeriod Months of the cliff period before tokens can be released.
     */
    function initialize(
        uint256 months,
        address beneficiary_,
        uint256 vestingAllocation,
        uint8 cliffPeriod
    ) external initializer onlyOwner {
        // Validate months parameter
        if (
            months != 12 &&
            months != 24 &&
            months != 36 &&
            months != 48 &&
            months != 60 &&
            months != 72 &&
            months != 84
        ) {
            revert InvalidMonthsValue();
        }

        // Validate vestingAllocation parameter
        if (vestingAllocation == 0) {
            revert VestingAllocationZero();
        }
        // set vesting duration
        _vestingDuration = months;
        //set cliff period in months
        cliffPeroidinMonths = cliffPeriod * 30 days;

        _startTime = block.timestamp + cliffPeroidinMonths;
        uint256 RELEASE_AMOUNT_UNIT = vestingAllocation / 100;
        _setBeneficiaryAddress(beneficiary_);

        // 12 months
        if (_vestingDuration == 12) {
            uint8[12] memory vestingSchedule = [
                8,
                8,
                8,
                8,
                8,
                8,
                8,
                8,
                8,
                8,
                10,
                10
            ];

            for (uint256 i = 0; i < 12; i++) {
                _createVestingSchedule(
                    vestingSchedule[i] * RELEASE_AMOUNT_UNIT
                );
            }
        }

        // 24 months
        if (_vestingDuration == 24) {
            uint8[24] memory vestingSchedule = [
                4,
                4,
                4,
                4,
                4,
                4,
                4,
                4,
                4,
                4,
                4,
                4,
                4,
                4,
                4,
                4,
                4,
                4,
                4,
                4,
                5,
                5,
                5,
                5
            ];

            for (uint256 i = 0; i < 24; i++) {
                _createVestingSchedule(
                    vestingSchedule[i] * RELEASE_AMOUNT_UNIT
                );
            }
        }

        // 36 months
        if (_vestingDuration == 36) {
            uint8[36] memory vestingSchedule = [
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
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3,
                3
            ];

            for (uint256 i = 0; i < 36; i++) {
                _createVestingSchedule(
                    vestingSchedule[i] * RELEASE_AMOUNT_UNIT
                );
            }
        }

        // 48 months
        if (_vestingDuration == 48) {
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
                _createVestingSchedule(
                    vestingSchedule[i] * RELEASE_AMOUNT_UNIT
                );
            }
        }

        // 60 months (5 years)
        if (_vestingDuration == 60) {
            uint8[60] memory vestingSchedule = [
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
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
                2,
                2,
                2,
                2,
                2,
                2
            ];

            for (uint256 i = 0; i < 60; i++) {
                _createVestingSchedule(
                    vestingSchedule[i] * RELEASE_AMOUNT_UNIT
                );
            }
        }

        // 72 months (6 years)
        if (_vestingDuration == 72) {
            uint8[72] memory vestingSchedule = [
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
                1,
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
                2
            ];

            for (uint256 i = 0; i < 72; i++) {
                _createVestingSchedule(
                    vestingSchedule[i] * RELEASE_AMOUNT_UNIT
                );
            }
        }

        // 7 years
        if (_vestingDuration == 84) {
            uint8[84] memory vestingSchedule = [
                2,
                1,
                1,
                1,
                1,
                1,
                2,
                1,
                1,
                1,
                1,
                1,
                2,
                1,
                1,
                1,
                1,
                1,
                2,
                1,
                1,
                1,
                1,
                1,
                2,
                1,
                1,
                1,
                1,
                1,
                2,
                1,
                1,
                1,
                1,
                1,
                2,
                1,
                1,
                1,
                1,
                1,
                2,
                1,
                1,
                1,
                1,
                1,
                2,
                1,
                1,
                1,
                1,
                1,
                2,
                1,
                1,
                1,
                1,
                1,
                2,
                1,
                1,
                1,
                1,
                1,
                2,
                1,
                1,
                1,
                1,
                1,
                2,
                1,
                1,
                1,
                1,
                1,
                2,
                1,
                1,
                1,
                1,
                3
            ];
            for (uint256 i = 0; i < 84; i++) {
                _createVestingSchedule(
                    vestingSchedule[i] * RELEASE_AMOUNT_UNIT
                );
            }
        }
        _unpause();
        emit VestingInitialized(
            _vestingDuration,
            beneficiary_,
            address(_token),
            vestingAllocation
        );
    }

    /**
     * @notice Pauses the vesting release process.
     * @dev Can only be called by the owner of the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the vesting release process.
     * @dev Can only be called by the owner of the contract.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Creates a new vesting schedule for a beneficiary internally.
     * @dev Called by the `initialize` function to set up vesting schedules.
     * @param amount Total amount of tokens to be released at the end of the vesting.
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
     * @notice Calculates the releasable amount of tokens for a vesting schedule.
     * @dev Used internally to determine how many tokens can be released at a given time.
     * @param currentTime Current timestamp to check against the vesting schedule.
     * @return releasable Amount of tokens that can be released.
     * @return released Amount of tokens already released.
     * @return total Total amount of tokens allocated for the beneficiary.
     */
    function _computeReleasableAmount(
        uint256 currentTime
    )
        internal
        view
        returns (uint256 releasable, uint256 released, uint256 total)
    {
        if (currentTime < _startTime) revert VestingreleaseHasNotReached();
        if (_vestingScheduleCount != _vestingDuration)
            revert VestingScheduleNotSet();

        uint256 duration = currentTime - _startTime;
        uint256 scheduleCount = duration / _RELEASE_TIME_UNIT;
        uint256 remainTime = (duration - (_RELEASE_TIME_UNIT * scheduleCount));
        uint256 releasableAmountTotal;

        if (scheduleCount >= _vestingScheduleCount) {
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
     * @notice Retrieves the current releasable amount of tokens.
     * @dev Read-only function that calculates the releasable amount based on the current time.
     * @return _releasable The current releasable amount of tokens.
     */
    function getReleasableAmount() external view returns (uint256 _releasable) {
        uint256 currentTime = block.timestamp;
        (_releasable, , ) = _computeReleasableAmount(currentTime);
    }

    /**
     * @notice Retrieves the token release information for the beneficiary.
     * @dev Read-only function that provides details on the releasable, released, and total tokens.
     * @return releasable The current releasable amount of tokens.
     * @return released The amount of tokens already released to the beneficiary.
     * @return total The total amount of tokens allocated for the beneficiary.
     */
    function getReleaseInfo()
        public
        view
        returns (uint256 releasable, uint256 released, uint256 total)
    {
        uint256 currentTime = block.timestamp;
        (releasable, released, total) = _computeReleasableAmount(currentTime);
    }

    /**
     * @notice Release the releasable amount of tokens.
     * @return The success or failure.
     */
    function _release(uint256 currentTime) internal returns (bool) {
        if (currentTime < _startTime) revert VestingreleaseHasNotReached();
        (uint256 releaseAmount, , ) = _computeReleasableAmount(currentTime);

        _releasedAmount = _releasedAmount + releaseAmount;
        emit Released(_beneficiaryAddress, releaseAmount);
        _token.safeTransfer(_beneficiaryAddress, releaseAmount);
        return true;
    }

    /**
     * @notice Releases the releasable amount of tokens to the beneficiary.
     * @dev This function can only be called by the owner and when the contract is not paused.
     * @return true if the release was successful.
     */
    function release() external whenNotPaused nonReentrant returns (bool) {
        if (!_release(block.timestamp)) revert ReleaseFailed();
        return true;
    }

    /**
     * @notice Withdraws the specified amount of tokens if possible.
     * @dev Only the owner can call this function, and the contract must be paused.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(
        uint256 amount
    ) external nonReentrant onlyOwner whenPaused {
        if (getWithdrawableAmount() < amount) revert InsufficientAmount();
        _token.safeTransfer(owner(), amount);
    }

    /**
     * @notice Returns the amount of tokens that can be withdrawn by the owner.
     * @dev This function is read-only and does not modify the state.
     * @return The amount of tokens available for withdrawal.
     */
    function getWithdrawableAmount() public view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    /**
     * @notice Returns the number of vesting schedules managed by this contract.
     * @dev This function is read-only and does not modify the state.
     * @return The number of vesting schedules.
     */
    function getVestingSchedulesCount() external view returns (uint256) {
        return _vestingScheduleCount;
    }

    /**
     * @notice Returns the vesting schedule information for a given identifier.
     * @dev This function is read-only and does not modify the state.
     * @param scheduleId Vesting schedule index: 0, 1, 2, ...
     * @return The vesting schedule structure information.
     */
    function getVestingSchedule(
        uint256 scheduleId
    ) external view returns (VestingSchedule memory) {
        return _vestingSchedule[scheduleId];
    }

    /**
     * @notice Returns the release start timestamp.
     * @dev This function is read-only and does not modify the state.
     * @return The block timestamp of the release start.
     */
    function getStartTime() external view returns (uint256) {
        return _startTime;
    }

    /**
     * @notice Returns the daily releasable amount of tokens for the mining pool.
     * @dev This function is read-only and does not modify the state.
     * @param currentTime Current timestamp to calculate the daily releasable amount.
     * @return The amount of token that can be released daily.
     */
    function getDailyReleasableAmount(
        uint256 currentTime
    ) external view whenNotPaused returns (uint256) {
        if (currentTime < _startTime) revert VestingreleaseHasNotReached();
        if (_vestingScheduleCount != _vestingDuration)
            revert VestingreleaseHasNotReached();

        uint256 duration = currentTime - _startTime;
        uint256 scheduleCount = duration / _RELEASE_TIME_UNIT;
        if (scheduleCount >= _vestingScheduleCount) return 0;
        return _vestingSchedule[scheduleCount].totalAmount / 30;
    }

    /**
     * @notice Returns the cliff period in months.
     * @dev This function is read-only and does not modify the state.
     * @return The cliff period in months.
     */
    function getCliff() public view virtual returns (uint256) {
        return cliffPeroidinMonths;
    }
}
