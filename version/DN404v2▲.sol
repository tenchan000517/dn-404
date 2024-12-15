// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.4;

// import "./DN404.sol";
// import "./ExtendedDN404Mirror.sol";
// import {Ownable} from "solady/src/auth/Ownable.sol";
// import {LibString} from "solady/src/utils/LibString.sol";
// import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
// import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";

// contract MAVILLAIN is DN404, AccessControl, Ownable {
//     // Constants at the top
//     bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
//     bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
//     bytes32 public constant AIRDROP_ROLE = keccak256("AIRDROP_ROLE");

//     // Error definitions
//     error InvalidAirdropParameters();
//     error BatchAirdropFailed();
//     error FractionalTransferNotAllowed();
//     error InvalidPhaseTransition(SalePhase current, SalePhase requested);
//     error InsufficientPayment(uint256 required, uint256 provided);
//     error MaxSupplyExceeded(uint256 requested, uint256 remaining);
//     error PhaseNotConfigured(SalePhase phase);
//     error InvalidTimePeriod(uint256 startTime, uint256 endTime);
//     error OverlappingPhases(SalePhase phase1, SalePhase phase2);
//     error SaleConfigAlreadyExists(SalePhase phase);
//     error InvalidProof(address user, bytes32 merkleRoot);
//     error PhaseNotActive(SalePhase phase);
//     error PhasePaused(SalePhase phase);
//     error ExceedsPhaseLimit(uint256 requested, uint256 allowed);
//     error InvalidMintRatio(uint256 oldRatio, uint256 newRatio);
//     error InvalidOperation(string reason);
//     error InvalidPrice();
//     error TotalSupplyReached();
//     error NotLive();

//     enum SalePhase {
//         NotStarted,
//         OGList,
//         WL1,
//         WL2,
//         Public,
//         Ended
//     }

//     struct MintLimits {
//         uint32 maxPerPhase;
//         uint32 maxPerWallet;
//         uint32 maxPerTransaction;
//     }

//     struct SaleConfig {
//         uint96 price;
//         uint32 maxPerWallet;
//         bytes32 merkleRoot;
//         bool isConfigured;
//         bool isPaused;
//     }

//     struct PhaseStatus {
//         bool isActive;
//         bool isPaused;
//         uint256 totalMinted;
//     }

//     // Events
//     event PhaseConfigured(
//         SalePhase indexed phase,
//         uint96 price,
//         uint32 maxPerWallet,
//         bytes32 merkleRoot
//     );
//     event SalePhaseUpdated(
//         SalePhase indexed oldPhase,
//         SalePhase indexed newPhase
//     );
//     event MintCompleted(address indexed user, uint256 amount, bool isNFT);
//     event ConfigurationUpdated(string indexed parameter, uint256 newValue);
//     event EmergencyAction(string indexed action, uint256 timestamp);
//     event PhaseStatusChanged(SalePhase indexed phase, bool isPaused);
//     event SaleConfigRemoved(SalePhase indexed phase);
//     event AirdropCompleted(
//         address indexed recipient,
//         uint256 amount,
//         bool isNFT
//     );
//     event BatchAirdropCompleted(
//         address[] recipients,
//         uint256[] amounts,
//         bool isNFT
//     );
//     event ExternalMintCompleted(
//         address indexed recipient,
//         uint256 amount,
//         bool isNFT
//     );

//     // Immutable state variables
//     address public immutable CAL;
//     ExtendedDN404Mirror public immutable mirror;

//     // Storage variables
//     address public withdrawAddress;
//     string private _name;
//     string private _symbol;
//     string private _baseURI;

//     SalePhase public currentPhase;
//     mapping(SalePhase => SaleConfig) public saleConfigs;
//     mapping(SalePhase => mapping(address => uint32)) public mintCounts;
//     mapping(SalePhase => uint256) public phaseTotalMints;
//     mapping(SalePhase => MintLimits) public phaseMintLimits;

//     uint32 public totalMinted;
//     uint32 public maxPerWallet = 20000;
//     uint32 public maxSupply = 20000;
//     uint256 private _mintRatio = 1000;
//     bool public live;

//     constructor(
//         string memory name_,
//         string memory symbol_,
//         bytes32 allowlistRoot_,
//         uint96 publicPrice_,
//         uint96 allowlistPrice_,
//         uint96 initialTokenSupply,
//         address initialSupplyOwner,
//         address contractAllowListProxy,
//         address initialWithdrawAddress
//     ) {
//         _initializeOwner(msg.sender);
//         _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
//         _setupRole(ADMIN_ROLE, msg.sender);
//         _setupRole(MINTER_ROLE, msg.sender);
//         _setupRole(AIRDROP_ROLE, msg.sender);

//         withdrawAddress = initialWithdrawAddress;

//         _name = name_;
//         _symbol = symbol_;
//         CAL = contractAllowListProxy;

//         // Public phase configuration
//         SaleConfig storage publicConfig = saleConfigs[SalePhase.Public];
//         publicConfig.price = publicPrice_;
//         publicConfig.maxPerWallet = maxPerWallet;
//         publicConfig.isConfigured = true;

//         // Allowlist phase configuration
//         SaleConfig storage allowlistConfig = saleConfigs[SalePhase.WL1];
//         allowlistConfig.price = allowlistPrice_;
//         allowlistConfig.maxPerWallet = maxPerWallet;
//         allowlistConfig.merkleRoot = allowlistRoot_;
//         allowlistConfig.isConfigured = true;

//         mirror = new ExtendedDN404Mirror(
//             msg.sender, // デプロイ者
//             CAL, // Contract Allow List Proxy
//             initialWithdrawAddress, // デフォルトロイヤリティ受取人
//             1000 // デフォルトロイヤリティ手数料
//         );
//         _initializeDN404(
//             initialTokenSupply,
//             initialSupplyOwner,
//             address(mirror)
//         );
//     }

//     // ERC20 Core Functions
//     function name() public view override returns (string memory) {
//         return _name;
//     }

//     function symbol() public view override returns (string memory) {
//         return _symbol;
//     }

//     // Interface support
//     function supportsInterface(
//         bytes4 interfaceId
//     ) public view virtual override(AccessControl) returns (bool) {
//         // ERC20インターフェースの明示的サポート
//         if (interfaceId == 0x36372b07) {
//             // ERC20 interface id
//             return true;
//         }
//         // IERC165のサポート
//         if (interfaceId == 0x01ffc9a7) {
//             return true;
//         }
//         // ERC721はミラーで処理
//         if (interfaceId == 0x80ac58cd) {
//             return false;
//         }
//         // AccessControlのサポート
//         return AccessControl.supportsInterface(interfaceId);
//     }

//     // Internal functions
//     function _unit() internal view override returns (uint256) {
//         return _mintRatio * 10 ** decimals();
//     }

//     // function _beforeTokenTransfer(
//     //     address from,
//     //     address to,
//     //     uint256 amount
//     // ) internal virtual override {
//     //     super._beforeTokenTransfer(from, to, amount);
//     // }

//     // Modifiers
//     modifier onlyAdmin() {
//         require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
//         _;
//     }

//     modifier onlyLive() {
//         if (!live) revert NotLive();
//         _;
//     }

//     modifier validatePhase(SalePhase phase) {
//         SaleConfig storage config = saleConfigs[phase];
//         if (!config.isConfigured) revert PhaseNotConfigured(phase);
//         if (config.isPaused) revert PhasePaused(phase);
//         _;
//     }

//     modifier validateMintRequest(
//         SalePhase phase,
//         uint256 price,
//         uint256 amount
//     ) {
//         if (price * amount != msg.value) revert InvalidPrice();

//         uint256 newTotalMinted;
//         unchecked {
//             newTotalMinted = totalMinted + amount;
//         }
//         if (newTotalMinted > maxSupply)
//             revert MaxSupplyExceeded(amount, maxSupply - totalMinted);

//         MintLimits storage limits = phaseMintLimits[phase];
//         if (limits.maxPerPhase > 0) {
//             uint256 newPhaseMinted;
//             unchecked {
//                 newPhaseMinted = phaseTotalMints[phase] + amount;
//             }
//             if (newPhaseMinted > limits.maxPerPhase)
//                 revert ExceedsPhaseLimit(
//                     amount,
//                     limits.maxPerPhase - phaseTotalMints[phase]
//                 );
//         }

//         _;

//         unchecked {
//             totalMinted = uint32(newTotalMinted);
//             phaseTotalMints[phase] += amount;
//         }
//     }

//     modifier validateMintLimit(SalePhase phase, uint256 amount) {
//         SaleConfig storage config = saleConfigs[phase];
//         uint256 currentPhaseMintCount = mintCounts[phase][msg.sender];
//         uint256 newPhaseMintCount;
//         unchecked {
//             newPhaseMintCount = currentPhaseMintCount + amount;
//         }
//         if (newPhaseMintCount > config.maxPerWallet) {
//             revert ExceedsPhaseLimit(newPhaseMintCount, config.maxPerWallet);
//         }

//         uint256 currentTotalMintCount = _getAux(msg.sender);
//         uint256 newTotalMintCount;
//         unchecked {
//             newTotalMintCount = currentTotalMintCount + amount;
//         }
//         if (newTotalMintCount > maxPerWallet) {
//             revert ExceedsPhaseLimit(newTotalMintCount, maxPerWallet);
//         }

//         _;

//         unchecked {
//             mintCounts[phase][msg.sender] = uint32(newPhaseMintCount);
//             _setAux(msg.sender, uint88(newTotalMintCount));
//         }
//     }

//     // Public minting functions
//     function mint(
//         uint256 tokenAmount
//     )
//         public
//         payable
//         onlyLive
//         validatePhase(currentPhase)
//         validateMintRequest(
//             currentPhase,
//             saleConfigs[currentPhase].price, // 修正: 現在のフェーズの価格を使用
//             tokenAmount
//         )
//         validateMintLimit(currentPhase, tokenAmount)
//     {
//         uint256 mintAmount = tokenAmount * 10 ** decimals();
//         _mint(msg.sender, mintAmount);
//         emit MintCompleted(msg.sender, tokenAmount, false);
//     }

//     function allowlistMint(
//         uint256 tokenAmount,
//         bytes32[] calldata proof
//     )
//         public
//         payable
//         onlyLive
//         validatePhase(SalePhase.WL1)
//         validateMintRequest(
//             SalePhase.WL1,
//             saleConfigs[SalePhase.WL1].price,
//             tokenAmount
//         )
//         validateMintLimit(SalePhase.WL1, tokenAmount)
//     {
//         if (
//             !MerkleProofLib.verify(
//                 proof,
//                 saleConfigs[SalePhase.WL1].merkleRoot,
//                 keccak256(abi.encodePacked(msg.sender))
//             )
//         ) {
//             revert InvalidProof(
//                 msg.sender,
//                 saleConfigs[SalePhase.WL1].merkleRoot
//             );
//         }

//         uint256 mintAmount = tokenAmount * 10 ** decimals();
//         _mint(msg.sender, mintAmount);
//         emit MintCompleted(msg.sender, tokenAmount, false);
//     }

//     function mintNFT(
//         uint256 nftAmount
//     )
//         public
//         payable
//         onlyLive
//         validatePhase(currentPhase)
//         validateMintRequest(
//             currentPhase,
//             saleConfigs[currentPhase].price, // 修正: 現在のフェーズの価格を使用
//             nftAmount
//         )
//         validateMintLimit(currentPhase, nftAmount)
//     {
//         _mint(msg.sender, nftAmount * _unit());
//         emit MintCompleted(msg.sender, nftAmount, true);
//     }

//     function allowlistNFTMint(
//         uint256 nftAmount,
//         bytes32[] calldata proof
//     )
//         public
//         payable
//         onlyLive
//         validatePhase(SalePhase.WL1)
//         validateMintRequest(
//             SalePhase.WL1,
//             saleConfigs[SalePhase.WL1].price,
//             nftAmount
//         )
//         validateMintLimit(SalePhase.WL1, nftAmount)
//     {
//         if (
//             !MerkleProofLib.verify(
//                 proof,
//                 saleConfigs[SalePhase.WL1].merkleRoot,
//                 keccak256(abi.encodePacked(msg.sender))
//             )
//         ) {
//             revert InvalidProof(
//                 msg.sender,
//                 saleConfigs[SalePhase.WL1].merkleRoot
//             );
//         }

//         _mint(msg.sender, nftAmount * _unit());
//         emit MintCompleted(msg.sender, nftAmount, true);
//     }

//     // Airdrop functions
//     function airdrop(
//         address recipient,
//         uint256 amount,
//         bool isNFT
//     ) external onlyRole(AIRDROP_ROLE) {
//         if (recipient == address(0) || amount == 0)
//             revert InvalidAirdropParameters();

//         uint256 mintAmount = isNFT
//             ? amount * _unit()
//             : amount * 10 ** decimals();
//         _mint(recipient, mintAmount);

//         emit AirdropCompleted(recipient, amount, isNFT);
//     }

//     function batchAirdrop(
//         address[] calldata recipients,
//         uint256[] calldata amounts,
//         bool isNFT
//     ) external onlyRole(AIRDROP_ROLE) {
//         if (recipients.length != amounts.length || recipients.length == 0)
//             revert InvalidAirdropParameters();

//         for (uint256 i = 0; i < recipients.length; i++) {
//             if (recipients[i] == address(0)) revert InvalidAirdropParameters();

//             uint256 mintAmount = isNFT
//                 ? amounts[i] * _unit()
//                 : amounts[i] * 10 ** decimals();
//             _mint(recipients[i], mintAmount);
//         }

//         emit BatchAirdropCompleted(recipients, amounts, isNFT);
//     }

//     function externalMint(
//         address recipient,
//         uint256 amount,
//         bool isNFT
//     ) external onlyRole(MINTER_ROLE) {
//         if (recipient == address(0) || amount == 0)
//             revert InvalidAirdropParameters();

//         uint256 mintAmount = isNFT
//             ? amount * _unit()
//             : amount * 10 ** decimals();
//         _mint(recipient, mintAmount);

//         emit ExternalMintCompleted(recipient, amount, isNFT);
//     }

//     // Admin functions
//     function setPhase(SalePhase newPhase) external onlyRole(ADMIN_ROLE) {
//         if (!saleConfigs[newPhase].isConfigured)
//             revert PhaseNotConfigured(newPhase);

//         SalePhase oldPhase = currentPhase;
//         currentPhase = newPhase;
//         emit SalePhaseUpdated(oldPhase, newPhase);
//     }

//     function configurePhase(
//         SalePhase phase,
//         uint96 price,
//         uint32 phaseMaxPerWallet,
//         bytes32 merkleRoot
//     ) external onlyRole(ADMIN_ROLE) {
//         SaleConfig storage config = saleConfigs[phase];

//         config.price = price;
//         config.maxPerWallet = phaseMaxPerWallet;
//         if (phase != SalePhase.Public) {
//             config.merkleRoot = merkleRoot;
//         }
//         config.isConfigured = true;

//         emit PhaseConfigured(phase, price, phaseMaxPerWallet, merkleRoot);
//     }

//     function resetPhaseConfig(SalePhase phase) external onlyRole(ADMIN_ROLE) {
//         delete saleConfigs[phase];
//         emit SaleConfigRemoved(phase);
//     }

//     function togglePhase(SalePhase phase) external onlyRole(ADMIN_ROLE) {
//         SaleConfig storage config = saleConfigs[phase];
//         config.isPaused = !config.isPaused;
//         emit PhaseStatusChanged(phase, config.isPaused);
//     }

//     function setBaseURI(
//         string calldata baseURI_
//     ) external onlyRole(ADMIN_ROLE) {
//         _baseURI = baseURI_;
//     }

//     function setPrices(
//         uint96 publicPrice_,
//         uint96 allowlistPrice_
//     ) external onlyRole(ADMIN_ROLE) {
//         saleConfigs[SalePhase.Public].price = publicPrice_;
//         saleConfigs[SalePhase.WL1].price = allowlistPrice_;
//     }

//     function setMintRatio(uint256 newRatio) external onlyRole(ADMIN_ROLE) {
//         if (newRatio == 0) revert InvalidMintRatio(_mintRatio, newRatio);
//         _mintRatio = newRatio;
//         emit ConfigurationUpdated("mintRatio", newRatio);
//     }

//     function setMaxPerWallet(
//         uint32 _maxPerWallet
//     ) external onlyRole(ADMIN_ROLE) {
//         maxPerWallet = _maxPerWallet;
//         emit ConfigurationUpdated("maxPerWallet", _maxPerWallet);
//     }

//     function setMaxSupply(uint32 _maxSupply) external onlyRole(ADMIN_ROLE) {
//         if (_maxSupply < totalMinted)
//             revert InvalidOperation("New max supply below total minted");
//         maxSupply = _maxSupply;
//         emit ConfigurationUpdated("maxSupply", _maxSupply);
//     }

//     function toggleLive() external onlyRole(ADMIN_ROLE) {
//         live = !live;
//     }

//     function setAllowlistRoot(bytes32 newRoot) external onlyRole(ADMIN_ROLE) {
//         saleConfigs[SalePhase.WL1].merkleRoot = newRoot;
//     }

//     // View functions
//     function getAllowlistRoot() external view returns (bytes32) {
//         return saleConfigs[SalePhase.WL1].merkleRoot;
//     }

//     function tokenURI(
//         uint256 tokenId
//     ) public view override returns (string memory result) {
//         if (bytes(_baseURI).length != 0) {
//             result = string(
//                 abi.encodePacked(_baseURI, LibString.toString(tokenId), ".json")
//             );
//         }
//     }

//     function getNextTokenId() public view returns (uint32) {
//         DN404Storage storage $ = _getDN404Storage();
//         return $.nextTokenId;
//     }

//     function getPhaseStatus(
//         SalePhase phase
//     ) external view returns (PhaseStatus memory) {
//         SaleConfig storage config = saleConfigs[phase];
//         return
//             PhaseStatus({
//                 isActive: config.isConfigured,
//                 isPaused: config.isPaused,
//                 totalMinted: phaseTotalMints[phase]
//             });
//     }

//     // Withdrawal functions
//     function withdraw() external onlyOwner {
//         require(withdrawAddress != address(0), "Withdraw address not set");
//         SafeTransferLib.safeTransferAllETH(withdrawAddress);
//         emit EmergencyAction("withdraw", block.timestamp);
//     }

//     function setWithdrawAddress(address _withdrawAddress) public onlyOwner {
//         require(_withdrawAddress != address(0), "Invalid address");
//         withdrawAddress = _withdrawAddress;
//     }

//     function getWithdrawAddress() public view returns (address) {
//         return withdrawAddress;
//     }

//     // Emergency functions
//     function emergencyPause() external onlyRole(ADMIN_ROLE) {
//         live = false;
//         emit EmergencyAction("pause", block.timestamp);
//     }
// }
