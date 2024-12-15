// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// 各種ライブラリとスマートコントラクトのインポート
import {Ownable} from "solady/src/auth/Ownable.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "contract-allow-list/contracts/proxy/interface/IContractAllowListProxy.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

/**
 * @title NFTMintDN404
 * @notice Sample DN404 contract that demonstrates the owner selling NFTs rather than the fungible token.
 * The underlying call still mints ERC20 tokens, but to the end user it'll appear as a standard NFT mint.
 * Each address is limited to maxPerWallet total mints.
 */
contract TESTDN404RELiC is ERC721, Ownable, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    IContractAllowListProxy public CAL;
    EnumerableSet.AddressSet private localAllowedAddresses;

    event LocalCalAdded(address indexed operator, address indexed transferer);
    event LocalCalRemoved(address indexed operator, address indexed transferer);

    // カスタムエラーを定義
    error FractionalTransferNotAllowed();

    // NFTの基本URI、ホワイトリストのルートを保持するプライベート変数
    bytes32 private _allowlistRoot;

    // 公開価格、ホワイトリスト価格、総発行量、売買可能状態を保持するパブリック変数
    uint96 public publicPrice; // uint96 is sufficient to represent all ETH in existence.
    uint96 public allowlistPrice; // uint96 is sufficient to represent all ETH in existence.
    uint32 public totalMinted; // DN404 only supports up to `2**32 - 2` tokens.
    bool public live;

    // 一つのウォレットで購入可能な最大量と総供給量を保持するパブリック定数
    uint32 public maxPerWallet = 100;
    uint32 public maxSupply = 100;
    uint256 private _mintRatio = 10; // 10トークンにつき1NFTの初期設定

    // 各種エラーを定義
    error InvalidProof();
    error InvalidMint();
    error InvalidPrice();
    error TotalSupplyReached();
    error NotLive();

    bytes32 public constant ADMIN = keccak256("ADMIN");

    bool public enableRestrict = true;

    // token lock
    mapping(uint256 => uint256) public tokenCALLevel;

    // wallet lock
    mapping(address => uint256) public walletCALLevel;

    // contract lock
    uint256 public CALLevel = 1;

    // コンストラクタ：スマートコントラクトがデプロイされるときに一度だけ実行される
    constructor(
        string memory name_,
        string memory symbol_,
        bytes32 allowlistRoot_,
        uint96 publicPrice_,
        uint96 allowlistPrice_
    ) ERC721(name_, symbol_) {
        // オーナーの初期化
        _initializeOwner(msg.sender);

        // 各種パラメータの設定
        _allowlistRoot = allowlistRoot_;
        publicPrice = publicPrice_;
        allowlistPrice = allowlistPrice_;

        _setupRole(ADMIN, msg.sender);
    }

    // ミント比率を設定する関数
    function setMintRatio(uint256 newRatio) public onlyOwner {
        _mintRatio = newRatio;
    }

    // 売買可能状態のみで実行可能な関数を制限する修飾子
    modifier onlyLive() {
        if (!live) {
            revert NotLive();
        }
        _;
    }

    // 価格が正しいことを確認し、不正な場合はエラーを返す修飾子
    modifier checkPrice(uint256 price, uint256 nftAmount) {
        if (price * nftAmount != msg.value) {
            revert InvalidPrice();
        }
        _;
    }

    // maxPerWallet と maxSupply を更新するためのセッター関数を追加
    function setMaxPerWallet(uint32 _maxPerWallet) public onlyOwner {
        maxPerWallet = _maxPerWallet;
    }

    function setMaxSupply(uint32 _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
    }

    // 総発行量を更新し、上限を超えた場合はエラーを返す修飾子
    modifier checkAndUpdateTotalMinted(uint256 nftAmount) {
        uint256 newTotalMinted = uint256(totalMinted) + nftAmount;
        if (newTotalMinted > maxSupply) {
            revert TotalSupplyReached();
        }
        totalMinted = uint32(newTotalMinted);
        _;
    }

    // 購入者の発行カウントを更新し、上限を超えた場合はエラーを返す修飾子
    modifier checkAndUpdateBuyerMintCount(uint256 nftAmount) {
        uint256 currentMintCount = userMintedAmount[msg.sender];
        uint256 newMintCount = currentMintCount + nftAmount;
        if (newMintCount > maxPerWallet) {
            revert InvalidMint();
        }
        userMintedAmount[msg.sender] = uint88(newMintCount);
        _;
    }

    // NFTを発行する関数
    function mint(uint256 tokenAmount)
        public
        payable
        onlyLive
        checkPrice(publicPrice, tokenAmount)
        checkAndUpdateBuyerMintCount(tokenAmount)
        checkAndUpdateTotalMinted(tokenAmount)
    {
        for (uint256 i = 0; i < tokenAmount; i++) {
            _safeMint(msg.sender, totalMinted + i);
        }
    }

    // ホワイトリストに登録されたアドレスがNFTを発行する関数
    function allowlistMint(uint256 tokenAmount, bytes32[] calldata proof)
        public
        payable
        onlyLive
        checkPrice(allowlistPrice, tokenAmount)
        checkAndUpdateBuyerMintCount(tokenAmount)
        checkAndUpdateTotalMinted(tokenAmount)
    {
        // ホワイトリストの確認
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProofLib.verify(proof, _allowlistRoot, leaf)) {
            revert InvalidProof();
        }

        for (uint256 i = 0; i < tokenAmount; i++) {
            _safeMint(msg.sender, totalMinted + i);
        }
    }

    // NFTを発行する関数
    function mintNFT(uint256 nftAmount)
        public
        payable
        onlyLive
        checkPrice(publicPrice, nftAmount)
        checkAndUpdateBuyerMintCount(nftAmount)
        checkAndUpdateTotalMinted(nftAmount)
    {
        for (uint256 i = 0; i < nftAmount; i++) {
            _safeMint(msg.sender, totalMinted + i);
        }
    }

    // ホワイトリストに登録されたアドレスがNFTを発行する関数
    function allowlistNFTMint(uint256 nftAmount, bytes32[] calldata proof)
        public
        payable
        onlyLive
        checkPrice(allowlistPrice, nftAmount)
        checkAndUpdateBuyerMintCount(nftAmount)
        checkAndUpdateTotalMinted(nftAmount)
    {
        // ホワイトリストの確認
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProofLib.verify(proof, _allowlistRoot, leaf)) {
            revert InvalidProof();
        }

        for (uint256 i = 0; i < nftAmount; i++) {
            _safeMint(msg.sender, totalMinted + i);
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIValue;
    }

    string private _baseURIValue;

    function setBaseURI(string memory baseURI_) public onlyOwner {
        _baseURIValue = baseURI_;
    }

    function setPrices(uint96 publicPrice_, uint96 allowlistPrice_) public onlyOwner {
        publicPrice = publicPrice_;
        allowlistPrice = allowlistPrice_;
    }

    function toggleLive() public onlyOwner {
        live = !live;
    }

    function withdraw() public onlyOwner {
        SafeTransferLib.safeTransferAllETH(msg.sender);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        if (bytes(_baseURIValue).length != 0) {
            // tokenIdを文字列に変換し、基本URIと結合して、最後に".json"を追加
            return string(abi.encodePacked(_baseURIValue, LibString.toString(tokenId), ".json"));
        }

        return "";
    }

    // transferFromをオーバーライド
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        _beforeApprove(to, tokenId);
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override {
        _beforeApprove(to, tokenId);
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function approve(address to, uint256 tokenId) public virtual override {
        _beforeApprove(to, tokenId);
        super.approve(to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(
            _isAllowed(operator) || approved == false,
            "RestrictApprove: Can not approve locked token"
        );
        super.setApprovalForAll(operator, approved);
    }

    function _beforeApprove(address to, uint256 tokenId) internal virtual {
        if (to != address(0)) {
            require(_isAllowed(tokenId, to), "RestrictApprove: The contract is not allowed.");
        }
    }

    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual {
        if (from != address(0)) {
            _deleteTokenCALLevel(tokenId);
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setCALLevel(uint256 level) public onlyRole(ADMIN) {
        CALLevel = level;
    }

    function setCAL(address calAddress) external onlyRole(ADMIN) {
        CAL = IContractAllowListProxy(calAddress);
    }

    function addLocalContractAllowList(address transferer) external onlyRole(ADMIN) {
        localAllowedAddresses.add(transferer);
        emit LocalCalAdded(msg.sender, transferer);
    }

    function removeLocalContractAllowList(address transferer) external onlyRole(ADMIN) {
        localAllowedAddresses.remove(transferer);
        emit LocalCalRemoved(msg.sender, transferer);
    }

    function getLocalContractAllowList() external view returns (address[] memory) {
        return localAllowedAddresses.values();
    }

    function _isAllowed(uint256 tokenId, address transferer) internal view virtual returns (bool) {
        uint256 level = _getCALLevel(msg.sender, tokenId);
        return _isAllowed(transferer);
    }

    function _isAllowed(address transferer) internal view virtual returns (bool) {
        if (!enableRestrict) {
            return true;
        }
        return localAllowedAddresses.contains(transferer) || CAL.isAllowed(transferer, CALLevel);
    }

    function _deleteTokenCALLevel(uint256 tokenId) internal virtual {
        delete tokenCALLevel[tokenId];
    }

    function _getCALLevel(address holder, uint256 tokenId) internal view virtual returns (uint256) {
        if (tokenCALLevel[tokenId] > 0) {
            return tokenCALLevel[tokenId];
        }
        return _getCALLevel(holder);
    }

    function _getCALLevel(address holder) internal view virtual returns (uint256) {
        if (walletCALLevel[holder] > 0) {
            return walletCALLevel[holder];
        }
        return CALLevel;
    }

    // ユーザーごとのミント数を記録するマッピング
    mapping(address => uint256) private userMintedAmount;
}