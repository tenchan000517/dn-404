// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.4;
// import "hardhat/console.sol";
// import "./DN404Mirror.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/token/common/ERC2981.sol";
// import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol"; // ローカル許可リスト用
// import "contract-allow-list/contracts/proxy/interface/IContractAllowListProxy.sol";

// contract ExtendedDN404Mirror is AccessControl, DN404Mirror, ERC2981{

//     using EnumerableSet for EnumerableSet.AddressSet;

//     IContractAllowListProxy public CAL;
//     EnumerableSet.AddressSet private localAllowedAddresses;

//     event ApprovalAttempt(address indexed owner, address indexed spender, uint256 indexed tokenId, bool success, string reason);
//     event SetApprovalForAllAttempt(address indexed owner, address indexed operator, bool approved, bool success, string reason);
//     event TransferAttempt(address indexed from, address indexed to, uint256 indexed tokenId, bool success, string reason);
//     event SafeTransferAttempt(address indexed from, address indexed to, uint256 indexed tokenId, bytes data, bool success, string reason);

//     bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
//     bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

//     bool public enableRestrict = true;
//     // CALレベル
//     uint256 public CALLevel = 2;

//     // token specific CAL level
//     mapping(uint256 => uint256) public tokenCALLevel;

//     // wallet specific CAL level
//     mapping(address => uint256) public walletCALLevel;

//     event LocalCalAdded(address indexed operator, address indexed transferer);
//     event LocalCalRemoved(address indexed operator, address indexed transferer);

//     // ロック機能用
//     bool public contractLocked = false; // コントラクト全体のロック
//     mapping(address => bool) public walletLocked; // ウォレットごとのロック
//     mapping(uint256 => bool) public tokenLocked; // トークンごとのロック

//     constructor(address deployer, address _cal) DN404Mirror(deployer) {
//             console.log("Deploying ExtendedDN404Mirror with deployer:", deployer);

//             _grantRole(DEFAULT_ADMIN_ROLE, deployer);
//             console.log("Granted DEFAULT_ADMIN_ROLE to:", deployer);

//             _grantRole(ADMIN_ROLE, deployer);
//             _grantRole(MINTER_ROLE, deployer);

//         _setDefaultRoyalty(0xDC68E2aF8816B3154c95dab301f7838c7D83A0Ba, 1000);

//         CAL = IContractAllowListProxy(_cal);

//         // // CALレベル1のアドレス追加
//         // calAllowedAddresses[1].add(0x1E0049783F008A0085193E00003D00cd54003c71);
//         // calAllowedAddresses[1].add(0x2052f8A2Ff46283B30084e5d84c89A2fdBE7f74b);

//         // // CALレベル2のアドレス追加
//         // calAllowedAddresses[2].add(0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834);
//         // calAllowedAddresses[2].add(0x1E0049783F008A0085193E00003D00cd54003c71);

//         // // CALレベル3のアドレス追加
//         // calAllowedAddresses[3].add(0x1E0049783F008A0085193E00003D00cd54003c71);
//         // calAllowedAddresses[3].add(0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834);
//         // calAllowedAddresses[3].add(0x2f18F339620a63e43f0839Eeb18D7de1e1Be4DfB);
//         // calAllowedAddresses[3].add(0xF849de01B080aDC3A814FaBE1E2087475cF2E354);
//         // calAllowedAddresses[3].add(0x000000000060C4Ca14CfC4325359062ace33Fe3D);
//         // calAllowedAddresses[3].add(0x4feE7B061C97C9c496b01DbcE9CDb10c02f0a0Be);
//     }

//     function setDefaultRoyalty(address receiver, uint96 feeNumerator) public onlyRole(ADMIN_ROLE) {
//         _setDefaultRoyalty(receiver, feeNumerator);
//     }

//     // ロック機能：コントラクト全体のロック
//     function lockContract() public onlyRole(ADMIN_ROLE) {
//         contractLocked = true;
//     }

//     function unlockContract() public onlyRole(ADMIN_ROLE) {
//         contractLocked = false;
//     }

//     // ロック機能：ウォレットごとのロック
//     function lockWallet(address wallet) public onlyRole(ADMIN_ROLE) {
//         walletLocked[wallet] = true;
//     }

//     function unlockWallet(address wallet) public onlyRole(ADMIN_ROLE) {
//         walletLocked[wallet] = false;
//     }

//     // ロック機能：トークンごとのロック
//     function lockToken(uint256 tokenId) public onlyRole(ADMIN_ROLE) {
//         tokenLocked[tokenId] = true;
//     }

//     function unlockToken(uint256 tokenId) public onlyRole(ADMIN_ROLE) {
//         tokenLocked[tokenId] = false;
//     }

//     // トークンやウォレットがロックされているか確認
//     function isLocked(address wallet, uint256 tokenId) public view returns (bool) {
//         return contractLocked || walletLocked[wallet] || tokenLocked[tokenId];
//     }

//     // CALレベルを設定する
//     function setCAL(address _cal) external onlyRole(ADMIN_ROLE) {
//         CAL = IContractAllowListProxy(_cal);
//     }

//     function setCALLevel(uint256 level) external onlyRole(ADMIN_ROLE) {
//         CALLevel = level;
//     }

//     // CALレベルごとの許可リストにアドレスを追加
//     function addLocalContractAllowList(address transferer) external onlyRole(ADMIN_ROLE) {
//         localAllowedAddresses.add(transferer);
//         emit LocalCalAdded(msg.sender, transferer);
//     }

//     // CALレベルごとの許可リストからアドレスを削除
//     function removeLocalContractAllowList(address transferer) external onlyRole(ADMIN_ROLE) {
//         localAllowedAddresses.remove(transferer);
//         emit LocalCalRemoved(msg.sender, transferer);
//     }

//     // CALレベルごとの許可リストを取得
//     function getLocalContractAllowList() external view returns (address[] memory) {
//         return localAllowedAddresses.values();
//     }

//     function setTokenCALLevel(uint256 tokenId, uint256 level) external {
//         require(ownerOf(tokenId) == msg.sender, "Not token owner");
//         tokenCALLevel[tokenId] = level;
//     }

//     function setWalletCALLevel(uint256 level) external {
//         walletCALLevel[msg.sender] = level;
//     }

//     function _getCALLevel(address holder, uint256 tokenId) internal view returns (uint256) {
//         if (tokenCALLevel[tokenId] > 0) {
//             return tokenCALLevel[tokenId];
//         }
//         if (walletCALLevel[holder] > 0) {
//             return walletCALLevel[holder];
//         }
//         return CALLevel;
//     }

//     function _isAllowed(address operator, address tokenOwner) internal view returns (bool) {
//         if (!enableRestrict) return true;
//         if (operator == tokenOwner) return true;
//         uint256 level = _getCALLevel(tokenOwner, 0); // tokenIdは0を使用（全体の承認なので）
//         return localAllowedAddresses.contains(operator) || CAL.isAllowed(operator, level);
//     }

//     function checkIsAllowed(address operator, address tokenOwner) public view returns (bool) {
//     return _isAllowed(operator, tokenOwner);
//     }

//     function setApprovalForAll(address operator, bool approved) public virtual override {
//         require(_isAllowed(operator, msg.sender), "Operator not allowed");
//         super.setApprovalForAll(operator, approved);
//     }

//     function approve(address spender, uint256 id) public payable virtual override {
//         address owner = ownerOf(id);
//         require(_isAllowed(spender, owner), "Spender not allowed");
//         super.approve(spender, id);
//     }

//     function transferFrom(address from, address to, uint256 id) public payable virtual override {
//         require(_isAllowed(msg.sender, from), "Caller not allowed to transfer");
//         super.transferFrom(from, to, id);
//     }

//     function safeTransferFrom(address from, address to, uint256 id) public payable virtual override {
//         require(_isAllowed(msg.sender, from), "Caller not allowed to transfer");
//         super.safeTransferFrom(from, to, id);
//     }

//     function safeTransferFrom(address from, address to, uint256 id, bytes calldata data) public payable virtual override {
//         require(_isAllowed(msg.sender, from), "Caller not allowed to transfer");
//         super.safeTransferFrom(from, to, id, data);
//     }

//     function supportsInterface(bytes4 interfaceId) public view virtual override(DN404Mirror, AccessControl, ERC2981) returns (bool) {
//         return 
//                 DN404Mirror.supportsInterface(interfaceId) || 
//                 AccessControl.supportsInterface(interfaceId) ||
//                 ERC2981.supportsInterface(interfaceId);
//     }
// }
