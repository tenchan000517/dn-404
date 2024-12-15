// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// 各種ライブラリとスマートコントラクトのインポート
import "./DN404.sol";
import "./DN404Mirror.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";

/**
 * @title NFTMintDN404
 * @notice Sample DN404 contract that demonstrates the owner selling NFTs rather than the fungible token.
 * The underlying call still mints ERC20 tokens, but to the end user it'll appear as a standard NFT mint.
 * Each address is limited to MAX_PER_WALLET total mints.
 */
contract NecogeneDN404 is DN404, Ownable {
    // NFTの名前、シンボル、基本URI、ホワイトリストのルートを保持するプライベート変数
    string private _name;
    string private _symbol;
    string private _baseURI;
    bytes32 private _allowlistRoot;

    // 公開価格、ホワイトリスト価格、総発行量、売買可能状態を保持するパブリック変数
    uint96 public publicPrice; // uint96 is sufficient to represent all ETH in existence.
    uint96 public allowlistPrice; // uint96 is sufficient to represent all ETH in existence.
    uint32 public totalMinted; // DN404 only supports up to `2**32 - 2` tokens.
    bool public live;

    // 一つのウォレットで購入可能な最大量と総供給量を保持するパブリック定数
    uint32 public constant MAX_PER_WALLET = 5;
    uint32 public constant MAX_SUPPLY = 5000;

    // 各種エラーを定義
    error InvalidProof();
    error InvalidMint();
    error InvalidPrice();
    error TotalSupplyReached();
    error NotLive();

    // コンストラクタ：スマートコントラクトがデプロイされるときに一度だけ実行される
    constructor(
        string memory name_,
        string memory symbol_,
        bytes32 allowlistRoot_,
        uint96 publicPrice_,
        uint96 allowlistPrice_,
        uint96 initialTokenSupply,
        address initialSupplyOwner
    ) {
        // オーナーの初期化
        _initializeOwner(msg.sender);

        // 各種パラメータの設定
        _name = name_;
        _symbol = symbol_;
        _allowlistRoot = allowlistRoot_;
        publicPrice = publicPrice_;
        allowlistPrice = allowlistPrice_;

        // DN404Mirrorのインスタンスを作成し、DN404を初期化
        address mirror = address(new DN404Mirror(msg.sender));
        _initializeDN404(initialTokenSupply, initialSupplyOwner, mirror);
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

    // 総発行量を更新し、上限を超えた場合はエラーを返す修飾子
    modifier checkAndUpdateTotalMinted(uint256 nftAmount) {
        uint256 newTotalMinted = uint256(totalMinted) + nftAmount;
        if (newTotalMinted > MAX_SUPPLY) {
            revert TotalSupplyReached();
        }
        totalMinted = uint32(newTotalMinted);
        _;
    }

    // 購入者の発行カウントを更新し、上限を超えた場合はエラーを返す修飾子
    modifier checkAndUpdateBuyerMintCount(uint256 nftAmount) {
        uint256 currentMintCount = _getAux(msg.sender);
        uint256 newMintCount = currentMintCount + nftAmount;
        if (newMintCount > MAX_PER_WALLET) {
            revert InvalidMint();
        }
        _setAux(msg.sender, uint88(newMintCount));
        _;
    }

    // NFTを発行する関数
    function mint(uint256 nftAmount)
        public
        payable
        onlyLive
        checkPrice(publicPrice, nftAmount)
        checkAndUpdateBuyerMintCount(nftAmount)
        checkAndUpdateTotalMinted(nftAmount)
    {
        _mint(msg.sender, nftAmount * _unit());
    }

    // ホワイトリストに登録されたアドレスがNFTを発行する関数
    function allowlistMint(uint256 nftAmount, bytes32[] calldata proof)
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

        // NFTの発行
        _mint(msg.sender, nftAmount * _unit());
    }

        // 基本URIを設定する関数
    function setBaseURI(string memory baseURI_) public onlyOwner {
        _baseURI = baseURI_;
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

    // NFTの名前を取得する関数
    function name() public view override returns (string memory) {
        return _name;
    }

    // NFTのシンボルを取得する関数
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory result) {
        if (bytes(_baseURI).length != 0) {
            result = string(abi.encodePacked(_baseURI, LibString.toString(tokenId)));
        }
    }
}