// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";

contract NFT201155v1 is
    ERC20BurnableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IERC1155ReceiverUpgradeable
{
    IERC1155Upgradeable public nftContract;
    uint256 public depositFee; // Percentage (100 = 1%)
    uint256 public withdrawalFee; // Percentage (100 = 1%)
    address payable public feeRecipient;
    uint8 tokenDecimals;
    bool public depositPaused;
    bool public withdrawalPaused;
    uint256 public tokenID;

    //Events

    event DepositNFT(
        address indexed user,
        uint256 indexed depositAmount,
        uint256 feeAmount
    );

    event WithdrawNFTs(address indexed user, uint256 amount, uint256 feeAmount);
    event FeesChanged(uint256 newDepositFee, uint256 newWithdrawalFee);
    event FeeRecipientChanged(address newFeeRecipient);

    function initialize(
        address _nftContract,
        uint256 _tokenID,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _depositFee,
        uint256 _withdrawalFee,
        address payable _feeRecipient,
        uint8 _tokenDecimals
    ) public initializer {
        __ERC20_init(_tokenName, _tokenSymbol);
        __Ownable_init();
        __UUPSUpgradeable_init();

        nftContract = IERC1155Upgradeable(_nftContract);
        tokenID = _tokenID;
        depositFee = _depositFee;
        withdrawalFee = _withdrawalFee;
        feeRecipient = _feeRecipient;
        tokenDecimals = _tokenDecimals;
        depositPaused = false;
        withdrawalPaused = false;
    }

    function depositNFT(uint256 _amount) external {
        require(!depositPaused, "Deposits are paused");
        nftContract.safeTransferFrom(
            msg.sender,
            address(this),
            tokenID,
            _amount,
            ""
        );

        uint256 grossAmount = _amount * 10 ** tokenDecimals;
        uint256 feeAmount = (grossAmount * depositFee) / 10000;
        uint256 netAmount = grossAmount - feeAmount;
        _mint(msg.sender, netAmount);
        _mint(feeRecipient, feeAmount);

        emit DepositNFT(msg.sender, _amount, feeAmount);
    }

    function withdrawNFTs(uint256 _amount) external {
        require(!withdrawalPaused, "Withdrawals are paused");

        uint256 netNFT20TokensRequired = _amount * 10 ** tokenDecimals;
        uint256 feeAmount = (netNFT20TokensRequired * withdrawalFee) / 10000;
        uint256 grossNFT20TokensRequired = netNFT20TokensRequired + feeAmount;

        require(
            balanceOf(msg.sender) >= grossNFT20TokensRequired,
            "Not enough NFT20 balance to redeem NFTs + fees"
        );

        _burn(msg.sender, grossNFT20TokensRequired);
        _mint(feeRecipient, feeAmount);

        nftContract.safeTransferFrom(
            address(this),
            msg.sender,
            tokenID,
            _amount,
            ""
        );

        emit WithdrawNFTs(msg.sender, _amount, feeAmount);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) public pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return
            interfaceId == type(IERC1155ReceiverUpgradeable).interfaceId ||
            interfaceId == this.onERC1155Received.selector ||
            interfaceId == this.onERC1155BatchReceived.selector;
    }

    function setFees(
        uint256 _depositFee,
        uint256 _withdrawalFee
    ) external onlyOwner {
        depositFee = _depositFee;
        withdrawalFee = _withdrawalFee;

        emit FeesChanged(_depositFee, _withdrawalFee);
    }

    function setFeeRecipient(address payable _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
        emit FeeRecipientChanged(_feeRecipient);
    }

    function decimals() public view virtual override returns (uint8) {
        return tokenDecimals;
    }

    function pauseDeposits() external onlyOwner {
        depositPaused = true;
    }

    function unpauseDeposits() external onlyOwner {
        depositPaused = false;
    }

    function pauseWithdrawals() external onlyOwner {
        withdrawalPaused = true;
    }

    function unpauseWithdrawals() external onlyOwner {
        withdrawalPaused = false;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
