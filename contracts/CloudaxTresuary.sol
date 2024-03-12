// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title CloudaxTresauryVestingWallet (smart contract)
 * @dev A contract designed to manage the vesting of tokens according to predefined schedules.
 * It is intended to facilitate token distribution processes, particularly those involving
 * gradual release over time, which is common in token sales and employee compensation schemes.
 * Further expanded to control the swap operations for Eco (our flagship web2 token) and CLDX our web3 token.
 *
 * Architecture:
 * - Uses OpenZeppelin's Ownable, ReentrancyGuard, and Pausable contracts for security and functionality.
 * - Employs a structured data model to define vesting schedules and tracks them using mappings.
 * - Implements a set of events to provide transparency and is secured with access controls.
 * - Optimized for gas efficiency and robustly handles errors to ensure a secure and reliable operation.
 *
 * Features:
 * - Manage multiple vesting schedules for different beneficiaries
 * - Define custom vesting durations and amounts
 * - Enforce a cliff period before any tokens can be released
 * - Track and log token release events
 * - Support for pausing and resuming vesting releases
 * - Role-based access control for setting beneficiaries and managing wallets
 * - Swap Eco to CLDX and vice versa
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
 * - The contract holds and release CLDX token in exchange for ECO
 * - Burns CLDX to balance liquidity w.r.t Eco miniting
 *
 * Use Cases:
 * - Token sale participant vesting
 * - Employee equity vesting
 * - Community reward distribution
 * - Partner token distribution with vesting conditions
 * - Token swap
 *
 * Roles and Authorizations:
 * - Owner: Has full control over the contract, including setting the beneficiary,
 *   initializing vesting schedules, pausing and unpausing the contract, and burning tokens.
 * - Beneficiary: Receives tokens according to the vesting schedule set by the owner.
 * - Approved Wallets: Can swap tokens and are subject to the rules defined by the owner.
 *
 */

contract CloudaxTresauryVestingWallet is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for ERC20;

    error UnauthorizedAddress();
    error InvalidOracleAddress();
    error NotAnApprovedEcoWallet();
    error InsufficientAmount();
    error InsufficientTokens();
    error ExceededBurnAllocation();
    error ZeroAddress();

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
     * @dev Emitted when oracle address is set.
     * @param oldOracleAddress Old beneficiary address.
     * @param newOracleAddress New beneficiary address.
     */
    event OracleSet(address oldOracleAddress, address newOracleAddress);

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
     * @dev Emitted when a token swap occurs.
     * @param owner Owner initiating the swap.
     * @param recipent Recipient of the swapped tokens.
     * @param admin Admin address involved in the swap.
     * @param amount Amount of tokens being swapped.
     * @param assesType Type of asset being swapped.
     */
    event TokenSwap(
        address owner,
        address recipent,
        address admin,
        uint256 amount,
        string assesType
    );

    /**
     * @dev Emitted when an Eco wallet is added.
     * @param ecoWallet Added Eco wallet address.
     * @param currentContractOwner Current owner of the contract.
     */
    event EcoWalletAdded(address ecoWallet, address currentContractOwner);

    /**
     * @dev Emitted when an Eco wallet is removed.
     * @param ecoWallet Removed Eco wallet address.
     * @param currentContractOwner Current owner of the contract.
     */
    event EcoWalletRemoved(address ecoWallet, address currentContractOwner);

    /**
     * @dev Emitted when tokens are burnt.
     * @param owner Owner initiating the burn.
     * @param admin Admin address involved in the burn.
     * @param burnAddress Address where tokens are burned.
     * @param amount Amount of tokens being burned.
     */
    event TokenBurnt(
        address owner,
        address admin,
        address burnAddress,
        uint256 amount
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
    uint256 public ecoWallets; // Counter for Eco wallets
    uint256 private cliffPeroidinMonths; // Cliff period for vesting in months
    uint256 private _vestingDuration; // vesting duration in months
    uint256 private _totalBurnt;

    uint256 private _startTime; // Start time of the contract
    address private _beneficiaryAddress; // Address of the beneficiary
    address private oracle; // Address of the oracle
    mapping(uint256 => VestingSchedule) private _vestingSchedule; // Mapping of vesting schedules
    uint256 private _vestingScheduleCount; // Counter for vesting schedules
    uint256 private _lastReleasedTime; // Last time tokens were released
    uint256 private _releasedAmount; // Total amount of released tokens
    mapping(uint256 => uint256) private _previousTotalVestingAmount; // Mapping of previous total vesting amounts
    mapping(address => uint256) public _swappedForEco; // Mapping of swapped tokens for Eco
    mapping(address => uint256) public _swappedForCldx; // Mapping of swapped tokens for CLDX
    mapping(address => uint256) public ecoApprovalWallet; // Mapping of Eco approval wallets

    // Modifier to restrict function execution to the oracle address
    modifier onlyOracle() {
        if (msg.sender != oracle) revert UnauthorizedAddress();
        _;
    }
    /**
     * @dev Constructor to initialize the contract.
     * @param token_ Address of the ERC20 token.
     * @param initialOwner Address of the initial owner of the contract.
     */
    constructor(address token_, address initialOwner) Ownable(initialOwner) {
        require(token_ != address(0), "invalid token address");
        _token = ERC20(token_);
        oracle = msg.sender;
        _totalBurnt = 0;
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
        require(
            beneficiary_ != address(0),
            "CloudrVesting: invalid beneficiary address"
        );
        emit BeneficiarySet(_beneficiaryAddress, beneficiary_);
        _beneficiaryAddress = beneficiary_;
    }

    /**
     * @notice Sets the oracle address.
     * @dev Only the owner can call this function.
     * @param _oracle The address to set as the oracle address.
     */
    function setOracleAddress(address _oracle) external onlyOwner {
        if (_oracle == address(0)) revert InvalidOracleAddress();
        emit OracleSet(oracle, _oracle);
        oracle = _oracle;
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
    ) external onlyOwner {
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
        require(
            currentTime >= _startTime,
            "CloudrVesting: no vesting is available now"
        );
        require(
            _vestingScheduleCount == _vestingDuration,
            "CloudrVesting: vesting schedule is not set"
        );

        uint256 duration = currentTime - _startTime;
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
     * @notice Retrieves the current releasable amount of tokens.
     * @dev Read-only function that calculates the releasable amount based on the current time.
     * @return _releasable The current releasable amount of tokens.
     */
    function getReleasableAmount() external view returns (uint256 _releasable) {
        uint256 currentTime = getCurrentTime();
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
        uint256 currentTime = getCurrentTime();
        (releasable, released, total) = _computeReleasableAmount(currentTime);
    }

    /**
     * @notice Release the releasable amount of tokens.
     * @return The success or failure.
     */
    function _release(uint256 currentTime) internal returns (bool) {
        require(
            currentTime >= _startTime,
            "CloudrVesting: vesting schedule is not initialized"
        );
        (uint256 releaseAmount, , ) = _computeReleasableAmount(currentTime);
        _token.transfer(_beneficiaryAddress, releaseAmount);
        _releasedAmount = _releasedAmount + releaseAmount;
        emit Released(_beneficiaryAddress, releaseAmount);
        return true;
    }

    /**
     * @notice Releases the releasable amount of tokens to the beneficiary.
     * @dev This function can only be called by the owner and when the contract is not paused.
     * @return true if the release was successful.
     */
    function release() external whenNotPaused nonReentrant returns (bool) {
        require(_release(getCurrentTime()), "CloudrVesting: release failed");
        return true;
    }

    /**
     * @notice Swaps CLDX tokens for ECO tokens for approved wallets.
     * @dev This function is designed to allow authorized wallets to exchange CLDX for ECO tokens.
     * @param amount The amount of CLDX tokens to swap.
     * @param recipent The address receiving the ECO tokens.
     */
    function swapCldxToEco(
        uint256 amount,
        address recipent
    ) external nonReentrant onlyOracle {
        if (ecoApprovalWallet[msg.sender] == 0) revert NotAnApprovedEcoWallet();
        if (amount == 0) revert InsufficientAmount();
        if (_token.balanceOf(address(this)) < amount)
            revert InsufficientTokens();

        uint256 burnAmount = (amount * 20) / 100; // 20% of the amount to burn
        uint256 lockAmount = amount - burnAmount; // The rest to lock

        // Ensure total burnt does not exceed 20% of total supply
        if (_totalBurnt + burnAmount > (_token.totalSupply() * 20) / 100)
            revert ExceededBurnAllocation();

        _totalBurnt += burnAmount; // Update total burnt
        _swappedForEco[recipent] += lockAmount; // Lock the rest
        emit TokenSwap(
            recipent,
            address(this),
            msg.sender,
            lockAmount,
            "CldxToEco"
        );
        emit TokenBurnt(
            recipent,
            msg.sender,
            address(0x000000000000000000000000000000000000dEaD),
            burnAmount
        );
        _token.transfer(
            address(0x000000000000000000000000000000000000dEaD),
            burnAmount
        );
    }

    /**
     * @notice Swaps ECO tokens for CLDX tokens for approved wallets.
     * @dev This function is designed to allow authorized wallets to exchange ECO for CLDX tokens.
     * @param amount The amount of ECO tokens to swap.
     * @param recipent The address receiving the CLDX tokens.
     */
    function swapEcoToCldx(
        uint256 amount,
        address recipent
    ) external nonReentrant onlyOracle {
        if(ecoApprovalWallet[msg.sender] == 0) revert NotAnApprovedEcoWallet();
        if(recipent == address(0)) revert ZeroAddress();
        if (amount == 0) revert InsufficientAmount();
        if(_token.balanceOf(address(this)) < amount) revert InsufficientTokens();
        _swappedForCldx[recipent] += amount;
        emit TokenSwap(
            address(this),
            recipent,
            msg.sender,
            amount,
            "EcoToCldx"
        );
        _token.transfer(recipent, amount);
    }

    /**
     * @notice Approves an ECO wallet to perform token swaps.
     * @dev This function can only be called by the owner of the contract.
     * @param wallet The address of the wallet to be approved.
     */
    function aproveEcoWallet(address wallet) external onlyOwner {
        require(
            ecoApprovalWallet[wallet] == 0,
            "This wallet is already an approved EcoWallet"
        );
        ecoWallets += 1;
        ecoApprovalWallet[wallet] = 1;
        emit EcoWalletAdded(wallet, msg.sender);
    }

    /**
     * @notice Removes approval for an ECO wallet to perform token swaps.
     * @dev This function can only be called by the owner of the contract.
     * @param wallet The address of the wallet to be removed.
     */
    function removeEcoWallet(address wallet) external onlyOwner {
        require(
            ecoApprovalWallet[wallet] != 0,
            "This wallet is not an approved EcoWallet"
        );
        ecoApprovalWallet[wallet] = 0;
        emit EcoWalletRemoved(wallet, msg.sender);
    }

    /**
     * @notice Withdraws the specified amount of tokens if possible.
     * @dev Only the owner can call this function, and the contract must be paused.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(
        uint256 amount
    ) external nonReentrant onlyOwner whenPaused {
        require(
            getWithdrawableAmount() >= amount,
            "CloudrVesting: withdraw amount exceeds balance"
        );
        _token.transfer(owner(), amount);
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
        require(
            currentTime >= _startTime,
            "CloudrVesting: no vesting is available now"
        );
        require(
            _vestingScheduleCount == _vestingDuration,
            "CloudrVesting: vesting schedule is not set"
        );

        uint256 duration = currentTime - _startTime;
        uint256 scheduleCount = duration / _RELEASE_TIME_UNIT;
        if (scheduleCount > _vestingScheduleCount) return 0;
        return _vestingSchedule[scheduleCount].totalAmount / 30;
    }

    /**
     * @notice Returns the current timestamp.
     * @dev This function is read-only and does not modify the state.
     * @return The block timestamp of the current time.
     */
    function getCurrentTime() public view virtual returns (uint256) {
        return block.timestamp;
    }

    /**
     * @notice Returns the cliff period in months.
     * @dev This function is read-only and does not modify the state.
     * @return The cliff period in months.
     */
    function getCliff() public view virtual returns (uint256) {
        return cliffPeroidinMonths;
    }

    /**
     * @notice Burns a specified amount of tokens by sending them to a zero address.
     * @dev Only the owner can call this function.
     * @param amount The amount of tokens to burn.
     */
    function burn(uint256 amount) public onlyOwner {
        // burn CLDX by sending it to a zero address
        if(amount == 0) revert InsufficientAmount();
        if(_token.balanceOf(address(this)) < amount) revert InsufficientTokens();

        // Ensure total burnt does not exceed 20% of total supply
        if(_totalBurnt + amount > (_token.totalSupply() * 20) / 100) revert ExceededBurnAllocation();

        _totalBurnt += amount; // Update total burnt

        _token.transfer(
            address(0x000000000000000000000000000000000000dEaD),
            amount
        );

        emit TokenBurnt(
            msg.sender,
            msg.sender,
            address(0x000000000000000000000000000000000000dEaD),
            amount
        );
    }
}
