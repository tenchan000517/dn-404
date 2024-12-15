// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.4;
// import "hardhat/console.sol";
// import "./DN404Mirror.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/token/common/ERC2981.sol";
// import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol"; // ローカル許可リスト用

// contract ExtendedDN404Mirror is AccessControl, DN404Mirror, ERC2981{

//     using EnumerableSet for EnumerableSet.AddressSet;

//     event ApprovalAttempt(address indexed owner, address indexed spender, uint256 indexed tokenId, bool success, string reason);
//     event SetApprovalForAllAttempt(address indexed owner, address indexed operator, bool approved, bool success, string reason);
//     event TransferAttempt(address indexed from, address indexed to, uint256 indexed tokenId, bool success, string reason);
//     event SafeTransferAttempt(address indexed from, address indexed to, uint256 indexed tokenId, bytes data, bool success, string reason);

//     bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
//     bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

//     // CALレベル
//     uint256 public calLevel = 1;

//     // CALレベルごとの許可リスト
//     mapping(uint256 => EnumerableSet.AddressSet) private calAllowedAddresses;

//     // ロック機能用
//     bool public contractLocked = false; // コントラクト全体のロック
//     mapping(address => bool) public walletLocked; // ウォレットごとのロック
//     mapping(uint256 => bool) public tokenLocked; // トークンごとのロック

//         constructor(address deployer) DN404Mirror(deployer) {
//             console.log("Deploying ExtendedDN404Mirror with deployer:", deployer);

//             _grantRole(DEFAULT_ADMIN_ROLE, deployer);
//             console.log("Granted DEFAULT_ADMIN_ROLE to:", deployer);

//             _grantRole(ADMIN_ROLE, deployer);
//             _grantRole(MINTER_ROLE, deployer);

//         _setDefaultRoyalty(0xDC68E2aF8816B3154c95dab301f7838c7D83A0Ba, 1000);

//         // CALレベル1のアドレス追加
//         calAllowedAddresses[1].add(0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834);

//         // CALレベル2のアドレス追加
//         calAllowedAddresses[2].add(0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834);
//         calAllowedAddresses[2].add(0x1E0049783F008A0085193E00003D00cd54003c71);

//         // CALレベル3のアドレス追加
//         calAllowedAddresses[3].add(0x1E0049783F008A0085193E00003D00cd54003c71);
//         calAllowedAddresses[3].add(0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834);
//         calAllowedAddresses[3].add(0x2f18F339620a63e43f0839Eeb18D7de1e1Be4DfB);
//         calAllowedAddresses[3].add(0xF849de01B080aDC3A814FaBE1E2087475cF2E354);
//         calAllowedAddresses[3].add(0x000000000060C4Ca14CfC4325359062ace33Fe3D);
//         calAllowedAddresses[3].add(0x4feE7B061C97C9c496b01DbcE9CDb10c02f0a0Be);
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
//     function setCALLevel(uint256 level) public onlyRole(ADMIN_ROLE) {
//         require(level <= 3, "Invalid CAL level");
//         calLevel = level;
//     }

//     // CALレベルごとの許可リストにアドレスを追加
//     function addAddressToCAL(uint256 level, address contractAddress) public onlyRole(ADMIN_ROLE) {
//         require(level <= 3, "Invalid CAL level");
//         calAllowedAddresses[level].add(contractAddress);
//     }

//     // CALレベルごとの許可リストからアドレスを削除
//     function removeAddressFromCAL(uint256 level, address contractAddress) public onlyRole(ADMIN_ROLE) {
//         require(level <= 3, "Invalid CAL level");
//         calAllowedAddresses[level].remove(contractAddress);
//     }

//     // CALレベルごとの許可リストを取得
//     function getCALAllowedContracts(uint256 level) public view returns (address[] memory) {
//         return calAllowedAddresses[level].values();
//     }

//     function _isAllowed(address operator, address tokenOwner) internal view returns (bool) {
//         if (calLevel == 0) return true;
//         if (operator == tokenOwner) return true;
//         return calAllowedAddresses[calLevel].contains(operator);
//     }

//     function checkIsAllowed(address operator, address tokenOwner) public view returns (bool) {
//     return _isAllowed(operator, tokenOwner);
//     }

//     // function setApprovalForAll(address operator, bool approved) public override {
//     //     require(_isAllowed(operator, msg.sender), "Operator not allowed");
//     //     super.setApprovalForAll(operator, approved);
//     // }

//     // function approve(address spender, uint256 id) public payable virtual override {
//     //     address owner = ownerOf(id);
//     //     require(_isAllowed(spender, owner), "Approve to address not allowed");
//     //     super.approve(spender, id);
//     // }

//     // function transferFrom(address from, address to, uint256 tokenId) public payable override {
//     //     require(_isAllowed(msg.sender, from) || msg.sender == from || isApprovedForAll(from, msg.sender), "Caller is not allowed to transferFrom");
//     //     super.transferFrom(from, to, tokenId);
//     // }

//     // function safeTransferFrom(address from, address to, uint256 tokenId) public payable override {
//     //     require(_isAllowed(msg.sender, from) || msg.sender == from || isApprovedForAll(from, msg.sender), "Caller is not allowed to safeTransferFrom");
//     //     super.safeTransferFrom(from, to, tokenId);
//     // }

//     // function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) public payable override {
//     //     require(_isAllowed(msg.sender, from) || msg.sender == from || isApprovedForAll(from, msg.sender), "Caller is not allowed to safeTransferFrom with data");
//     //     super.safeTransferFrom(from, to, tokenId, data);
//     // }

//     function setApprovalForAll(address operator, bool approved) public override {
//         bool success = true;
//         string memory reason = "";
        
//         try this.externalSetApprovalForAll(operator, approved) {
//             // 成功した場合、何もしない
//         } catch Error(string memory errorMessage) {
//             success = false;
//             reason = errorMessage;
//         } catch {
//             success = false;
//             reason = "Unknown error";
//         }

//         emit SetApprovalForAllAttempt(msg.sender, operator, approved, success, reason);

//         if (!success) {
//             revert(reason);
//         }
//     }

//     function externalSetApprovalForAll(address operator, bool approved) external {
//         require(_isAllowed(operator, msg.sender), "Operator not allowed");
//         super.setApprovalForAll(operator, approved);
//     }

//     // DN404Mirrorの関数をオーバーライドしてCALチェックを追加
//     function approve(address spender, uint256 id) public payable virtual override {
//         require(_isAllowed(spender, ownerOf(id)), "CAL: Not allowed");
//         super.approve(spender, id);
//     }

//     function transferFrom(address from, address to, uint256 tokenId) public payable virtual override {
//         require(_isAllowed(msg.sender, from) || msg.sender == from || isApprovedForAll(from, msg.sender), "CAL: Not allowed");
//         super.transferFrom(from, to, tokenId);
//     }

//     function externalTransferFrom(address from, address to, uint256 tokenId) external payable {
//         require(_isAllowed(msg.sender, from) || msg.sender == from || isApprovedForAll(from, msg.sender), "Caller is not allowed to transferFrom");
//         super.transferFrom(from, to, tokenId);
//     }

//     function safeTransferFrom(address from, address to, uint256 tokenId) public payable override {
//         this.safeTransferFrom(from, to, tokenId, "");
//     }

//     function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) public payable override {
//         bool success = true;
//         string memory reason = "";
        
//         try this.externalSafeTransferFrom(from, to, tokenId, data) {
//             // 成功した場合、何もしない
//         } catch Error(string memory errorMessage) {
//             success = false;
//             reason = errorMessage;
//         } catch {
//             success = false;
//             reason = "Unknown error";
//         }

//         emit SafeTransferAttempt(from, to, tokenId, data, success, reason);

//         if (!success) {
//             revert(reason);
//         }
//     }

//     function externalSafeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external payable {
//         require(_isAllowed(msg.sender, from) || msg.sender == from || isApprovedForAll(from, msg.sender), "Caller is not allowed to safeTransferFrom");
//         super.safeTransferFrom(from, to, tokenId, data);
//     }

//     function supportsInterface(bytes4 interfaceId) public view virtual override(DN404Mirror, AccessControl, ERC2981) returns (bool) {
//         return 
//                 super.supportsInterface(interfaceId) || 
//                AccessControl.supportsInterface(interfaceId) ||
//                ERC2981.supportsInterface(interfaceId);
//     }
// }