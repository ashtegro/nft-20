// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract NFT20v1 is
    ERC20BurnableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    IERC721Upgradeable public nftContract;
    mapping(uint256 => uint256) private nftPool;
    uint256 private first;
    uint256 private last;
    uint256 public depositFee; // Percentage (100 = 1%)
    uint256 public withdrawalFee; // Percentage (100 = 1%)
    address payable public feeRecipient;
    uint8 tokenDecimals;
    bool public depositPaused;
    bool public withdrawalPaused;

    //Events

    event DepositNFT(
        address indexed user,
        uint256 indexed tokenId,
        uint256 feeAmount
    );
    event DepositNFTs(
        address indexed user,
        uint256[] tokenIds,
        uint256 feeAmount
    );
    event WithdrawNFTs(address indexed user, uint256 amount, uint256 feeAmount);
    event FeesChanged(uint256 newDepositFee, uint256 newWithdrawalFee);
    event FeeRecipientChanged(address newFeeRecipient);

    function initialize(
        address _nftContract,
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

        nftContract = IERC721Upgradeable(_nftContract);
        depositFee = _depositFee;
        withdrawalFee = _withdrawalFee;
        feeRecipient = _feeRecipient;
        tokenDecimals = _tokenDecimals;
        first = 1;
        last = 0;
        depositPaused = false;
        withdrawalPaused = false;
    }

    function depositNFT(uint256 _tokenId) external {
        require(!depositPaused, "Deposits are paused");
        require(
            nftContract.ownerOf(_tokenId) == msg.sender,
            "Not owner of NFT"
        );
        nftContract.transferFrom(msg.sender, address(this), _tokenId);
        last++;
        nftPool[last] = _tokenId;

        uint256 grossAmount = 1 * 10 ** tokenDecimals;
        uint256 feeAmount = (grossAmount * depositFee) / 10000;
        uint256 netAmount = grossAmount - feeAmount;
        _mint(msg.sender, netAmount);
        _mint(feeRecipient, feeAmount);

        emit DepositNFT(msg.sender, _tokenId, feeAmount);
    }

    function depositNFTs(uint256[] memory _tokenIds) external {
        require(!depositPaused, "Deposits are paused");
        uint256 length = _tokenIds.length;
        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = _tokenIds[i];
            require(
                nftContract.ownerOf(tokenId) == msg.sender,
                "Not owner of NFT"
            );
            nftContract.transferFrom(msg.sender, address(this), tokenId);
            last++;
            nftPool[last] = tokenId;
        }
        uint256 grossAmount = length * 10 ** tokenDecimals;
        uint256 feeAmount = (grossAmount * depositFee) / 10000;
        uint256 netAmount = grossAmount - feeAmount;
        _mint(msg.sender, netAmount);
        _mint(feeRecipient, feeAmount);

        emit DepositNFTs(msg.sender, _tokenIds, feeAmount);
    }

    function withdrawNFTs(uint256 _amount) external {
        require(!withdrawalPaused, "Withdrawals are paused");
        require(
            last >= first + _amount - 1,
            "Not enough NFTs available for withdrawal"
        );
        require(first + _amount - 1 <= last, "Amount exceeds available NFTs");

        uint256 netNFT20TokensRequired = _amount * 10 ** tokenDecimals;
        uint256 feeAmount = (netNFT20TokensRequired * withdrawalFee) / 10000;
        uint256 grossNFT20TokensRequired = netNFT20TokensRequired + feeAmount;

        require(
            balanceOf(msg.sender) >= grossNFT20TokensRequired,
            "Not enough NFT20 balance to redeem NFTs + fees"
        );

        _burn(msg.sender, grossNFT20TokensRequired);
        _mint(feeRecipient, feeAmount);

        for (uint256 i = 0; i < _amount; i++) {
            uint256 tokenId = nftPool[first];
            nftContract.transferFrom(address(this), msg.sender, tokenId);
            delete nftPool[first];
            first++;
        }

        emit WithdrawNFTs(msg.sender, _amount, feeAmount);
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
