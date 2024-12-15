// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.4;

// import "hardhat/console.sol";
// import "./DN404Mirror.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/token/common/ERC2981.sol";
// import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
// import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "contract-allow-list/contracts/proxy/interface/IContractAllowListProxy.sol";

// /**
//  * @title ExtendedDN404Mirror
//  * @dev Extends DN404Mirror with ERC721C capabilities and maintains CAL functionality
//  */
// contract MUTANT_ALIENS_VILLAIN is
//     DN404Mirror,
//     AccessControl,
//     ERC2981,
//     ReentrancyGuard
// {
//     using EnumerableSet for EnumerableSet.AddressSet;
//     using ECDSA for bytes32;

//     // === State Variables ===
//     IContractAllowListProxy public CAL;
//     EnumerableSet.AddressSet private localAllowedAddresses;

//     // Roles
//     bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
//     bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

//     // Seaport v1.6 hooks interface
//     bytes4 private constant _SEAPORT_HOOK_INTERFACE = 0x9059e6c3;

//     bytes4 private constant INTERFACE_ID_ERC721C = 0x3f4ce757;
//     bytes4 private constant INTERFACE_ID_CONTRACT_LEVEL = 0xa40eb359;

//     // Security Levels (Combined DN404 CAL and ERC721C security)
//     enum SecurityLevel {
//         NONE, // No restrictions
//         CAL_ONLY, // Only CAL restrictions
//         ROYALTY_ONLY, // Only royalty restrictions
//         FULL // Both CAL and royalty restrictions
//     }

//     // State Variables
//     SecurityLevel public securityLevel = SecurityLevel.FULL;
//     bool public enableRestrict = true;
//     uint256 public CALLevel = 2;
//     bool public contractLocked = false;

//     // Mappings
//     mapping(address => bool) public approvedMarketplaces;
//     mapping(address => uint256) public marketplaceFees;
//     mapping(uint256 => bool) public tokenLocked;
//     mapping(address => bool) public walletLocked;
//     mapping(uint256 => SecurityLevel) public tokenSecurityLevels;
//     mapping(uint256 => address) public tokenMarketplaces;
//     mapping(uint256 => uint256) public tokenCALLevel;
//     mapping(address => uint256) public walletCALLevel;

//     // Events
//     event RoyaltyPaid(
//         address indexed tokenContract,
//         uint256 indexed tokenId,
//         address indexed royaltyReceiver,
//         address seller,
//         address buyer,
//         uint256 amount
//     );
//     event SecurityLevelChanged(uint256 indexed tokenId, SecurityLevel level);
//     event MarketplaceApproved(
//         address indexed marketplace,
//         bool approved,
//         uint256 fee
//     );
//     event TokenMarketplaceSet(
//         uint256 indexed tokenId,
//         address indexed marketplace
//     );
//     event OwnershipSynced(address indexed oldOwner, address indexed newOwner);
//     event RoyaltyEnforced(
//         uint256 tokenId,
//         address receiver,
//         uint96 feeNumerator
//     );
//     event CreatorEarningsConfigured(address receiver, uint96 feeNumerator);
//     event ApprovalAttempt(
//         address indexed owner,
//         address indexed spender,
//         uint256 indexed tokenId,
//         bool success,
//         string reason
//     );
//     event SetApprovalForAllAttempt(
//         address indexed owner,
//         address indexed operator,
//         bool approved,
//         bool success,
//         string reason
//     );
//     event TransferAttempt(
//         address indexed from,
//         address indexed to,
//         uint256 indexed tokenId,
//         bool success,
//         string reason
//     );
//     event SafeTransferAttempt(
//         address indexed from,
//         address indexed to,
//         uint256 indexed tokenId,
//         bytes data,
//         bool success,
//         string reason
//     );
//     event LocalCalAdded(address indexed operator, address indexed transferer);
//     event LocalCalRemoved(address indexed operator, address indexed transferer);

//     event ContractLevelUpdated(uint256 newLevel);
//     event TokenLevelUpdated(uint256 indexed tokenId, uint256 newLevel);

//     // === Constructor ===
//     constructor(
//         address deployer,
//         address _cal,
//         address defaultRoyaltyReceiver,
//         uint96 defaultRoyaltyFeeNumerator
//     ) DN404Mirror(deployer) {
//         console.log("Deploying ExtendedDN404Mirror with deployer:", deployer);
//         _grantRole(DEFAULT_ADMIN_ROLE, deployer);
//         _grantRole(ADMIN_ROLE, deployer);
//         _grantRole(MINTER_ROLE, deployer);

//         securityLevel = SecurityLevel.FULL;

//         _setDefaultRoyalty(defaultRoyaltyReceiver, defaultRoyaltyFeeNumerator);
//         CAL = IContractAllowListProxy(_cal);

//         enableRestrict = true;
//     }

//     // === Lock Management ===
//     function lockContract() external onlyRole(ADMIN_ROLE) {
//         contractLocked = true;
//     }

//     function unlockContract() external onlyRole(ADMIN_ROLE) {
//         contractLocked = false;
//     }

//     function lockWallet(address wallet) external onlyRole(ADMIN_ROLE) {
//         walletLocked[wallet] = true;
//     }

//     function unlockWallet(address wallet) external onlyRole(ADMIN_ROLE) {
//         walletLocked[wallet] = false;
//     }

//     function lockToken(uint256 tokenId) external onlyRole(ADMIN_ROLE) {
//         tokenLocked[tokenId] = true;
//     }

//     function unlockToken(uint256 tokenId) external onlyRole(ADMIN_ROLE) {
//         tokenLocked[tokenId] = false;
//     }

//     function isLocked(
//         address wallet,
//         uint256 tokenId
//     ) public view returns (bool) {
//         return contractLocked || walletLocked[wallet] || tokenLocked[tokenId];
//     }

//     // === CAL Management ===
//     function setCAL(address _cal) external onlyRole(ADMIN_ROLE) {
//         CAL = IContractAllowListProxy(_cal);
//     }

//     function setCALLevel(uint256 level) external onlyRole(ADMIN_ROLE) {
//         require(level <= 2, "Invalid level");
//         CALLevel = level;
//     }

//     function addLocalContractAllowList(
//         address transferer
//     ) external onlyRole(ADMIN_ROLE) {
//         localAllowedAddresses.add(transferer);
//         emit LocalCalAdded(msg.sender, transferer);
//     }

//     function removeLocalContractAllowList(
//         address transferer
//     ) external onlyRole(ADMIN_ROLE) {
//         localAllowedAddresses.remove(transferer);
//         emit LocalCalRemoved(msg.sender, transferer);
//     }

//     function getLocalContractAllowList()
//         external
//         view
//         returns (address[] memory)
//     {
//         return localAllowedAddresses.values();
//     }

//     function setTokenCALLevel(uint256 tokenId, uint256 level) external {
//         require(ownerOf(tokenId) == msg.sender, "Not token owner");
//         require(level <= 2, "Invalid level");
//         tokenCALLevel[tokenId] = level;
//         emit SecurityLevelChanged(
//             tokenId,
//             level == 0 ? SecurityLevel.NONE : SecurityLevel.CAL_ONLY
//         );
//     }

//     function setWalletCALLevel(uint256 level) external {
//         walletCALLevel[msg.sender] = level;
//     }

//     function _getCALLevel(
//         address holder,
//         uint256 tokenId
//     ) internal view returns (uint256) {
//         if (tokenCALLevel[tokenId] > 0) {
//             return tokenCALLevel[tokenId];
//         }
//         if (walletCALLevel[holder] > 0) {
//             return walletCALLevel[holder];
//         }
//         return CALLevel;
//     }

//     // セキュリティレベル変更の制限
//     function setSecurityLevel(
//         SecurityLevel newLevel
//     ) external onlyRole(ADMIN_ROLE) {
//         require(
//             newLevel == SecurityLevel.FULL ||
//                 newLevel == SecurityLevel.ROYALTY_ONLY,
//             "Only FULL or ROYALTY_ONLY allowed"
//         );
//         securityLevel = newLevel;
//     }

//     function setDefaultRoyalty(
//         address receiver,
//         uint96 feeNumerator
//     ) public onlyRole(ADMIN_ROLE) {
//         require(feeNumerator > 0, "Royalty must be greater than 0");
//         _setDefaultRoyalty(receiver, feeNumerator);
//     }

//     // === Allow List Checks ===
//     function _isAllowed(
//         address operator,
//         address tokenOwner
//     ) internal view returns (bool) {
//         if (!enableRestrict) return true;
//         if (operator == tokenOwner) return true;
//         uint256 level = _getCALLevel(tokenOwner, 0);
//         return
//             localAllowedAddresses.contains(operator) ||
//             CAL.isAllowed(operator, level);
//     }

//     function checkIsAllowed(
//         address operator,
//         address tokenOwner
//     ) public view returns (bool) {
//         return _isAllowed(operator, tokenOwner);
//     }

//     // === Transfer Management ===
//     function setApprovalForAll(
//         address operator,
//         bool approved
//     ) public virtual override {
//         require(_isAllowed(operator, msg.sender), "Operator not allowed");
//         super.setApprovalForAll(operator, approved);
//         emit SetApprovalForAllAttempt(msg.sender, operator, approved, true, "");
//     }

//     function approve(
//         address spender,
//         uint256 id
//     ) public payable virtual override {
//         address owner = ownerOf(id);
//         require(_isAllowed(spender, owner), "Spender not allowed");
//         super.approve(spender, id);
//         emit ApprovalAttempt(owner, spender, id, true, "");
//     }

//     // === Transfer Override Functions ===
//     function transferFrom(
//         address from,
//         address to,
//         uint256 tokenId
//     ) public payable virtual override {
//         require(!isLocked(from, tokenId), "Transfer locked");

//         SecurityLevel level = tokenSecurityLevels[tokenId] != SecurityLevel.NONE
//             ? tokenSecurityLevels[tokenId]
//             : securityLevel;

//         require(
//             msg.value > 0 || from == ownerOf(tokenId),
//             "Royalty payment required for transfers"
//         );

//         if (msg.value > 0) {
//             _handleRoyaltyPayment(tokenId, from, to, msg.value);
//         }

//         if (level == SecurityLevel.CAL_ONLY || level == SecurityLevel.FULL) {
//             require(_isAllowed(msg.sender, from), "Caller not allowed by CAL");
//         }

//         DN404Mirror.transferFrom(from, to, tokenId);
//         emit TransferAttempt(from, to, tokenId, true, "");
//     }

//     function safeTransferFrom(
//         address from,
//         address to,
//         uint256 tokenId
//     ) public payable virtual override {
//         require(!isLocked(from, tokenId), "Transfer locked");

//         SecurityLevel level = tokenSecurityLevels[tokenId] != SecurityLevel.NONE
//             ? tokenSecurityLevels[tokenId]
//             : securityLevel;

//         if (level == SecurityLevel.CAL_ONLY || level == SecurityLevel.FULL) {
//             require(_isAllowed(msg.sender, from), "Caller not allowed by CAL");
//         }

//         if (
//             level == SecurityLevel.ROYALTY_ONLY || level == SecurityLevel.FULL
//         ) {
//             _handleRoyaltyPayment(tokenId, from, to, msg.value);
//         }

//         DN404Mirror.safeTransferFrom(from, to, tokenId);
//         emit TransferAttempt(from, to, tokenId, true, "");
//     }

//     function safeTransferFrom(
//         address from,
//         address to,
//         uint256 tokenId,
//         bytes calldata data
//     ) public payable virtual override {
//         require(!isLocked(from, tokenId), "Transfer locked");

//         SecurityLevel level = tokenSecurityLevels[tokenId] != SecurityLevel.NONE
//             ? tokenSecurityLevels[tokenId]
//             : securityLevel;

//         if (level == SecurityLevel.CAL_ONLY || level == SecurityLevel.FULL) {
//             require(_isAllowed(msg.sender, from), "Caller not allowed by CAL");
//         }

//         if (
//             level == SecurityLevel.ROYALTY_ONLY || level == SecurityLevel.FULL
//         ) {
//             _handleRoyaltyPayment(tokenId, from, to, msg.value);
//         }

//         DN404Mirror.safeTransferFrom(from, to, tokenId, data);
//         emit SafeTransferAttempt(from, to, tokenId, data, true, "");
//     }

//     // === Royalty Handling ===
//     function _handleRoyaltyPayment(
//         uint256 tokenId,
//         address from,
//         address to,
//         uint256 paymentAmount
//     ) internal {
//         address marketplace = tokenMarketplaces[tokenId] != address(0)
//             ? tokenMarketplaces[tokenId]
//             : msg.sender;

//         require(approvedMarketplaces[marketplace], "Invalid marketplace");

//         (address royaltyReceiver, uint256 royaltyAmount) = royaltyInfo(
//             tokenId,
//             paymentAmount
//         );
//         uint256 marketplaceFee = (paymentAmount *
//             marketplaceFees[marketplace]) / 10000;

//         require(
//             paymentAmount >= royaltyAmount + marketplaceFee,
//             "Insufficient payment"
//         );

//         // Pay royalty
//         if (royaltyAmount > 0) {
//             (bool success, ) = royaltyReceiver.call{value: royaltyAmount}("");
//             require(success, "Royalty payment failed");

//             emit RoyaltyPaid(
//                 address(this),
//                 tokenId,
//                 royaltyReceiver,
//                 from,
//                 to,
//                 royaltyAmount
//             );
//         }

//         // Pay marketplace fee
//         if (marketplaceFee > 0) {
//             (bool success, ) = marketplace.call{value: marketplaceFee}("");
//             require(success, "Marketplace fee payment failed");
//         }

//         // Return excess payment to seller
//         uint256 sellerPayment = paymentAmount - royaltyAmount - marketplaceFee;
//         if (sellerPayment > 0) {
//             (bool success, ) = from.call{value: sellerPayment}("");
//             require(success, "Seller payment failed");
//         }
//     }

//     // === Marketplace Management ===
//     function setMarketplaceApproval(
//         address marketplace,
//         bool approved,
//         uint256 fee
//     ) external onlyRole(ADMIN_ROLE) {
//         require(marketplace != address(0), "Invalid marketplace");
//         approvedMarketplaces[marketplace] = approved;
//         marketplaceFees[marketplace] = fee;
//         emit MarketplaceApproved(marketplace, approved, fee);
//     }

//     function setTokenMarketplace(
//         uint256 tokenId,
//         address marketplace
//     ) external {
//         require(ownerOf(tokenId) == msg.sender, "Not token owner");
//         require(approvedMarketplaces[marketplace], "Marketplace not approved");
//         tokenMarketplaces[tokenId] = marketplace;
//         emit TokenMarketplaceSet(tokenId, marketplace);
//     }

//     /**
//      * @dev Returns allowed contract level for a given token
//      * @param tokenId Token ID to check
//      */
//     function contractLevel(uint256 tokenId) external view returns (uint256) {
//         return _getCALLevel(ownerOf(tokenId), tokenId);
//     }

//     /**
//      * @dev Returns the base contract level
//      */
//     function defaultContractLevel() external view returns (uint256) {
//         return CALLevel;
//     }

//     // === Interface Support ===
//     function supportsInterface(
//         bytes4 interfaceId
//     )
//         public
//         view
//         virtual
//         override(DN404Mirror, AccessControl, ERC2981)
//         returns (bool)
//     {
//         return
//             interfaceId == INTERFACE_ID_ERC721C ||
//             interfaceId == INTERFACE_ID_CONTRACT_LEVEL ||
//             interfaceId == _SEAPORT_HOOK_INTERFACE ||
//             DN404Mirror.supportsInterface(interfaceId) ||
//             AccessControl.supportsInterface(interfaceId) ||
//             ERC2981.supportsInterface(interfaceId);
//     }

//     // === Utility Functions ===
//     receive() external payable virtual override {}

//     function withdrawETH() external onlyRole(ADMIN_ROLE) {
//         (bool success, ) = msg.sender.call{value: address(this).balance}("");
//         require(success, "ETH withdrawal failed");
//     }
// }
