// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step} from "./Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title CloudaxTresuary (smart contract)
 * @dev The CloudaxTresuary contract is designed to manage the vesting and swapping of Cloudax (CLDX) tokens.
 * It provides a secure and transparent mechanism for token swaps between CLDX and ECO tokens,
 * ensuring that only approved wallets can perform these transactions.
 * The contract also includes functionality for burning tokens, which is crucial for maintaining the token's supply and value.
 *
 * Architecture:
 * The contract is designed with security and transparency in mind.
 * It utilizes OpenZeppelin's ERC20, SafeERC20, Ownable2Step, and ReentrancyGuard contracts to ensure secure and reliable token management.
 * The contract includes custom errors to handle various failure conditions and events to log significant actions such as token swaps and burns.
 *
 * Features:
 * - Token Swapping: Allows for the swapping of CLDX tokens for ECO tokens and vice versa, with a mechanism to burn a portion of the swapped tokens to maintain the token's supply.
 * - Token Burning: Provides a method for burning tokens, ensuring that the total supply of tokens does not exceed a certain threshold.
 * - Oracle Management: Allows the contract owner to set an oracle address, which is responsible for executing token swaps.
 * - Eco Wallet Approval: Enables the contract owner to approve or remove wallets for performing token swaps.
 * - Reentrancy Protection: Utilizes the ReentrancyGuard to prevent reentrant calls, ensuring the security of the contract.
 *
 * Business Logic:
 * The contract's business logic revolves around the management of CLDX tokens.
 * It includes mechanisms for token swapping, where a portion of the swapped tokens is burned to maintain the token's supply.
 * The contract also allows for the approval and removal of Eco wallets, ensuring that only authorized wallets can perform token swaps.
 * The contract owner has the ability to set an oracle address, which is responsible for executing these swaps
 *
 * Use Cases:
 * - Token Swapping: Users can swap CLDX tokens for ECO tokens and vice versa, with a portion of the swapped tokens being burned to maintain the token's supply.
 * - Token Burning: The contract owner can burn tokens to reduce the total supply, which can help maintain the token's value.
 * - Oracle Management: The contract owner can set an oracle address, which is responsible for executing token swaps.
 * - Eco Wallet Approval: The contract owner can approve or remove wallets for performing token swaps, ensuring that only authorized wallets can execute these transactions.
 *
 * Roles and Authorizations:
 * - Owner: The owner of the contract has the ability to set the oracle address, approve or remove Eco wallets, and burn tokens.
 * - Oracle: The oracle address is responsible for executing token swaps.
 * - Approved Eco Wallets: Wallets approved by the contract owner can perform token swaps between CLDX and ECO tokens.
 *
 * Components (Key Functions)
 * - swapCldxToEco(uint256 amount, address recipent): Swaps CLDX tokens for ECO tokens.
 * - swapEcoToCldx(uint256 amount, address recipent): Swaps ECO tokens for CLDX tokens.
 * - setOracleAddress(address _oracle): Sets the oracle address.
 * - approveEcoWallet(address wallet): Approves an Eco wallet to perform token swaps.
 * - removeEcoWallet(address wallet): Removes approval for an Eco wallet to perform token swaps.
 * - burn(uint256 amount): Burns a specified amount of tokens.
 *
 * State Variables:
 * - _token: The ERC20 token managed by this contract.
 * - ecoWallets: Counter for Eco wallets.
 * - _totalBurnt: Total amount of tokens burnt.
 * - oracle: Address of the oracle.
 * - _swappedForEco: Mapping of swapped tokens for ECO.
 * - _swappedForCldx: Mapping of swapped tokens for CLDX.
 * - ecoApprovalWallet: Mapping of Eco approval wallets.
 */

contract CloudaxTresuary is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for ERC20;

    // Custom errors
    error InvalidTokenAddress();
    error InvalidOracleAddress();
    error InsufficientTokens();
    error NotAnApprovedEcoWallet();
    error AlreadyApproved();
    error ZeroAddress();
    error InsufficientAmount();
    error UnauthorizedAddress();
    error ExceededBurnAllocation();
    error InvalidBurnPercentage();

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

    // Define the SwapInitiated event
    event SwapInitiated(address indexed sender, uint256 amount);

    // State variables
    ERC20 private immutable _token; // The ERC20 token managed by this contract
    uint256 public ecoWallets; // Counter for Eco wallets
    uint256 public _totalBurnt;
    // State variable for burn percentage
    uint8 public burnPercentage;

    address public oracle; // Address of the oracle
    enum SwapStatus { Pending, Completed }

    struct SwapOperation {
        SwapStatus status;
        uint256 amount;
    }
    mapping(address => SwapOperation) private swapOperations;
    mapping(address => uint256) public _swappedForEco; // Mapping of swapped tokens for Eco
    mapping(address => uint256) public _swappedForCldx; // Mapping of swapped tokens for CLDX
    mapping(address => bool) public ecoApprovalWallet; // Mapping of Eco approval wallets

    // Modifier to restrict function execution to the oracle address
    modifier onlyOracle() {
        if (msg.sender != oracle) revert UnauthorizedAddress();
        _;
    }

    // Modifier to restrict function execution to the token address
    modifier onlyToken() {
        if (msg.sender != address(_token)) revert UnauthorizedAddress();
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

    // Setter function for burn percentage
    function setBurnPercentage(uint8 _burnPercentage) external onlyOwner {
        if (_burnPercentage != 0 && _burnPercentage != 1 && _burnPercentage != 2 && _burnPercentage != 3 && _burnPercentage != 4 && _burnPercentage != 5) {
            revert InvalidBurnPercentage();
        }
        burnPercentage = _burnPercentage;
    }

    function initiateSwap(uint256 amount, address recipent) external onlyOracle {
        // 000000000000000000
        // Check if the sender has enough tokens to initiate the swap
        if (_token.balanceOf(recipent) < amount)
            revert InsufficientTokens();

        // Initiate the swap operation by adding an entry to the swapOperations mapping
        swapOperations[recipent] = SwapOperation({
            status: SwapStatus.Pending,
            amount: amount
        });

        // emit an event to log the initiation of the swap operation
        emit SwapInitiated(recipent, amount);
    }

    /**
     * @notice Swaps CLDX tokens for ECO tokens for approved wallets.
     * @dev This function is designed to allow authorized wallets to exchange CLDX for ECO tokens. 
     * @dev For the function to be triggered the web2 Oracle listens to blockchain for when the user (recipent) successfully sends the given "amount" of cldx to this "tresuary" contract.
     * @param amount The amount of CLDX tokens to swap.
     * @param recipent The address receiving the ECO tokens.
     */
    function swapCldxToEco(
        uint256 amount,
        address recipent
    ) external nonReentrant onlyToken {
        if (!ecoApprovalWallet[msg.sender]) revert NotAnApprovedEcoWallet();
        if (amount == 0) revert InsufficientAmount();
        if (_token.balanceOf(address(this)) < amount)
            revert InsufficientTokens();

        if (burnPercentage != 0) {
            uint256 burnAmount = (amount * burnPercentage) / 100;
            uint256 lockAmount = amount - burnAmount; // The rest to lock

            // Ensure burnPercentage not equal 0
        
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
            // The burn amount is not a tax on users, thus when the user wants to bridge (swap) back their Eco to Cldx, they get 100% of the desired swap value.
            _token.safeTransfer(
                address(0x000000000000000000000000000000000000dEaD),
                burnAmount
            );
        }else{
            
            swapOperations[recipent] = SwapOperation({
                status: SwapStatus.Completed,
                amount: amount
            });

            _swappedForEco[recipent] += amount;
            emit TokenSwap(
                recipent,
                address(this),
                msg.sender,
                amount,
                "CldxToEco"
            );
        }
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
        if (!ecoApprovalWallet[msg.sender])
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
        if (!ecoApprovalWallet[wallet]) revert NotAnApprovedEcoWallet();
        ecoApprovalWallet[wallet] = false;
        ecoWallets - 1;
        emit EcoWalletRemoved(wallet, msg.sender);
    }

    // Function to get the swap operation status and amount for a given address
    function getSwapOperation(address sender) external view returns (SwapStatus, uint256) {
        SwapOperation memory operation = swapOperations[sender];
        return (operation.status, operation.amount);
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
