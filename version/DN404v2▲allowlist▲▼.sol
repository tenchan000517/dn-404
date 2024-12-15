// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.4;

// import "./DN404.sol";
// import "./ExtendedDN404Mirror.sol";
// import {Ownable} from "solady/src/auth/Ownable.sol";
// import {LibString} from "solady/src/utils/LibString.sol";
// import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
// import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// contract MAVILLAIN is DN404, AccessControl, Ownable, ReentrancyGuard {
//     // Constants at the top
//     bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
//     bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
//     bytes32 public constant AIRDROP_ROLE = keccak256("AIRDROP_ROLE");

//     string private constant TOKEN_NAME = "MUTANT ALIENS VILLAIN TOKEN";
//     string private constant TOKEN_SYMBOL = "$VLN";
//     string private constant NFT_NAME = "MUTANT ALIENS VILLAIN";
//     string private constant NFT_SYMBOL = "MAV";

//     // Error definitions
//     error InvalidAirdropParameters();
//     error BatchAirdropFailed();
//     error FractionalTransferNotAllowed();
//     error InvalidPhaseTransition(uint256 current, uint256 requested);
//     error InsufficientPayment(uint256 required, uint256 provided);
//     error MaxSupplyExceeded(uint256 requested, uint256 remaining);
//     error PhaseNotConfigured(uint256 phase);
//     error InvalidTimePeriod(uint256 startTime, uint256 endTime);
//     error InvalidProof(address user, bytes32 merkleRoot);
//     error PhaseNotActive(uint256 phase);
//     error PhasePaused(uint256 phase);
//     error ExceedsPhaseLimit(uint256 requested, uint256 allowed);
//     error InvalidMintRatio(uint256 oldRatio, uint256 newRatio);
//     error InvalidOperation(string reason);
//     error InvalidPrice();
//     error NotLive();
//     error PhaseAlreadyExists(uint256 phase);
//     error NotAllowlisted(address user);
//     error AllowlistAmountExceeded(uint256 requested, uint256 allowed);

//     struct PhaseConfig {
//         uint96 price;
//         uint32 maxPerWallet;
//         uint32 maxSupplyForPhase;
//         uint256 totalMinted;
//         bytes32 merkleRoot;
//         bool isConfigured;
//         bool isPaused;
//         bool requiresAllowlist;
//         uint256 allowlistType; // 0: Merkle Tree, 1: Mapping
//         mapping(address => uint256) allowlistUserAmount; // For mapping type
//         mapping(address => uint256) mintedAmount; // Track mints per user in this phase
//     }

//     // struct MintLimits {
//     //     uint32 maxPerPhase;
//     //     uint32 maxPerWallet;
//     //     uint32 maxPerTransaction;
//     // }

//     // struct SaleConfig {
//     //     uint96 price;
//     //     uint32 maxPerWallet;
//     //     bytes32 merkleRoot;
//     //     bool isConfigured;
//     //     bool isPaused;
//     // }

//     struct PhaseStatus {
//         bool isActive;
//         bool isPaused;
//         uint256 totalMinted;
//         uint96 price;
//         uint32 maxPerWallet;
//         uint32 maxSupplyForPhase;
//         bool requiresAllowlist;
//         uint256 allowlistType;
//         bytes32 merkleRoot;
//     }

//     // Events
//     event PhaseConfigured(
//         uint256 indexed phase,
//         uint96 price,
//         uint32 maxPerWallet,
//         uint32 maxSupplyForPhase,
//         bytes32 merkleRoot,
//         bool requiresAllowlist,
//         uint256 allowlistType
//     );
//     event AllowlistConfigured(
//         uint256 indexed phase,
//         address[] users,
//         uint256[] amounts
//     );
//     event AllowlistMintCompleted(
//         address indexed user,
//         uint256 amount,
//         bool isNFT,
//         uint256 phase
//     );
//     event PhaseUpdated(uint256 indexed oldPhase, uint256 indexed newPhase);
//     event MintCompleted(address indexed user, uint256 amount, bool isNFT);
//     event ConfigurationUpdated(string indexed parameter, uint256 newValue);
//     event EmergencyAction(string indexed action, uint256 timestamp);
//     event PhaseStatusChanged(uint256 indexed phase, bool isPaused);
//     event PhaseRemoved(uint256 indexed phase);
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

//     uint256 public currentPhase;
//     mapping(uint256 => PhaseConfig) public phaseConfigs;
//     mapping(uint256 => mapping(address => uint32)) public mintCounts;
//     mapping(uint256 => uint256) public phaseTotalMints;

//     uint32 public totalMinted;
//     uint32 public maxPerWallet = 20000;
//     uint32 public maxSupply = 20000;
//     uint256 private _mintRatio = 1000;
//     bool public live;

//     constructor(
//         // string memory name_,
//         // string memory symbol_,
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

//         // _name = name_;
//         // _symbol = symbol_;
//         CAL = contractAllowListProxy;

//         mirror = new ExtendedDN404Mirror(
//             msg.sender,
//             CAL, // Contract Allow List Proxy
//             initialWithdrawAddress, 
//             1000
//         );
//         _initializeDN404(
//             initialTokenSupply,
//             initialSupplyOwner,
//             address(mirror)
//         );
//     }

//     // ERC20 Core Functions
//     function name() public view override returns (string memory) {
//         return msg.sender == address(mirror) ? NFT_NAME : TOKEN_NAME;
//     }

//     function symbol() public view override returns (string memory) {
//         return msg.sender == address(mirror) ? NFT_SYMBOL : TOKEN_SYMBOL;
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

//     modifier validatePhase(uint256 phase) {
//         PhaseConfig storage config = phaseConfigs[phase];
//         if (!config.isConfigured) revert PhaseNotConfigured(phase);
//         if (config.isPaused) revert PhasePaused(phase);
//         _;
//     }

//     modifier validateMintRequest(
//         uint256 phase,
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

//         PhaseConfig storage config = phaseConfigs[phase];
//         if (config.maxSupplyForPhase > 0) {
//             uint256 newPhaseMinted;
//             unchecked {
//                 newPhaseMinted = phaseTotalMints[phase] + amount;
//             }
//             if (newPhaseMinted > config.maxSupplyForPhase)
//                 revert ExceedsPhaseLimit(
//                     amount,
//                     config.maxSupplyForPhase - phaseTotalMints[phase]
//                 );
//         }

//         _;

//         unchecked {
//             totalMinted = uint32(newTotalMinted);
//             phaseTotalMints[phase] += amount;
//         }
//     }

//     modifier validateMintLimit(uint256 phase, uint256 amount) {
//         PhaseConfig storage config = phaseConfigs[phase];
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
//             phaseConfigs[currentPhase].price,
//             tokenAmount
//         )
//         validateMintLimit(currentPhase, tokenAmount)
//         nonReentrant
//     {
//         PhaseConfig storage config = phaseConfigs[currentPhase];

//         if (config.requiresAllowlist) {
//             revert InvalidOperation("This phase requires allowlist");
//         }

//         uint256 mintAmount = tokenAmount * 10 ** decimals();
//         _mint(msg.sender, mintAmount);

//         unchecked {
//             config.totalMinted += tokenAmount; // フェーズごとの追跡を追加
//             totalMinted += uint32(tokenAmount);
//         }

//         emit MintCompleted(msg.sender, tokenAmount, false);
//     }

//     function allowlistMint(
//         uint256 tokenAmount,
//         bytes32[] calldata proof
//     )
//         public
//         payable
//         onlyLive
//         validatePhase(currentPhase)
//         validateMintLimit(currentPhase, tokenAmount)
//         nonReentrant
//     {
//         PhaseConfig storage config = phaseConfigs[currentPhase];

//         if (!config.requiresAllowlist) {
//             revert InvalidOperation("This phase does not require allowlist");
//         }

//         // Check allowlist based on type
//         if (config.allowlistType == 0) {
//             // Merkle Tree validation
//             bytes32 leaf = keccak256(abi.encodePacked(msg.sender, tokenAmount));
//             if (!MerkleProofLib.verify(proof, config.merkleRoot, leaf)) {
//                 revert InvalidProof(msg.sender, config.merkleRoot);
//             }
//         } else {
//             // Mapping validation
//             uint256 allowedAmount = config.allowlistUserAmount[msg.sender];
//             if (allowedAmount == 0) revert NotAllowlisted(msg.sender);

//             uint256 mintedAmount = config.mintedAmount[msg.sender];
//             if (mintedAmount + tokenAmount > allowedAmount) {
//                 revert AllowlistAmountExceeded(
//                     tokenAmount,
//                     allowedAmount - mintedAmount
//                 );
//             }
//             config.mintedAmount[msg.sender] += tokenAmount;
//         }

//         // Payment validation
//         if (msg.value < config.price * tokenAmount) {
//             revert InsufficientPayment(config.price * tokenAmount, msg.value);
//         }

//         // Supply validation
//         if (totalMinted + tokenAmount > maxSupply) {
//             revert MaxSupplyExceeded(tokenAmount, maxSupply - totalMinted);
//         }

//         // Mint tokens
//         uint256 mintAmount = tokenAmount * 10 ** decimals();
//         _mint(msg.sender, mintAmount);

//         unchecked {
//             config.totalMinted += tokenAmount; // フェーズごとのトータル
//             totalMinted += uint32(tokenAmount); // 全体のトータル
//         }

//         emit AllowlistMintCompleted(
//             msg.sender,
//             tokenAmount,
//             false,
//             currentPhase
//         );
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
//             phaseConfigs[currentPhase].price,
//             nftAmount
//         )
//         validateMintLimit(currentPhase, nftAmount)
//         nonReentrant
//     {
//         // nonReentrantを追加
//         PhaseConfig storage config = phaseConfigs[currentPhase];

//         if (config.requiresAllowlist) {
//             revert InvalidOperation("This phase requires allowlist");
//         }

//         _mint(msg.sender, nftAmount * _unit());

//         unchecked {
//             config.totalMinted += nftAmount; // フェーズごとの追跡を追加
//             totalMinted += uint32(nftAmount);
//         }

//         emit MintCompleted(msg.sender, nftAmount, true);
//     }

//     function allowlistMintNFT(
//         uint256 tokenAmount,
//         bytes32[] calldata proof
//     ) public payable onlyLive validatePhase(currentPhase) nonReentrant {
//         // nonReentrantを追加
//         PhaseConfig storage config = phaseConfigs[currentPhase];

//         if (!config.requiresAllowlist) {
//             revert InvalidOperation("This phase does not require allowlist");
//         }

//         // Allowlist validation (similar to above)
//         if (config.allowlistType == 0) {
//             bytes32 leaf = keccak256(abi.encodePacked(msg.sender, tokenAmount));
//             if (!MerkleProofLib.verify(proof, config.merkleRoot, leaf)) {
//                 revert InvalidProof(msg.sender, config.merkleRoot);
//             }
//         } else {
//             uint256 allowedAmount = config.allowlistUserAmount[msg.sender];
//             if (allowedAmount == 0) revert NotAllowlisted(msg.sender);

//             uint256 mintedAmount = config.mintedAmount[msg.sender];
//             if (mintedAmount + tokenAmount > allowedAmount) {
//                 revert AllowlistAmountExceeded(
//                     tokenAmount,
//                     allowedAmount - mintedAmount
//                 );
//             }
//             config.mintedAmount[msg.sender] += tokenAmount;
//         }

//         // Payment validation
//         if (msg.value < config.price * tokenAmount) {
//             revert InsufficientPayment(config.price * tokenAmount, msg.value);
//         }

//         // Supply validation
//         if (totalMinted + tokenAmount > maxSupply) {
//             revert MaxSupplyExceeded(tokenAmount, maxSupply - totalMinted);
//         }

//         // Mint NFTs
//         _mint(msg.sender, tokenAmount * _unit());

//         unchecked {
//             config.totalMinted += tokenAmount; // フェーズごとの追跡を追加
//             totalMinted += uint32(tokenAmount);
//         }
//         emit AllowlistMintCompleted(
//             msg.sender,
//             tokenAmount,
//             true,
//             currentPhase
//         );
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
//     function setPhase(uint256 newPhase) external onlyRole(ADMIN_ROLE) {
//         if (!phaseConfigs[newPhase].isConfigured)
//             revert PhaseNotConfigured(newPhase);

//         uint256 oldPhase = currentPhase;
//         currentPhase = newPhase;
//         emit PhaseUpdated(oldPhase, newPhase);
//     }

//     function configurePhase(
//         uint256 phase,
//         uint96 price,
//         uint32 phaseMaxPerWallet,
//         uint32 maxSupplyForPhase,
//         bytes32 merkleRoot,
//         bool requiresAllowlist,
//         uint256 allowlistType
//     ) external onlyRole(ADMIN_ROLE) {
//         PhaseConfig storage config = phaseConfigs[phase];
//         if (config.isConfigured) revert PhaseAlreadyExists(phase);

//         require(allowlistType <= 1, "Invalid allowlist type");

//         config.price = price;
//         config.maxPerWallet = phaseMaxPerWallet;
//         config.maxSupplyForPhase = maxSupplyForPhase;
//         config.merkleRoot = merkleRoot;
//         config.requiresAllowlist = requiresAllowlist;
//         config.allowlistType = allowlistType;
//         config.isConfigured = true;

//         emit PhaseConfigured(
//             phase,
//             price,
//             phaseMaxPerWallet,
//             maxSupplyForPhase,
//             merkleRoot,
//             requiresAllowlist,
//             allowlistType
//         );
//     }

//     function setAllowlistMapping(
//         uint256 phase,
//         address[] calldata users,
//         uint256[] calldata amounts
//     ) external onlyRole(ADMIN_ROLE) {
//         require(users.length == amounts.length, "Length mismatch");
//         PhaseConfig storage config = phaseConfigs[phase];
//         require(config.isConfigured, "Phase not configured");
//         require(config.allowlistType == 1, "Invalid allowlist type");

//         for (uint256 i = 0; i < users.length; i++) {
//             config.allowlistUserAmount[users[i]] = amounts[i];
//         }

//         emit AllowlistConfigured(phase, users, amounts);
//     }

//     function resetPhaseConfig(uint256 phase) external onlyRole(ADMIN_ROLE) {
//         delete phaseConfigs[phase];
//         emit PhaseRemoved(phase);
//     }

//     function togglePhase(uint256 phase) external onlyRole(ADMIN_ROLE) {
//         PhaseConfig storage config = phaseConfigs[phase];
//         if (!config.isConfigured) revert PhaseNotConfigured(phase);

//         config.isPaused = !config.isPaused;
//         emit PhaseStatusChanged(phase, config.isPaused);
//     }

//     function setBaseURI(
//         string calldata baseURI_
//     ) external onlyRole(ADMIN_ROLE) {
//         _baseURI = baseURI_;
//     }

//     function setPhasePrice(
//         uint256 phase,
//         uint96 newPrice
//     ) external onlyRole(ADMIN_ROLE) {
//         if (!phaseConfigs[phase].isConfigured) revert PhaseNotConfigured(phase);
//         phaseConfigs[phase].price = newPrice;
//         emit ConfigurationUpdated(
//             string(abi.encodePacked("price_phase_", LibString.toString(phase))),
//             newPrice
//         );
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

//     function setPhaseMaxPerWallet(
//         uint256 phase,
//         uint32 newMaxPerWallet
//     ) external onlyRole(ADMIN_ROLE) {
//         if (!phaseConfigs[phase].isConfigured) revert PhaseNotConfigured(phase);
//         phaseConfigs[phase].maxPerWallet = newMaxPerWallet;
//         emit ConfigurationUpdated(
//             string(
//                 abi.encodePacked(
//                     "maxPerWallet_phase_",
//                     LibString.toString(phase)
//                 )
//             ),
//             newMaxPerWallet
//         );
//     }

//     function setMaxSupply(uint32 _maxSupply) external onlyRole(ADMIN_ROLE) {
//         if (_maxSupply < totalMinted)
//             revert InvalidOperation("New max supply below total minted");
//         maxSupply = _maxSupply;
//         emit ConfigurationUpdated("maxSupply", _maxSupply);
//     }

//     function setPhaseMaxSupply(
//         uint256 phase,
//         uint32 newMaxSupply
//     ) external onlyRole(ADMIN_ROLE) {
//         if (!phaseConfigs[phase].isConfigured) revert PhaseNotConfigured(phase);
//         if (newMaxSupply < phaseTotalMints[phase])
//             revert InvalidOperation(
//                 "New phase max supply below phase total minted"
//             );
//         phaseConfigs[phase].maxSupplyForPhase = newMaxSupply;
//         emit ConfigurationUpdated(
//             string(
//                 abi.encodePacked("maxSupply_phase_", LibString.toString(phase))
//             ),
//             newMaxSupply
//         );
//     }

//     function toggleLive() external onlyRole(ADMIN_ROLE) {
//         live = !live;
//     }

//     function setMerkleRoot(
//         uint256 phase,
//         bytes32 newRoot
//     ) external onlyRole(ADMIN_ROLE) {
//         if (!phaseConfigs[phase].isConfigured) revert PhaseNotConfigured(phase);
//         if (!phaseConfigs[phase].requiresAllowlist)
//             revert InvalidOperation("Phase does not require allowlist");
//         phaseConfigs[phase].merkleRoot = newRoot;
//         emit ConfigurationUpdated(
//             string(
//                 abi.encodePacked("merkleRoot_phase_", LibString.toString(phase))
//             ),
//             uint256(newRoot)
//         );
//     }

//     // View functions
//     function getMerkleRoot(uint256 phase) external view returns (bytes32) {
//         if (!phaseConfigs[phase].isConfigured) revert PhaseNotConfigured(phase);
//         if (!phaseConfigs[phase].requiresAllowlist)
//             revert InvalidOperation("Phase does not require allowlist");
//         return phaseConfigs[phase].merkleRoot;
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

//     function getAllowlistMintedAmount(
//         uint256 phase,
//         address user
//     ) external view returns (uint256) {
//         return phaseConfigs[phase].mintedAmount[user];
//     }

//     function getAllowlistUserAmount(
//         uint256 phase,
//         address user
//     ) external view returns (uint256) {
//         return phaseConfigs[phase].allowlistUserAmount[user];
//     }

//     function getPhaseStatus(
//         uint256 phase
//     ) external view returns (PhaseStatus memory) {
//         PhaseConfig storage config = phaseConfigs[phase];
//         return
//             PhaseStatus({
//                 isActive: config.isConfigured,
//                 isPaused: config.isPaused,
//                 totalMinted: getTotalMintedInPhase(phase),
//                 price: config.price,
//                 maxPerWallet: config.maxPerWallet,
//                 maxSupplyForPhase: config.maxSupplyForPhase,
//                 requiresAllowlist: config.requiresAllowlist,
//                 allowlistType: config.allowlistType,
//                 merkleRoot: config.merkleRoot
//             });
//     }

//     // Internal functions
//     function getTotalMintedInPhase(
//         uint256 phase
//     ) internal view returns (uint256) {
//         PhaseConfig storage config = phaseConfigs[phase];
//         return config.totalMinted;
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
