// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.4;

// import "./DN404.sol";
// import "./ExtendedDN404Mirror.sol";
// import {Ownable} from "solady/src/auth/Ownable.sol";
// import {LibString} from "solady/src/utils/LibString.sol";
// import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
// import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";

// contract TESTDN404v2 is DN404, Ownable {
//     error FractionalTransferNotAllowed();
//     address public immutable CAL;

//     string private _name;
//     string private _symbol;
//     string private _baseURI;
//     bytes32 private _allowlistRoot;

//     uint96 public publicPrice;
//     uint96 public allowlistPrice;
//     uint32 public totalMinted;
//     bool public live;

//     uint32 public maxPerWallet = 100;
//     uint32 public maxSupply = 100;
//     uint256 private _mintRatio = 1000;
//     uint8 private _decimals = 18;

//     error InvalidProof();
//     error InvalidMint();
//     error InvalidPrice();
//     error TotalSupplyReached();
//     error NotLive();

//     ExtendedDN404Mirror public mirror;

//     constructor(
//         string memory name_,
//         string memory symbol_,
//         bytes32 allowlistRoot_,
//         uint96 publicPrice_,
//         uint96 allowlistPrice_,
//         uint96 initialTokenSupply,
//         address initialSupplyOwner,
//         address contractAllowListProxy
//     ) {
//         _initializeOwner(msg.sender);

//         _name = name_;
//         _symbol = symbol_;
//         _allowlistRoot = allowlistRoot_;
//         publicPrice = publicPrice_;
//         allowlistPrice = allowlistPrice_;
//         CAL = contractAllowListProxy;

//         mirror = new ExtendedDN404Mirror(msg.sender, CAL);

//         _initializeDN404(
//             initialTokenSupply,
//             initialSupplyOwner,
//             address(mirror)
//         );
//     }

//     // nextTokenId を取得するための public 関数
//     function getNextTokenId() public view returns (uint32) {
//         DN404Storage storage $ = _getDN404Storage();
//         return $.nextTokenId;
//     }

//     function _unit() internal view override returns (uint256) {
//         return _mintRatio * 10 ** 18;
//     }

//     function setMintRatio(uint256 newRatio) public onlyOwner {
//         _mintRatio = newRatio;
//     }

//     modifier onlyLive() {
//         if (!live) {
//             revert NotLive();
//         }
//         _;
//     }

//     modifier checkPrice(uint256 price, uint256 nftAmount) {
//         if (price * nftAmount != msg.value) {
//             revert InvalidPrice();
//         }
//         _;
//     }

//     function setDecimals(uint8 newDecimals) public onlyOwner {
//         _decimals = newDecimals;
//     }

//     function setMaxPerWallet(uint32 _maxPerWallet) public onlyOwner {
//         maxPerWallet = _maxPerWallet;
//     }

//     function setMaxSupply(uint32 _maxSupply) public onlyOwner {
//         maxSupply = _maxSupply;
//     }

//     modifier checkAndUpdateTotalMinted(uint256 nftAmount) {
//         uint256 newTotalMinted = uint256(totalMinted) + nftAmount;
//         if (newTotalMinted > maxSupply) {
//             revert TotalSupplyReached();
//         }
//         totalMinted = uint32(newTotalMinted);
//         _;
//     }

//     modifier checkAndUpdateBuyerMintCount(uint256 nftAmount) {
//         uint256 currentMintCount = _getAux(msg.sender);
//         uint256 newMintCount = currentMintCount + nftAmount;
//         if (newMintCount > maxPerWallet) {
//             revert InvalidMint();
//         }
//         _setAux(msg.sender, uint88(newMintCount));
//         _;
//     }

//     // マークルルートを更新する関数を追加
//     function setAllowlistRoot(bytes32 newRoot) public onlyOwner {
//         _allowlistRoot = newRoot;
//     }

//     // 現在のマークルルートを確認する関数も追加
//     function getAllowlistRoot() public view returns (bytes32) {
//         return _allowlistRoot;
//     }

//     function mint(
//         uint256 tokenAmount
//     )
//         public
//         payable
//         onlyLive
//         checkPrice(publicPrice, tokenAmount)
//         checkAndUpdateBuyerMintCount(tokenAmount)
//         checkAndUpdateTotalMinted(tokenAmount)
//     {
//         _mint(msg.sender, tokenAmount * 10 ** _decimals);
//     }

//     function allowlistMint(
//         uint256 tokenAmount,
//         bytes32[] calldata proof
//     )
//         public
//         payable
//         onlyLive
//         checkPrice(allowlistPrice, tokenAmount)
//         checkAndUpdateBuyerMintCount(tokenAmount)
//         checkAndUpdateTotalMinted(tokenAmount)
//     {
//         bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
//         if (!MerkleProofLib.verify(proof, _allowlistRoot, leaf)) {
//             revert InvalidProof();
//         }

//         _mint(msg.sender, tokenAmount * 10 ** _decimals);
//     }

//     function mintNFT(
//         uint256 nftAmount
//     )
//         public
//         payable
//         onlyLive
//         checkPrice(publicPrice, nftAmount)
//         checkAndUpdateBuyerMintCount(nftAmount)
//         checkAndUpdateTotalMinted(nftAmount)
//     {
//         _mint(msg.sender, nftAmount * _unit());
//     }

//     function allowlistNFTMint(
//         uint256 nftAmount,
//         bytes32[] calldata proof
//     )
//         public
//         payable
//         onlyLive
//         checkPrice(allowlistPrice, nftAmount)
//         checkAndUpdateBuyerMintCount(nftAmount)
//         checkAndUpdateTotalMinted(nftAmount)
//     {
//         bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
//         if (!MerkleProofLib.verify(proof, _allowlistRoot, leaf)) {
//             revert InvalidProof();
//         }

//         _mint(msg.sender, nftAmount * _unit());
//     }

//     function setBaseURI(string memory baseURI_) public onlyOwner {
//         _baseURI = baseURI_;
//     }

//     function setPrices(
//         uint96 publicPrice_,
//         uint96 allowlistPrice_
//     ) public onlyOwner {
//         publicPrice = publicPrice_;
//         allowlistPrice = allowlistPrice_;
//     }

//     function toggleLive() public onlyOwner {
//         live = !live;
//     }

//     function withdraw() public onlyOwner {
//         SafeTransferLib.safeTransferAllETH(msg.sender);
//     }

//     function name() public view override returns (string memory) {
//         return _name;
//     }

//     function symbol() public view override returns (string memory) {
//         return _symbol;
//     }

//     function tokenURI(
//         uint256 tokenId
//     ) public view override returns (string memory) {
//         return _tokenURI(tokenId);
//     }

//     function _tokenURI(
//         uint256 tokenId
//     ) internal view virtual returns (string memory result) {
//         if (bytes(_baseURI).length != 0) {
//             // tokenIdを文字列に変換し、基本URIと結合して、最後に".json"を追加
//             result = string(
//                 abi.encodePacked(_baseURI, LibString.toString(tokenId), ".json")
//             );
//         }
//     }

//     // // オーバーライドされた転送関数
//     // function transfer(address to, uint256 amount) public override returns (bool) {
//     //     require(mirror.isTransferAllowed(msg.sender), "Transfer not allowed");
//     //     return super.transfer(to, amount);
//     // }

//     // function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
//     //     require(mirror.isTransferAllowed(from), "Transfer not allowed");
//     //     return super.transferFrom(from, to, amount);
//     // }

//     // ExtendedDN404Mirror関連の新しい関数
//     // function grantRole(bytes32 role, address account) public onlyOwner {
//     //     mirror.grantRole(role, account);
//     // }

//     // function revokeRole(bytes32 role, address account) public onlyOwner {
//     //     mirror.revokeRole(role, account);
//     // }

//     // function setDefaultRoyalty(address receiver, uint96 feeNumerator) public onlyOwner {
//     //     mirror.setDefaultRoyalty(receiver, feeNumerator);
//     // }

//     // function deleteDefaultRoyalty() public onlyOwner {
//     //     mirror.deleteDefaultRoyalty();
//     // }

//     // function setCALLevel(uint256 level) public onlyOwner {
//     //     mirror.setCALLevel(level);
//     // }

//     // function setCAL(address calAddress) external onlyOwner {
//     //     mirror.setCAL(calAddress);
//     // }

//     // インターフェースサポートの確認
//     function supportsInterface(
//         bytes4 interfaceId
//     ) public view virtual returns (bool) {
//         return mirror.supportsInterface(interfaceId);
//     }
// }
