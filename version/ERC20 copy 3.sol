// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/security/Pausable.sol";

// contract POPOPO is ERC20, Ownable, AccessControl, Pausable {
//     bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
//     uint256 private _maxSupply;

//     event MaxSupplyUpdated(uint256 previousMaxSupply, uint256 newMaxSupply);

//     // Initial supply address for testnet:
//     address public constant INITIAL_SUPPLY_ADDRESS =
//         0x33fb3aD653B212a7FE898F5a31295dd25cCbd5aC;

//     constructor(uint256 initialMaxSupply) ERC20("POPOPO", "$PPP") Ownable() {
//         require(
//             INITIAL_SUPPLY_ADDRESS != address(0),
//             "Invalid initial supply address"
//         );

//         _maxSupply = initialMaxSupply;
//         _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
//         _grantRole(MINTER_ROLE, msg.sender);

//         // 200 million tokens with 18 decimals
//         uint256 initialSupply = 200_000_000 * 10 ** 18;
//         require(
//             initialSupply <= initialMaxSupply,
//             "Initial supply exceeds max supply"
//         );

//         // Initial mint of 200 million tokens to the specified address
//         _mint(INITIAL_SUPPLY_ADDRESS, initialSupply);
//     }

//     function setMaxSupply(uint256 newMaxSupply) public onlyOwner {
//         require(
//             newMaxSupply >= totalSupply(),
//             "New max supply must be greater than or equal to current total supply"
//         );

//         uint256 oldMaxSupply = _maxSupply;
//         _maxSupply = newMaxSupply;

//         emit MaxSupplyUpdated(oldMaxSupply, newMaxSupply);
//     }

//     function mint(
//         address to,
//         uint256 amount
//     ) public onlyRole(MINTER_ROLE) whenNotPaused {
//         require(
//             totalSupply() + amount <= _maxSupply,
//             "Mint would exceed max supply"
//         );
//         _mint(to, amount);
//     }

//     function maxSupply() public view returns (uint256) {
//         return _maxSupply;
//     }

//     // Pause functions
//     function pause() public onlyOwner {
//         _pause();
//     }

//     function unpause() public onlyOwner {
//         _unpause();
//     }

//     // Override required by Solidity for multiple inheritance
//     function supportsInterface(
//         bytes4 interfaceId
//     ) public view override(AccessControl) returns (bool) {
//         return super.supportsInterface(interfaceId);
//     }

//     // Override _beforeTokenTransfer
//     function _beforeTokenTransfer(
//         address from,
//         address to,
//         uint256 amount
//     ) internal override {
//         super._beforeTokenTransfer(from, to, amount);
//     }
// }
