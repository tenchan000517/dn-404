// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title POPOPO Token
 * @dev Implementation of the POPOPO Token
 */
contract POPOPO is ERC20, ERC20Burnable, Ownable, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint8 public constant TOKEN_DECIMALS = 18;
    uint256 private _maxSupply;

    event MaxSupplyUpdated(uint256 indexed previousMaxSupply, uint256 indexed newMaxSupply);
    event MinterRoleGranted(address indexed account);
    event MinterRoleRevoked(address indexed account);

    /**
     * @dev Constructor that gives msg.sender all initial tokens
     * @param initialMaxSupply Maximum supply of tokens
     * @param initialSupply Initial supply of tokens to mint
     * @param initialSupplyAddress Address to receive the initial supply
     */
    constructor(
        uint256 initialMaxSupply,
        uint256 initialSupply,
        address initialSupplyAddress
    ) ERC20("POPOPO", "$PPP") Ownable() {
        require(initialSupplyAddress != address(0), "POPOPO: invalid initial supply address");
        require(initialSupply <= initialMaxSupply, "POPOPO: initial supply exceeds max supply");
        require(initialMaxSupply > 0, "POPOPO: max supply must be greater than 0");

        _maxSupply = initialMaxSupply;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        _mint(initialSupplyAddress, initialSupply);
    }

    /**
     * @dev Sets new maximum supply
     * @param newMaxSupply New maximum supply to set
     */
    function setMaxSupply(uint256 newMaxSupply) public onlyOwner {
        require(
            newMaxSupply >= totalSupply(),
            "POPOPO: new max supply must be greater than or equal to current total supply"
        );

        uint256 oldMaxSupply = _maxSupply;
        _maxSupply = newMaxSupply;

        emit MaxSupplyUpdated(oldMaxSupply, newMaxSupply);
    }

    /**
     * @dev Mints new tokens
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(
        address to,
        uint256 amount
    ) public onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(to != address(0), "POPOPO: mint to the zero address");
        require(amount > 0, "POPOPO: mint amount must be greater than 0");
        require(
            totalSupply() + amount <= _maxSupply,
            "POPOPO: mint would exceed max supply"
        );
        _mint(to, amount);
    }

    /**
     * @dev Returns the maximum supply of tokens
     */
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    /**
     * @dev Pauses all token transfers
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Grants minter role to an account
     * @param account Address to grant minter role to
     */
    function grantMinterRole(address account) public onlyOwner {
        require(account != address(0), "POPOPO: invalid address");
        grantRole(MINTER_ROLE, account);
        emit MinterRoleGranted(account);
    }

    /**
     * @dev Revokes minter role from an account
     * @param account Address to revoke minter role from
     */
    function revokeMinterRole(address account) public onlyOwner {
        require(account != address(0), "POPOPO: invalid address");
        revokeRole(MINTER_ROLE, account);
        emit MinterRoleRevoked(account);
    }

    /**
     * @dev Returns the number of decimals used to get its user representation
     */
    function decimals() public pure override returns (uint8) {
        return TOKEN_DECIMALS;
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}