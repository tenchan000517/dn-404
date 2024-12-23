// SPDX-License-Identifier: MIT

pragma solidity >=0.8.17;

import {Base64} from "base64-sol/base64.sol";
import "contract-allow-list/contracts/ERC721AntiScam/restrictApprove/ERC721RestrictApprove.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {UpdatableOperatorFilterer} from "operator-filter-registry/src/UpdatableOperatorFilterer.sol";
import {RevokableDefaultOperatorFilterer} from "operator-filter-registry/src/RevokableDefaultOperatorFilterer.sol";

//tokenURI interface
interface iTokenURI {
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

//SBT interface
interface iSbtCollection {
    function externalMint(address _address, uint256 _amount) external payable;

    function balanceOf(address _owner) external view returns (uint);
}

struct PhaseConfig {
    uint96 cost;
    uint96 phaseMaxSupply;
    uint64 maxMintAmountPerTransaction;
    uint64 maxMintAmountPerAddress;
    bytes32 merkleRoot;
    bool onlyAllowlisted;
    bool isPaused;
    uint256 totalMinted;
    mapping(address => uint256) mintedAmount;
}

struct StateConfig {
    bool paused;
    bool mintCount;
    bool burnAndMintMode;
    bool mintWithSBT;
    bool isSBT;
    bool useInterfaceMetadata;
    bool useAnimationUrl;
}

contract TESTJAMDAO is
    RevokableDefaultOperatorFilterer,
    ERC2981,
    Ownable,
    ERC721RestrictApprove,
    AccessControl,
    ReentrancyGuard
{
    uint256 public currentPhase;
    mapping(uint256 => PhaseConfig) public phaseConfigs;

    StateConfig public stateConfig = StateConfig({
        paused: true,
        mintCount: true,
        burnAndMintMode: false,
        mintWithSBT: false,
        isSBT: false,
        useInterfaceMetadata: false,
        useAnimationUrl: false
    });
    
    constructor() ERC721Psi("TESTJAMDAO", "TEST") {
        //Role initialization
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        grantRole(MINTER_ROLE, msg.sender);
        grantRole(AIRDROP_ROLE, msg.sender);
        grantRole(ADMIN, msg.sender);

        // MintingConfig initialization
        PhaseConfig storage initialPhase = phaseConfigs[1];
        initialPhase.cost = 0;
        initialPhase.phaseMaxSupply = 200;
        initialPhase.maxMintAmountPerTransaction = 10;
        initialPhase.maxMintAmountPerAddress = 20;
        initialPhase.merkleRoot = bytes32(0);
        initialPhase.onlyAllowlisted = false;
        initialPhase.isPaused = false;

        setBaseURI("https://0xmavillain.com/data/metadata2/");

        //CAL initialization
        setCALLevel(1);
        _setCAL(0xdbaa28cBe70aF04EbFB166b1A3E8F8034e5B9FC7); //Ethereum mainnet proxy
        _addLocalContractAllowList(0x1E0049783F008A0085193E00003D00cd54003c71); //OpenSea
        _addLocalContractAllowList(0x4feE7B061C97C9c496b01DbcE9CDb10c02f0a0Be); //Rarible
        _addLocalContractAllowList(0x9A1D00bEd7CD04BCDA516d721A596eb22Aac6834); //

        //initial mint
        _safeMint(msg.sender, 1);

        //Royalty
        setDefaultRoyalty(0xDC68E2aF8816B3154c95dab301f7838c7D83A0Ba, 1000);
        setWithdrawAddress(0xDC68E2aF8816B3154c95dab301f7838c7D83A0Ba);
    }

    address public withdrawAddress = 0xB8c6AA7e3C7900a1E06A3808B8377Fd9B61Bf5d4;

    function setWithdrawAddress(address _withdrawAddress) public onlyOwner {
        withdrawAddress = _withdrawAddress;
    }

    function withdraw() public payable onlyOwner {
        (bool os, ) = payable(withdrawAddress).call{
            value: address(this).balance
        }("");
        require(os);
    }

    //
    //mint section
    //

    uint256 public maxSupply = 200;
    bool public paused = true;

    // bool public onlyAllowlisted = false;
    bool public mintCount = true;
    bool public burnAndMintMode = false;

    mapping(uint256 => mapping(address => uint256)) public userMintedAmount;

    bool public mintWithSBT = false;
    iSbtCollection public sbtCollection;

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract.");
        _;
    }

    //mint with merkle tree
    function mint(
        uint256 _mintAmount,
        uint256 _maxMintAmount,
        bytes32[] calldata _merkleProof,
        uint256 _burnId
    ) public payable callerIsUser {
        // Get current phase configuration
        PhaseConfig storage config = phaseConfigs[currentPhase];

        // Global state checks
        require(!stateConfig.paused, "the contract is paused");
        require(!config.isPaused, "current phase is paused");
        require(_mintAmount > 0, "need to mint at least 1 NFT");

        // Check mint limits
        require(
            _mintAmount <= config.maxMintAmountPerTransaction,
            "max mint amount per transaction exceeded"
        );

        // Check total supply limits
        require(
            (_nextTokenId() - 1) + _mintAmount <= maxSupply,
            "global max NFT limit exceeded"
        );
        require(
            config.totalMinted + _mintAmount <= config.phaseMaxSupply,
            "phase max NFT limit exceeded"
        );

        // Check payment
        require(config.cost * _mintAmount <= msg.value, "insufficient funds");

        // Handle allowlist checks if enabled
        if (config.onlyAllowlisted) {
            bytes32 leaf = keccak256(
                abi.encodePacked(msg.sender, _maxMintAmount)
            );
            require(
                MerkleProof.verify(_merkleProof, config.merkleRoot, leaf),
                "user is not allowlisted"
            );
            require(
                _mintAmount <= _maxMintAmount,
                "exceeds allowlist mint amount"
            );
        }

        // Check per-address mint limits if enabled
        if (stateConfig.mintCount) {
            require(
                _mintAmount <=
                    config.maxMintAmountPerAddress -
                        config.mintedAmount[msg.sender],
                "max NFT per address exceeded"
            );
            config.mintedAmount[msg.sender] += _mintAmount;
        }

        // Handle burn and mint mode if enabled
        if (stateConfig.burnAndMintMode) {
            require(
                _mintAmount == 1,
                "burn and mint mode only allows minting 1 NFT"
            );
            require(msg.sender == ownerOf(_burnId), "must own token to burn");
            _burn(_burnId);
        }

        // Handle SBT minting if enabled
        if (stateConfig.mintWithSBT) {
            if (sbtCollection.balanceOf(msg.sender) == 0) {
                sbtCollection.externalMint(msg.sender, 1);
            }
        }

        // Update total minted for phase
        config.totalMinted += _mintAmount;

        // Execute mint
        _safeMint(msg.sender, _mintAmount);
    }

    bytes32 public constant AIRDROP_ROLE = keccak256("AIRDROP_ROLE"); // override指定追加

    function airdropMint(
        address[] calldata _airdropAddresses,
        uint256[] calldata _UserMintAmount
    ) public {
        require(
            hasRole(AIRDROP_ROLE, msg.sender),
            "Caller is not a air dropper"
        );

        uint256 length = _airdropAddresses.length;
        require(
            length == _UserMintAmount.length,
            "Array lengths are different"
        );

        uint256 _mintAmount;
        uint256 nextId = _nextTokenId();

        // 最初のループでの総量計算
        for (uint256 i; i < length; ) {
            _mintAmount += _UserMintAmount[i];
            unchecked {
                ++i;
            }
        }

        require(0 < _mintAmount, "need to mint at least 1 NFT");
        require(
            (nextId - 1) + _mintAmount <= maxSupply,
            "max NFT limit exceeded"
        );

        // ミント処理のループ
        for (uint256 i; i < length; ) {
            _safeMint(_airdropAddresses[i], _UserMintAmount[i]);
            unchecked {
                ++i;
            }
        }
    }

    // フェーズ設定のセッター関数
    function setPhaseConfig(
        uint256 phaseId,
        uint96 cost,
        uint96 phaseMaxSupply,
        uint64 maxMintAmountPerTransaction,
        uint64 maxMintAmountPerAddress,
        bytes32 merkleRoot,
        bool onlyAllowlisted,
        bool isPaused
    ) public onlyRole(ADMIN) {
        PhaseConfig storage config = phaseConfigs[phaseId];
        config.cost = cost;
        config.phaseMaxSupply = phaseMaxSupply;
        config.maxMintAmountPerTransaction = maxMintAmountPerTransaction;
        config.maxMintAmountPerAddress = maxMintAmountPerAddress;
        config.merkleRoot = merkleRoot;
        config.onlyAllowlisted = onlyAllowlisted;
        config.isPaused = isPaused;
    }

    function setPhaseMaxSupply(
        uint256 phaseId,
        uint96 phaseMaxSupply
    ) public onlyRole(ADMIN) {
        PhaseConfig storage config = phaseConfigs[phaseId];

        // コントラクト全体の供給量との整合性を確認
        require(
            totalSupply() + phaseMaxSupply <= maxSupply,
            "Phase max supply exceeds global max supply"
        );

        // フェーズの maxSupply を更新
        config.phaseMaxSupply = phaseMaxSupply;
    }

    function setCurrentPhase(uint256 phaseId) public onlyRole(ADMIN) {
        require(
            phaseConfigs[phaseId].phaseMaxSupply > 0,
            "Phase not configured"
        );
        currentPhase = phaseId;
    }

    function setCost(uint96 _newCost) public onlyRole(ADMIN) {
        phaseConfigs[currentPhase].cost = _newCost;
    }

    function setMaxSupply(uint256 _maxSupply) public onlyRole(ADMIN) {
        maxSupply = _maxSupply;
    }

    function setOnlyAllowlisted(bool _state) public onlyRole(ADMIN) {
        phaseConfigs[currentPhase].onlyAllowlisted = _state;
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyRole(ADMIN) {
        phaseConfigs[currentPhase].merkleRoot = _merkleRoot;
    }

    function setPhaseMaxMintAmountPerAddress(
        uint256 phaseId,
        uint64 maxMintAmountPerAddress
    ) public onlyRole(ADMIN) {
        PhaseConfig storage config = phaseConfigs[phaseId];
        config.maxMintAmountPerAddress = maxMintAmountPerAddress;
    }

    function setPhaseMaxMintAmountPerTransaction(
        uint256 phaseId,
        uint64 maxMintAmountPerTransaction
    ) public onlyRole(ADMIN) {
        PhaseConfig storage config = phaseConfigs[phaseId];
        config.maxMintAmountPerTransaction = maxMintAmountPerTransaction;
    }

    function currentTokenId() public view returns (uint256) {
        return _nextTokenId() - 1;
    }

    function setMintWithSBT(bool _mintWithSBT) public onlyRole(ADMIN) {
        mintWithSBT = _mintWithSBT;
    }

    function setSbtCollection(address _address) public onlyRole(ADMIN) {
        sbtCollection = iSbtCollection(_address);
    }

    function setBurnAndMintMode(bool _burnAndMintMode) public onlyRole(ADMIN) {
        burnAndMintMode = _burnAndMintMode;
    }

    function setPause(bool _state) public onlyRole(ADMIN) {
        paused = _state;
    }

    function getUserMintedAmountByPhaseId(
        uint256 phaseId,
        address user
    ) public view returns (uint256) {
        return phaseConfigs[phaseId].mintedAmount[user];
    }

    function getUserMintedAmountCurrentPhase(
        address user
    ) public view returns (uint256) {
        return phaseConfigs[currentPhase].mintedAmount[user];
    }

    function setMintCount(bool _state) public onlyRole(ADMIN) {
        mintCount = _state;
    }

    //
    //URI section
    //

    string public baseURI;
    string public baseExtension = ".json";

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyRole(ADMIN) {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(
        string memory _newBaseExtension
    ) public onlyRole(ADMIN) {
        baseExtension = _newBaseExtension;
    }

    //
    //interface metadata
    //

    iTokenURI public interfaceOfTokenURI;
    bool public useInterfaceMetadata = false;

    function setInterfaceOfTokenURI(address _address) public onlyRole(ADMIN) {
        interfaceOfTokenURI = iTokenURI(_address);
    }

    function setUseInterfaceMetadata(
        bool _useInterfaceMetadata
    ) public onlyRole(ADMIN) {
        useInterfaceMetadata = _useInterfaceMetadata;
    }

    //
    //token URI
    //

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        // 外部インターフェースを使う場合
        if (useInterfaceMetadata == true) {
            return interfaceOfTokenURI.tokenURI(tokenId);
        }

        // デフォルトの外部URIを返す場合
        return
            string(
                abi.encodePacked(ERC721Psi.tokenURI(tokenId), baseExtension)
            );
    }

    //
    //burnin' section
    //

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    function externalMint(address _address, uint256 _amount) external payable {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        require(
            (_nextTokenId() - 1) + _amount <= maxSupply,
            "max NFT limit exceeded"
        );
        _safeMint(_address, _amount);
    }

    function externalBurn(
        uint256[] memory _burnTokenIds
    ) external nonReentrant {
        require(hasRole(BURNER_ROLE, msg.sender), "Caller is not a burner");
        for (uint256 i = 0; i < _burnTokenIds.length; i++) {
            uint256 tokenId = _burnTokenIds[i];
            require(tx.origin == ownerOf(tokenId), "Owner is different");
            _burn(tokenId);
        }
    }

    //
    //sbt and opensea filter section
    //

    bool public isSBT = false;

    function setIsSBT(bool _state) public onlyRole(ADMIN) {
        isSBT = _state;
    }

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        require(
            isSBT == false ||
                from == address(0) ||
                to == address(0) ||
                to == address(0x000000000000000000000000000000000000dEaD),
            "transfer is prohibited"
        );
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override onlyAllowedOperatorApproval(operator) {
        require(
            isSBT == false || approved == false,
            "setApprovalForAll is prohibited"
        );
        super.setApprovalForAll(operator, approved);
    }

    function approve(
        address operator,
        uint256 tokenId
    ) public virtual override onlyAllowedOperatorApproval(operator) {
        require(isSBT == false, "approve is prohibited");
        super.approve(operator, tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function owner()
        public
        view
        virtual
        override(Ownable, UpdatableOperatorFilterer)
        returns (address)
    {
        return Ownable.owner();
    }

    //
    //ERC721PsiAddressData section
    //

    // Mapping owner address to address data
    mapping(address => AddressData) _addressData;

    // Compiler will pack this into a single 256bit word.
    struct AddressData {
        // Realistically, 2**64-1 is more than enough.
        uint64 balance;
        // Keeps track of mint count with minimal overhead for tokenomics.
        uint64 numberMinted;
        // Keeps track of burn count with minimal overhead for tokenomics.
        uint64 numberBurned;
        // For miscellaneous variable(s) pertaining to the address
        // (e.g. number of whitelist mint slots used).
        // If there are multiple variables, please pack them into a uint64.
        uint64 aux;
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(
        address _owner
    ) public view virtual override returns (uint) {
        require(
            _owner != address(0),
            "ERC721Psi: balance query for the zero address"
        );
        return uint256(_addressData[_owner].balance);
    }

    /**
     * @dev Hook that is called after a set of serially-ordered token ids have been transferred. This includes
     * minting.
     *
     * startTokenId - the first token id to be transferred
     * quantity - the amount to be transferred
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     */
    function _afterTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        require(quantity < 2 ** 64);
        uint64 _quantity = uint64(quantity);

        if (from != address(0)) {
            _addressData[from].balance -= _quantity;
        } else {
            // Mint
            _addressData[to].numberMinted += _quantity;
        }

        if (to != address(0)) {
            _addressData[to].balance += _quantity;
        } else {
            // Burn
            _addressData[from].numberBurned += _quantity;
        }
        super._afterTokenTransfers(from, to, startTokenId, quantity);
    }

    //
    //ERC721AntiScam section
    //

    bytes32 public constant ADMIN = keccak256("ADMIN");

    function setEnebleRestrict(bool _enableRestrict) public onlyRole(ADMIN) {
        enableRestrict = _enableRestrict;
    }

    /*///////////////////////////////////////////////////////////////
                    OVERRIDES ERC721RestrictApprove
    //////////////////////////////////////////////////////////////*/
    function addLocalContractAllowList(
        address transferer
    ) external override onlyRole(ADMIN) {
        _addLocalContractAllowList(transferer);
    }

    function removeLocalContractAllowList(
        address transferer
    ) external override onlyRole(ADMIN) {
        _removeLocalContractAllowList(transferer);
    }

    function getLocalContractAllowList()
        external
        view
        override
        returns (address[] memory)
    {
        return _getLocalContractAllowList();
    }

    function setCALLevel(uint256 level) public override onlyRole(ADMIN) {
        CALLevel = level;
    }

    function setCAL(address calAddress) external override onlyRole(ADMIN) {
        _setCAL(calAddress);
    }

    //
    //setDefaultRoyalty
    //
    function setDefaultRoyalty(
        address _receiver,
        uint96 _feeNumerator
    ) public onlyOwner {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /*///////////////////////////////////////////////////////////////
                    OVERRIDES ERC721RestrictApprove
    //////////////////////////////////////////////////////////////*/
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC2981, ERC721RestrictApprove, AccessControl)
        returns (bool)
    {
        return
            ERC2981.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId) ||
            ERC721RestrictApprove.supportsInterface(interfaceId);
    }
}
