
// scripts/generateMerkleRoot.js
const { ethers } = require('hardhat');
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const { allowlistAddresses } = require('./allowlist.js');

async function main() {
    const leaves = allowlistAddresses.map(([address, amount]) =>
        ethers.solidityPackedKeccak256(
            ['address', 'uint256'],
            [address, amount]
        )
    );

    const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    const rootHash = merkleTree.getRoot();

    console.log('Merkle Root:', '0x' + rootHash.toString('hex'));
    
    // 検証用のプルーフを生成
    const testAddress = allowlistAddresses[0];
    const leaf = ethers.solidityPackedKeccak256(
        ['address', 'uint256'],
        [testAddress[0], testAddress[1]]
    );
    const proof = merkleTree.getHexProof(leaf);
    
    console.log('Test Address:', testAddress[0]);
    console.log('Test Amount:', testAddress[1]);
    console.log('Merkle Proof:', proof);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });