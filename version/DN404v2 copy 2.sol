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
//     error PhaseNotConfigured();
//     error InvalidTimePeriod();
//     error OverlappingPhases();
//     error SaleConfigAlreadyExists();

//     address public immutable CAL;

//     string private _name;
//     string private _symbol;
//     string private _baseURI;

//     // セールフェーズの定義
//     enum SalePhase {
//         NotStarted,
//         OGList,
//         WL1,
//         WL2,
//         Public,
//         Ended
//     }

//     struct SaleConfig {
//         uint256 startTime;
//         uint256 endTime;
//         uint96 price;
//         uint32 maxPerWallet;
//         bytes32 merkleRoot;
//         bool isConfigured; // 設定済みかどうかを追跡
//     }

//     struct PhaseStatus {
//         bool isActive;
//         uint256 startTime;
//         uint256 endTime;
//     }

//     // セールフェーズの状態変数
//     SalePhase public currentPhase;
//     mapping(SalePhase => SaleConfig) public saleConfigs;
//     mapping(SalePhase => mapping(address => uint32)) public mintCounts;

//     uint32 public totalMinted;
//     bool public live;

//     uint32 public maxPerWallet = 100;
//     uint32 public maxSupply = 20000;
//     uint256 private _mintRatio = 1000;
//     uint8 private _decimals = 18;

//     event PhaseConfigured(
//         SalePhase indexed phase,
//         uint256 startTime,
//         uint256 endTime,
//         uint96 price,
//         uint32 maxPerWallet,
//         bytes32 merkleRoot
//     );

//     // エラー定義
//     error InvalidProof();
//     error InvalidMint();
//     error InvalidPrice();
//     error TotalSupplyReached();
//     error NotLive();
//     error AllowlistEnded();
//     error InvalidPhase();
//     error SaleNotActive();
//     error ExceedsPhaseLimit();
//     error InvalidSaleConfig();

//     // // イベント定義（既存）
//     // event AllowlistRootUpdated(bytes32 oldRoot, bytes32 newRoot);
//     // event AllowlistEndTimeUpdated(uint256 oldEndTime, uint256 newEndTime);

//     // // イベント定義（新規追加）
//     // event SalePhaseUpdated(SalePhase indexed phase);
//     // event SaleConfigUpdated(
//     //     SalePhase indexed phase,
//     //     uint256 startTime,
//     //     uint256 endTime,
//     //     uint96 price,
//     //     uint32 maxPerWallet,
//     //     bytes32 merkleRoot
//     // );

//     ExtendedDN404Mirror public mirror;

//     constructor(
//         string memory name_,
//         string memory symbol_,
//         address contractAllowListProxy
//     ) {
//         _initializeOwner(msg.sender);

//         _name = name_;
//         _symbol = symbol_;
//         CAL = contractAllowListProxy;
//         currentPhase = SalePhase.NotStarted;

//         mirror = new ExtendedDN404Mirror(msg.sender, CAL);

//         // 初期供給は0に設定
//         _initializeDN404(0, msg.sender, address(mirror));
//     }

//     modifier phaseExists(SalePhase phase) {
//         if (!saleConfigs[phase].isConfigured) {
//             revert PhaseNotConfigured();
//         }
//         _;
//     }

//     modifier checkSaleActive() {
//         SaleConfig storage config = saleConfigs[currentPhase];
//         if (!config.isConfigured) {
//             revert PhaseNotConfigured();
//         }
//         if (
//             block.timestamp < config.startTime ||
//             block.timestamp > config.endTime
//         ) {
//             revert SaleNotActive();
//         }
//         _;
//     }

//     function configureSalePhase(
//         SalePhase phase,
//         uint256 startTime,
//         uint256 endTime,
//         uint96 price,
//         uint32 maxPerWallet_,
//         bytes32 merkleRoot
//     ) external onlyOwner {
//         // 基本的なバリデーション
//         if (startTime >= endTime) {
//             revert InvalidTimePeriod();
//         }

//         // 既存の設定がある場合は上書きを防ぐ
//         if (saleConfigs[phase].isConfigured) {
//             revert SaleConfigAlreadyExists();
//         }

//         // 他のフェーズとの時間重複チェック
//         for (
//             uint i = uint(SalePhase.OGList);
//             i <= uint(SalePhase.Public);
//             i++
//         ) {
//             SaleConfig storage existingConfig = saleConfigs[SalePhase(i)];
//             if (existingConfig.isConfigured) {
//                 if (
//                     (startTime >= existingConfig.startTime &&
//                         startTime < existingConfig.endTime) ||
//                     (endTime > existingConfig.startTime &&
//                         endTime <= existingConfig.endTime)
//                 ) {
//                     revert OverlappingPhases();
//                 }
//             }
//         }

//         saleConfigs[phase] = SaleConfig({
//             startTime: startTime,
//             endTime: endTime,
//             price: price,
//             maxPerWallet: maxPerWallet_,
//             merkleRoot: merkleRoot,
//             isConfigured: true
//         });

//         emit PhaseConfigured(
//             phase,
//             startTime,
//             endTime,
//             price,
//             maxPerWallet_,
//             merkleRoot
//         );
//     }

//     // 緊急停止機能の追加
//     function emergencyPause() external onlyOwner {
//         live = false;
//     }

//     // フェーズ設定の削除機能
//     function removeSaleConfig(SalePhase phase) external onlyOwner {
//         require(currentPhase != phase, "Cannot remove active phase config");
//         delete saleConfigs[phase];
//     }

//     // 各フェーズの状態確認
//     function getPhaseStatus(SalePhase phase) external view returns (PhaseStatus memory) {
//         SaleConfig storage config = saleConfigs[phase];
//         return PhaseStatus({
//             isActive: config.isConfigured && 
//                      block.timestamp >= config.startTime && 
//                      block.timestamp <= config.endTime,
//             startTime: config.startTime,
//             endTime: config.endTime
//         });
//     }

//     function setPhase(
//         SalePhase newPhase
//     ) external onlyOwner phaseExists(newPhase) {
//         // フェーズの遷移が正しいかチェック
//         if (newPhase != SalePhase.NotStarted && newPhase != SalePhase.Ended) {
//             require(
//                 uint256(newPhase) > uint256(currentPhase) ||
//                     currentPhase == SalePhase.Ended,
//                 "Invalid phase transition"
//             );
//         }

//         currentPhase = newPhase;
//         emit SalePhaseUpdated(newPhase);
//     }

//     modifier checkPhaseLimit(uint256 amount) {
//         SaleConfig storage config = saleConfigs[currentPhase];
//         uint32 currentCount = mintCounts[currentPhase][msg.sender];
//         if (currentCount + uint32(amount) > config.maxPerWallet) {
//             revert ExceedsPhaseLimit();
//         }
//         _;
//     }

//     // 既存の修飾子
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

//     modifier allowlistActive() {
//         if (block.timestamp > allowlistEndTime) {
//             revert AllowlistEnded();
//         }
//         _;
//     }

//     // セールフェーズ管理用の新しい関数
//     function setSaleConfig(
//         SalePhase phase,
//         uint256 startTime,
//         uint256 endTime,
//         uint96 price,
//         uint32 maxPerWallet_,
//         bytes32 merkleRoot
//     ) external onlyOwner {
//         if (startTime >= endTime) revert InvalidSaleConfig();

//         saleConfigs[phase] = SaleConfig({
//             startTime: startTime,
//             endTime: endTime,
//             price: price,
//             maxPerWallet: maxPerWallet_,
//             merkleRoot: merkleRoot
//         });

//         emit SaleConfigUpdated(
//             phase,
//             startTime,
//             endTime,
//             price,
//             maxPerWallet_,
//             merkleRoot
//         );
//     }

//     function setPhase(SalePhase newPhase) external onlyOwner {
//         currentPhase = newPhase;
//         emit SalePhaseUpdated(newPhase);
//     }

//     function getSaleConfig(
//         SalePhase phase
//     )
//         public
//         view
//         returns (
//             uint256 startTime,
//             uint256 endTime,
//             uint96 price,
//             uint32 maxPerWallet_,
//             bytes32 merkleRoot
//         )
//     {
//         SaleConfig storage config = saleConfigs[phase];
//         return (
//             config.startTime,
//             config.endTime,
//             config.price,
//             config.maxPerWallet,
//             config.merkleRoot
//         );
//     }

//     function getMintCount(
//         SalePhase phase,
//         address user
//     ) public view returns (uint32) {
//         return mintCounts[phase][user];
//     }

//     // 既存の関数
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

//     function setDecimals(uint8 newDecimals) public onlyOwner {
//         _decimals = newDecimals;
//     }

//     function setMaxPerWallet(uint32 _maxPerWallet) public onlyOwner {
//         maxPerWallet = _maxPerWallet;
//     }

//     function setMaxSupply(uint32 _maxSupply) public onlyOwner {
//         maxSupply = _maxSupply;
//     }

//     function setAllowlistRoot(bytes32 newRoot) public onlyOwner {
//         bytes32 oldRoot = _allowlistRoot;
//         _allowlistRoot = newRoot;
//         emit AllowlistRootUpdated(oldRoot, newRoot);
//     }

//     function setAllowlistEndTime(uint256 endTime) public onlyOwner {
//         uint256 oldEndTime = allowlistEndTime;
//         allowlistEndTime = endTime;
//         emit AllowlistEndTimeUpdated(oldEndTime, endTime);
//     }

//     function getAllowlistRoot() public view returns (bytes32) {
//         return _allowlistRoot;
//     }

//     // 修正されたミント関数（フェーズ管理対応）
//     function mint(
//         uint256 tokenAmount
//     )
//         public
//         payable
//         onlyLive
//         requirePhase(SalePhase.Public)
//         checkSaleActive
//         checkPhaseLimit(tokenAmount)
//         checkAndUpdateTotalMinted(tokenAmount)
//     {
//         SaleConfig storage config = saleConfigs[SalePhase.Public];
//         if (msg.value != config.price * tokenAmount) {
//             revert InvalidPrice();
//         }

//         mintCounts[SalePhase.Public][msg.sender] += uint32(tokenAmount);
//         _mint(msg.sender, tokenAmount * 10 ** _decimals);
//     }

//     function allowlistMint(
//         uint256 tokenAmount,
//         bytes32[] calldata proof
//     )
//         public
//         payable
//         onlyLive
//         checkSaleActive
//         checkPhaseLimit(tokenAmount)
//         checkAndUpdateTotalMinted(tokenAmount)
//     {
//         if (
//             currentPhase != SalePhase.OGList &&
//             currentPhase != SalePhase.WL1 &&
//             currentPhase != SalePhase.WL2
//         ) {
//             revert InvalidPhase();
//         }

//         SaleConfig storage config = saleConfigs[currentPhase];
//         if (msg.value != config.price * tokenAmount) {
//             revert InvalidPrice();
//         }

//         bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
//         if (!MerkleProofLib.verify(proof, config.merkleRoot, leaf)) {
//             revert InvalidProof();
//         }

//         mintCounts[currentPhase][msg.sender] += uint32(tokenAmount);
//         _mint(msg.sender, tokenAmount * 10 ** _decimals);
//     }

//     function mintNFT(
//         uint256 nftAmount
//     )
//         public
//         payable
//         onlyLive
//         requirePhase(SalePhase.Public)
//         checkSaleActive
//         checkPhaseLimit(nftAmount)
//         checkAndUpdateTotalMinted(nftAmount)
//     {
//         SaleConfig storage config = saleConfigs[SalePhase.Public];
//         if (msg.value != config.price * nftAmount) {
//             revert InvalidPrice();
//         }

//         mintCounts[SalePhase.Public][msg.sender] += uint32(nftAmount);
//         _mint(msg.sender, nftAmount * _unit());
//     }

//     function allowlistNFTMint(
//         uint256 nftAmount,
//         bytes32[] calldata proof
//     )
//         public
//         payable
//         onlyLive
//         checkSaleActive
//         checkPhaseLimit(nftAmount)
//         checkAndUpdateTotalMinted(nftAmount)
//     {
//         if (
//             currentPhase != SalePhase.OGList &&
//             currentPhase != SalePhase.WL1 &&
//             currentPhase != SalePhase.WL2
//         ) {
//             revert InvalidPhase();
//         }

//         SaleConfig storage config = saleConfigs[currentPhase];
//         if (msg.value != config.price * nftAmount) {
//             revert InvalidPrice();
//         }

//         bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
//         if (!MerkleProofLib.verify(proof, config.merkleRoot, leaf)) {
//             revert InvalidProof();
//         }

//         mintCounts[currentPhase][msg.sender] += uint32(nftAmount);
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
//             result = string(
//                 abi.encodePacked(_baseURI, LibString.toString(tokenId), ".json")
//             );
//         }
//     }

//     function supportsInterface(
//         bytes4 interfaceId
//     ) public view virtual returns (bool) {
//         return mirror.supportsInterface(interfaceId);
//     }
// }
