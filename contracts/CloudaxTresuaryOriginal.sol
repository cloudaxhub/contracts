// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable2Step } from "./Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title CloudaxTresuary (smart contract)
 * @dev A contract designed to manage the vesting of tokens according to predefined schedules.
 * It is intended to facilitate token distribution processes, particularly those involving
 * gradual release over time, which is common in token sales and employee compensation schemes.
 * Further expanded to control the swap operations for Eco (our flagship web2 token) and CLDX our web3 token.
 *
 * Architecture:
 * - Uses OpenZeppelin's Ownable, and ReentrancyGuard contracts for security and functionality.
 * - Implements a set of events to provide transparency and is secured with access controls.
 * - Optimized for gas efficiency and robustly handles errors to ensure a secure and reliable operation.
 *
 * Features:
 * - Swap Eco to CLDX and vice versa
 *
 * Business Logic:
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
 * - Approved Wallets: Can swap tokens and are subject to the rules defined by the owner.
 *
 */

contract CloudaxTresuaryOriginal is
    Ownable2Step,
    ReentrancyGuard
{
    using SafeERC20 for ERC20;

    // Custom errors
    error InvalidTokenAddress();
    error InvalidBeneficiaryAddress();
    error InvalidOracleAddress();
    error VestingreleaseHasNotReached();
    error ReleaseFailed();
    error VestingScheduleNotSet();
    error InsufficientTokens();
    error NotAnApprovedEcoWallet();
    error AlreadyApproved();
    error ZeroAddress();
    error InsufficientAmount();
    error UnauthorizedAddress();
    error ExceededBurnAllocation();
    error InvalidMonthsValue();
    error VestingAllocationZero();


    // Events

    /**
     * @dev Emitted when oracle address is set.
     * @param oldOracleAddress Old beneficiary address.
     * @param newOracleAddress New beneficiary address.
     */
    event OracleSet(address oldOracleAddress, address newOracleAddress);

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

    // State variables
    ERC20 private immutable _token; // The ERC20 token managed by this contract
    uint256 public ecoWallets; // Counter for Eco wallets
    uint256 private _totalBurnt;

    address private oracle; // Address of the oracle
    mapping(address => uint256) public _swappedForEco; // Mapping of swapped tokens for Eco
    mapping(address => uint256) public _swappedForCldx; // Mapping of swapped tokens for CLDX
    mapping(address => bool) public ecoApprovalWallet; // Mapping of Eco approval wallets

    // Modifier to restrict function execution to the oracle address
    modifier onlyOracle() {
        if (msg.sender != oracle) revert UnauthorizedAddress();
        _;
    }
    /**
     * @dev Constructor to initialize the contract.
     * @param token_ Address of the ERC20 token.
     */
    constructor(address token_) {
        if (token_ == address(0)) revert InvalidTokenAddress();
        _token = ERC20(token_);
        oracle = msg.sender;
        _totalBurnt = 0;
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
     * @notice Swaps CLDX tokens for ECO tokens for approved wallets.
     * @dev This function is designed to allow authorized wallets to exchange CLDX for ECO tokens.
     * @param amount The amount of CLDX tokens to swap.
     * @param recipent The address receiving the ECO tokens.
     */
    function swapCldxToEco(
        uint256 amount,
        address recipent
    ) external nonReentrant onlyOracle {
        if (ecoApprovalWallet[msg.sender] == false)
            revert NotAnApprovedEcoWallet();
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
        _token.safeTransfer(
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
        if (ecoApprovalWallet[msg.sender] == false)
            revert NotAnApprovedEcoWallet();
        if (recipent == address(0)) revert ZeroAddress();
        if (amount == 0) revert InsufficientAmount();
        if (_token.balanceOf(address(this)) < amount)
            revert InsufficientTokens();
        _swappedForCldx[recipent] += amount;
        emit TokenSwap(
            address(this),
            recipent,
            msg.sender,
            amount,
            "EcoToCldx"
        );
        _token.safeTransfer(recipent, amount);
    }

    /**
     * @notice Approves an ECO wallet to perform token swaps.
     * @dev This function can only be called by the owner of the contract.
     * @param wallet The address of the wallet to be approved.
     */
    function aproveEcoWallet(address wallet) external onlyOwner {
        if (ecoApprovalWallet[wallet] == true) revert AlreadyApproved();
        ecoWallets += 1;
        ecoApprovalWallet[wallet] = true;
        emit EcoWalletAdded(wallet, msg.sender);
    }

    /**
     * @notice Removes approval for an ECO wallet to perform token swaps.
     * @dev This function can only be called by the owner of the contract.
     * @param wallet The address of the wallet to be removed.
     */
    function removeEcoWallet(address wallet) external onlyOwner {
        if (ecoApprovalWallet[wallet] == false)
            revert NotAnApprovedEcoWallet();
        ecoApprovalWallet[wallet] = false;
        ecoWallets - 1;
        emit EcoWalletRemoved(wallet, msg.sender);
    }


    /**
     * @notice Burns a specified amount of tokens by sending them to a zero address.
     * @dev Only the owner can call this function.
     * @param amount The amount of tokens to burn.
     */
    function burn(uint256 amount) public onlyOwner {
        // burn CLDX by sending it to a zero address
        if (amount == 0) revert InsufficientAmount();
        if (_token.balanceOf(address(this)) < amount)
            revert InsufficientTokens();

        // Ensure total burnt does not exceed 20% of total supply
        if (_totalBurnt + amount > (_token.totalSupply() * 20) / 100)
            revert ExceededBurnAllocation();

        _totalBurnt += amount; // Update total burnt

        emit TokenBurnt(
            msg.sender,
            msg.sender,
            address(0x000000000000000000000000000000000000dEaD),
            amount
        );

        _token.safeTransfer(
            address(0x000000000000000000000000000000000000dEaD),
            amount
        );
    }
}
