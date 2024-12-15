// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {RevokableDefaultOperatorFilterer} from "operator-filter-registry/src/RevokableDefaultOperatorFilterer.sol";
import {UpdatableOperatorFilterer} from "operator-filter-registry/src/UpdatableOperatorFilterer.sol";

// Interface for external token URI
interface ITokenURI {
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

// Interface for external minting
interface IExternalMint {
    function externalMint(address to, uint256 id, uint256 amount) external;
}

contract CustomERC1155 is
    RevokableDefaultOperatorFilterer,
    ERC1155,
    ERC2981,
    Ownable,
    AccessControl
{
    using Strings for uint256;

    // Basic token info
    string public name;
    string public symbol;
    mapping(uint256 => string) public tokenURIs;

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant AIRDROP_ROLE = keccak256("AIRDROP_ROLE");

    // Phase structure
    struct TokenConfig {
        bool isActive;
        uint256 maxSupply;
        uint256 totalSupply;
    }

    struct Phase {
        uint256 cost;
        uint256 maxMintAmountPerTransaction;
        bytes32 merkleRoot;
        mapping(uint256 => TokenConfig) tokenConfigs;
        mapping(address => mapping(uint256 => uint256)) userMintedAmount;
    }

    struct TokenConfigInput {
        uint256 tokenId;
        uint256 maxSupply;
    }

    // Phase management
    uint256 public currentPhaseId;
    mapping(uint256 => Phase) public phases;

    // Minting controls
    bool public paused = true;
    bool public onlyAllowlisted = true;
    uint256 public publicSaleMaxMintAmountPerAddress = 1;

    // SBT functionality
    bool public isSBT = false;

    // Interface metadata
    ITokenURI public interfaceOfTokenURI;
    bool public useInterfaceMetadata = false;

    // URI management
    bool public useBaseURI = false;
    string public baseURI;
    string public baseExtension = ".json";

    // Withdrawal
    address public withdrawAddress;

    struct InitialConfig {
        // Basic token info
        string name;
        string symbol;
        address withdrawAddress;
        // Phase configuration
        uint256 maxSupply;
        uint256 cost;
        uint256 maxMintAmountPerTransaction;
        bytes32 merkleRoot;
        // Control flags
        bool paused;
        bool onlyAllowlisted;
        bool isSBT;
        uint256 publicSaleMaxMintAmountPerAddress;
        // Metadata configuration
        bool useInterfaceMetadata;
        bool useBaseURI;
        string baseURI;
        string baseExtension;
        // Royalty configuration
        address royaltyReceiver;
        uint96 royaltyFeeNumerator;
    }

    constructor(InitialConfig memory config) ERC1155("") {
        // Basic token info
        name = config.name;
        symbol = config.symbol;
        withdrawAddress = config.withdrawAddress;

        // Setup roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(AIRDROP_ROLE, msg.sender);

        // Set initial phase
        Phase storage phase = phases[0];
        phase.cost = config.cost;
        phase.maxMintAmountPerTransaction = config.maxMintAmountPerTransaction;
        phase.merkleRoot = config.merkleRoot;
        phase.tokenConfigs[1].isActive = true;
        phase.tokenConfigs[1].maxSupply = config.maxSupply;

        // Set control flags
        paused = config.paused;
        onlyAllowlisted = config.onlyAllowlisted;
        isSBT = config.isSBT;
        publicSaleMaxMintAmountPerAddress = config
            .publicSaleMaxMintAmountPerAddress;

        // Set metadata configuration
        useBaseURI = config.useBaseURI;
        baseURI = config.baseURI;
        baseExtension = config.baseExtension;
        useInterfaceMetadata = config.useInterfaceMetadata;

        // Set royalty configuration
        _setDefaultRoyalty(config.royaltyReceiver, config.royaltyFeeNumerator);
    }

    // Modifiers
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    // Phase Management Functions
    function setPhaseTokenConfigs(
        uint256 _phaseId,
        TokenConfigInput[] calldata _tokenConfigs,
        uint256 _cost,
        uint256 _maxMintAmountPerTransaction,
        bytes32 _merkleRoot
    ) external onlyRole(ADMIN_ROLE) {
        Phase storage phase = phases[_phaseId];
        phase.cost = _cost;
        phase.maxMintAmountPerTransaction = _maxMintAmountPerTransaction;
        phase.merkleRoot = _merkleRoot;

        for (uint256 i = 0; i < _tokenConfigs.length; i++) {
            phase.tokenConfigs[_tokenConfigs[i].tokenId].isActive = true;
            phase
                .tokenConfigs[_tokenConfigs[i].tokenId]
                .maxSupply = _tokenConfigs[i].maxSupply;
        }
    }

    function deactivateTokenInPhase(
        uint256 _phaseId,
        uint256 _tokenId
    ) external onlyRole(ADMIN_ROLE) {
        phases[_phaseId].tokenConfigs[_tokenId].isActive = false;
    }

    function activateTokenInPhase(
        uint256 _phaseId,
        uint256 _tokenId
    ) external onlyRole(ADMIN_ROLE) {
        phases[_phaseId].tokenConfigs[_tokenId].isActive = true;
    }

    function setCurrentPhaseId(uint256 _phaseId) external onlyRole(ADMIN_ROLE) {
        currentPhaseId = _phaseId;
    }

    // Minting Functions
    function mint(
        uint256 _tokenId,
        uint256 _mintAmount,
        uint256 _maxMintAmount,
        bytes32[] calldata _merkleProof
    ) external payable callerIsUser {
        require(!paused, "Minting is paused");
        require(_mintAmount > 0, "Must mint at least 1");

        Phase storage phase = phases[currentPhaseId];
        TokenConfig storage tokenConfig = phase.tokenConfigs[_tokenId];

        require(tokenConfig.isActive, "Token not active in current phase");
        require(
            tokenConfig.totalSupply + _mintAmount <= tokenConfig.maxSupply,
            "Exceeds max supply for token"
        );
        require(
            _mintAmount <= phase.maxMintAmountPerTransaction,
            "Exceeds max mint per transaction"
        );
        require(msg.value >= phase.cost * _mintAmount, "Insufficient payment");

        if (onlyAllowlisted) {
            bytes32 leaf = keccak256(
                abi.encodePacked(msg.sender, _maxMintAmount)
            );
            require(
                MerkleProof.verify(_merkleProof, phase.merkleRoot, leaf),
                "Not allowlisted"
            );
            require(
                _mintAmount <=
                    _maxMintAmount -
                        phase.userMintedAmount[msg.sender][_tokenId],
                "Exceeds allowlist amount"
            );
        } else {
            require(
                _mintAmount <=
                    publicSaleMaxMintAmountPerAddress -
                        phase.userMintedAmount[msg.sender][_tokenId],
                "Exceeds public sale amount"
            );
        }

        phase.userMintedAmount[msg.sender][_tokenId] += _mintAmount;
        tokenConfig.totalSupply += _mintAmount;
        _mint(msg.sender, _tokenId, _mintAmount, "");
    }

    // Airdrop Function
    function airdrop(
        address[] calldata _to,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts
    ) external onlyRole(AIRDROP_ROLE) {
        require(
            _to.length == _tokenIds.length &&
                _tokenIds.length == _amounts.length,
            "Array lengths must match"
        );

        Phase storage phase = phases[currentPhaseId];

        for (uint256 i = 0; i < _to.length; i++) {
            TokenConfig storage tokenConfig = phase.tokenConfigs[_tokenIds[i]];
            require(tokenConfig.isActive, "Token not active in current phase");
            require(
                tokenConfig.totalSupply + _amounts[i] <= tokenConfig.maxSupply,
                "Exceeds max supply for token"
            );

            tokenConfig.totalSupply += _amounts[i];
            _mint(_to[i], _tokenIds[i], _amounts[i], "");
        }
    }

    // External Mint Function
    function externalMint(
        address _to,
        uint256 _tokenId,
        uint256 _amount
    ) external onlyRole(MINTER_ROLE) {
        Phase storage phase = phases[currentPhaseId];
        TokenConfig storage tokenConfig = phase.tokenConfigs[_tokenId];

        require(tokenConfig.isActive, "Token not active in current phase");
        require(
            tokenConfig.totalSupply + _amount <= tokenConfig.maxSupply,
            "Exceeds max supply for token"
        );

        tokenConfig.totalSupply += _amount;
        _mint(_to, _tokenId, _amount, "");
    }

    function getTokenConfig(
        uint256 _phaseId,
        uint256 _tokenId
    )
        external
        view
        returns (bool isActive, uint256 maxSupply, uint256 totalSupply)
    {
        TokenConfig storage config = phases[_phaseId].tokenConfigs[_tokenId];
        return (config.isActive, config.maxSupply, config.totalSupply);
    }

    function getUserMintedAmount(
        uint256 _phaseId,
        address _user,
        uint256 _tokenId
    ) external view returns (uint256) {
        return phases[_phaseId].userMintedAmount[_user][_tokenId];
    }

    function getTotalMintedAmountAcrossPhases(
        uint256 _tokenId
    ) external view returns (uint256) {
        uint256 totalMinted = 0;
        // フェーズ0から現在のフェーズまでループ
        for (uint256 i = 0; i <= currentPhaseId; i++) {
            TokenConfig storage config = phases[i].tokenConfigs[_tokenId];
            totalMinted += config.totalSupply;
        }
        return totalMinted;
    }

    // URI Management
    function setURI(
        uint256 _tokenId,
        string memory _uri
    ) external onlyRole(ADMIN_ROLE) {
        tokenURIs[_tokenId] = _uri;
        emit URI(_uri, _tokenId);
    }

    function uri(
        uint256 _tokenId
    ) public view virtual override returns (string memory) {
        if (useInterfaceMetadata) {
            return interfaceOfTokenURI.tokenURI(_tokenId);
        }
        if (useBaseURI) {
            return
                string(
                    abi.encodePacked(
                        baseURI,
                        _tokenId.toString(),
                        baseExtension
                    )
                );
        }
        return tokenURIs[_tokenId];
    }

    // SBT Functions
    function setIsSBT(bool _state) external onlyRole(ADMIN_ROLE) {
        isSBT = _state;
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        if (isSBT) {
            require(
                from == address(0) ||
                    to == address(0) ||
                    to == address(0x000000000000000000000000000000000000dEaD),
                "SBT: Transfer prohibited"
            );
        }
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    // Operator Filter Functions
    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override onlyAllowedOperatorApproval(operator) {
        require(!isSBT || !approved, "SBT: Approval prohibited");
        super.setApprovalForAll(operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) public virtual override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, amount, data);
    }

    // Withdrawal Function
    function withdraw() external onlyOwner {
        require(withdrawAddress != address(0), "Withdraw address not set");
        (bool success, ) = payable(withdrawAddress).call{
            value: address(this).balance
        }("");
        require(success, "Withdrawal failed");
    }

    // Administration Functions
    function setPaused(bool _state) external onlyRole(ADMIN_ROLE) {
        paused = _state;
    }

    function setOnlyAllowlisted(bool _state) external onlyRole(ADMIN_ROLE) {
        onlyAllowlisted = _state;
    }

    function setPublicSaleMaxMintAmountPerAddress(
        uint256 _amount
    ) external onlyRole(ADMIN_ROLE) {
        publicSaleMaxMintAmountPerAddress = _amount;
    }

    function setInterfaceMetadata(
        address _interface,
        bool _useInterface
    ) external onlyRole(ADMIN_ROLE) {
        interfaceOfTokenURI = ITokenURI(_interface);
        useInterfaceMetadata = _useInterface;
    }

    function setBaseURI(
        string memory _newBaseURI,
        bool _useBaseURI
    ) external onlyRole(ADMIN_ROLE) {
        baseURI = _newBaseURI;
        useBaseURI = _useBaseURI;
    }

    function setWithdrawAddress(address _withdrawAddress) external onlyOwner {
        withdrawAddress = _withdrawAddress;
    }

    function setDefaultRoyalty(
        address _receiver,
        uint96 _feeNumerator
    ) external onlyOwner {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    // Override Functions
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC1155, ERC2981, AccessControl)
        returns (bool)
    {
        return
            ERC1155.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
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
}
