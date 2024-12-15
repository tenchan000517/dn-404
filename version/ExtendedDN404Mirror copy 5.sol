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
// contract ExtendedDN404Mirror is
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

//     // Security Levels (Combined DN404 CAL and ERC721C security)
//     enum SecurityLevel {
//         NONE, // No restrictions
//         CAL_ONLY, // Only CAL restrictions
//         ROYALTY_ONLY, // Only royalty restrictions
//         FULL // Both CAL and royalty restrictions
//     }

//     // State Variables
//     SecurityLevel public securityLevel = SecurityLevel.FULL;
//     mapping(address => bool) public approvedMarketplaces;
//     mapping(address => uint256) public marketplaceFees;
//     mapping(uint256 => bool) public tokenLocked;
//     mapping(uint256 => SecurityLevel) public tokenSecurityLevels;
//     mapping(uint256 => address) public tokenMarketplaces;

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
//     event RoyaltyEnforced(uint256 tokenId, address receiver, uint96 feeNumerator);
//     event CreatorEarningsConfigured(address receiver, uint96 feeNumerator);

//     // === Constructor ===
//     constructor(
//         address deployer,
//         address _cal,
//         address defaultRoyaltyReceiver,
//         uint96 defaultRoyaltyFeeNumerator
//     ) DN404Mirror(deployer) {
//         _grantRole(DEFAULT_ADMIN_ROLE, deployer);
//         _grantRole(ADMIN_ROLE, deployer);
//         _grantRole(MINTER_ROLE, deployer);

//         _setDefaultRoyalty(defaultRoyaltyReceiver, defaultRoyaltyFeeNumerator);
//         CAL = IContractAllowListProxy(_cal);
//     }

//     // === Ownership Management ===
//     function owner() public view virtual override returns (address) {
//         address currentOwner = super.owner();
//         if (currentOwner == address(0)) {
//             return _getDN404NFTStorage().deployer;
//         }
//         return currentOwner;
//     }

//     function syncOwnership() public returns (bool) {
//         address oldOwner = owner();
//         bool success = pullOwner();
//         if (success) {
//             address newOwner = owner();
//             if (oldOwner != newOwner) {
//                 emit OwnershipSynced(oldOwner, newOwner);
//             }
//         }
//         return success;
//     }

//     // === Creator Earnings Management ===
//     function setTokenRoyalty(
//         uint256 tokenId,
//         address receiver,
//         uint96 feeNumerator
//     ) external {
//         address tokenOwner = ownerOf(tokenId);
//         require(
//             msg.sender == tokenOwner || 
//             isApprovedForAll(tokenOwner, msg.sender) ||
//             getApproved(tokenId) == msg.sender,
//             "Caller is not owner nor approved"
//         );
//         _setTokenRoyalty(tokenId, receiver, feeNumerator);
//         emit RoyaltyEnforced(tokenId, receiver, feeNumerator);
//     }

//     function setDefaultRoyalty(
//         address receiver,
//         uint96 feeNumerator
//     ) external onlyRole(ADMIN_ROLE) {
//         _setDefaultRoyalty(receiver, feeNumerator);
//         emit CreatorEarningsConfigured(receiver, feeNumerator);
//     }

//     // === Security Level Management ===
//     function setGlobalSecurityLevel(
//         SecurityLevel _level
//     ) external onlyRole(ADMIN_ROLE) {
//         securityLevel = _level;
//     }

//     function setTokenSecurityLevel(
//         uint256 tokenId,
//         SecurityLevel _level
//     ) external {
//         require(
//             ownerOf(tokenId) == msg.sender || hasRole(ADMIN_ROLE, msg.sender),
//             "Not authorized"
//         );
//         tokenSecurityLevels[tokenId] = _level;
//         emit SecurityLevelChanged(tokenId, _level);
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

//     // === Transfer Override Functions ===
//     function transferFrom(
//         address from,
//         address to,
//         uint256 tokenId
//     ) public payable virtual override nonReentrant {
//         require(!tokenLocked[tokenId], "Token locked");

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

//         super.transferFrom(from, to, tokenId);
//     }

//     function safeTransferFrom(
//         address from,
//         address to,
//         uint256 tokenId
//     ) public payable virtual override {
//         super.safeTransferFrom(from, to, tokenId);
//     }

//     function safeTransferFrom(
//         address from,
//         address to,
//         uint256 tokenId,
//         bytes calldata data
//     ) public payable virtual override nonReentrant {
//         require(!tokenLocked[tokenId], "Token locked");

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

//         super.safeTransferFrom(from, to, tokenId, data);
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

//     // === Existing CAL Functions ===
//     function _isAllowed(
//         address operator,
//         address tokenOwner
//     ) internal view returns (bool) {
//         if (operator == tokenOwner) return true;
//         if (!localAllowedAddresses.contains(operator)) {
//             uint256 level = CAL.isAllowed(operator, 0) ? 0 : 2;
//             return CAL.isAllowed(operator, level);
//         }
//         return true;
//     }

//     // === Interface Support ===
//     function supportsInterface(
//         bytes4 interfaceId
//     ) public view virtual override(DN404Mirror, AccessControl, ERC2981) returns (bool) {
//         return
//             interfaceId == _SEAPORT_HOOK_INTERFACE || // Add Seaport v1.6 hooks support
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