const { ethers } = require('ethers');

// スマートコントラクトの情報
const CONTRACT_ADDRESS = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512'; // 変更が必要な場合は適宜修正
const CONTRACT_ABI = [
  // 必要なコントラクトのメソッドのみをここに含める
  "function getPhaseStatus(uint256 phase) public view returns (tuple)",
  "function getAllowlistUserAmount(uint256 phase, address user) public view returns (uint256)",
  "function getAllowlistMintedAmount(uint256 phase, address user) public view returns (uint256)",
  "function allowlistMintNFT(uint256 tokenAmount, bytes32[] calldata proof) external payable",
  "function configurePhase(uint256 phase, uint96 price, uint32 phaseMaxPerWallet, uint32 maxSupplyForPhase, bytes32 merkleRoot, bool requiresAllowlist, uint256 allowlistType) external",
  "function grantRole(bytes32 role, address account) external"

];

// プロバイダーとウォレット設定
const ADMIN_ROLE = ethers.utils.id("ADMIN_ROLE");

const provider = new ethers.providers.JsonRpcProvider('http://127.0.0.1:8545'); // ローカルRPC
const wallet = new ethers.Wallet('0x59c6995e998f97a5a004497eb2e27faedfa64d8fdb5ac4f25f6f6cdbfef24f5e', provider);
const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, wallet);

async function setupRoles() {
  try {
    console.log('Granting ADMIN_ROLE to current wallet address...');
    const tx = await contract.grantRole(ADMIN_ROLE, wallet.address);
    console.log('Waiting for transaction confirmation...');
    await tx.wait();
    console.log('ADMIN_ROLE granted successfully.');
  } catch (error) {
    console.error('Error granting ADMIN_ROLE:', error);
  }
}


async function fetchTransactionDetails() {
  try {
    const phase = 1; // 現在のフェーズ
    const userAddress = '0xDC68E2aF8816B3154c95dab301f7838c7D83A0Ba'; // 対象アドレス

    console.log(`Fetching phase status for phase: ${phase}`);
    const phaseStatus = await contract.getPhaseStatus(phase);
    console.log('Phase Status:', phaseStatus);

    console.log(`Fetching allowlist user amount for user: ${userAddress}`);
    const allowedAmount = await contract.getAllowlistUserAmount(phase, userAddress);
    console.log('Allowed Amount:', allowedAmount.toString());

    console.log(`Fetching minted amount for user: ${userAddress}`);
    const mintedAmount = await contract.getAllowlistMintedAmount(phase, userAddress);
    console.log('Minted Amount:', mintedAmount.toString());

    console.log('Transaction details fetched successfully.');
  } catch (error) {
    console.error('Error fetching transaction details:', error);
  }
}

async function fetchPhaseStatus() {
  try {
    const phase = 1; // 現在のフェーズ

    console.log(`Fetching phase status for phase: ${phase}`);
    const phaseStatus = await contract.getPhaseStatus(phase);

    // Phase Statusの内容を確認
    console.log('Phase Status:', phaseStatus);

    if (phaseStatus.merkleRoot && phaseStatus.merkleRoot !== '0x0000000000000000000000000000000000000000000000000000000000000000') {
      console.log(`Merkle Root is set: ${phaseStatus.merkleRoot}`);
    } else {
      console.log('Merkle Root is not set or phase is not configured.');
    }
  } catch (error) {
    console.error('Error fetching phase status:', error);
  }
}

async function configurePhase() {
  try {
    const phase = 1;
    const price = ethers.utils.parseEther('0.01');
    const phaseMaxPerWallet = 5;
    const maxSupplyForPhase = 100;
    const merkleRoot = '0xf5d7a663bd520d587fd1b9d540e9b675cb953f123c9d01f654bc144aef28b1e7'; // 正しいマークルルートを設定
    const requiresAllowlist = true;
    const allowlistType = 0; // Merkle Tree

    console.log('Configuring phase...');
    const tx = await contract.configurePhase(
      phase,
      price,
      phaseMaxPerWallet,
      maxSupplyForPhase,
      merkleRoot,
      requiresAllowlist,
      allowlistType
    );

    console.log('Waiting for transaction confirmation...');
    await tx.wait();
    console.log('Phase configured successfully.');
  } catch (error) {
    console.error('Error configuring phase:', error);
  }
}

async function simulateMintTransaction() {
  try {
    const phase = 1; // 現在のフェーズ
    const tokenAmount = 1; // ミントしたいトークン数
    const proof = [
      // プルーフを適切に設定
      "0xd7989ed450535b378be1a4df7d9f93a0931dc6f75c211d570d33d31d4d33f53a",
      "0xe4332b7c02ff17ff301fc2342a4c164516e4ecfadaadd32448299c09d6ecc1a4",
      "0x01521b4c0f6940ce140ee69d3412f21dee5b5ed0da8f648a6c58dd63e026dd19",
      "0xc724dce8c126205f1e850d7c006cb93ee2d89c8b2eea9056b986b03fa28f236b"
    ];

    console.log('Simulating allowlist mint transaction...');

    // 推定ガスを取得
    const estimatedGas = await contract.estimateGas.allowlistMintNFT(tokenAmount, proof, {
      value: ethers.utils.parseEther('0.001')
    });

    console.log(`Estimated Gas: ${estimatedGas.toString()}`);

    // トランザクション送信
    const tx = await contract.allowlistMintNFT(tokenAmount, proof, {
      value: ethers.utils.parseEther('0.001'),
      gasLimit: estimatedGas.mul(2) // 推定ガスの2倍を設定
    });

    console.log('Transaction sent, awaiting confirmation...');
    const receipt = await tx.wait();

    console.log('Transaction successful:', receipt);
  } catch (error) {
    console.error('Error during mint transaction simulation:', error);

    // エラーデータのデコードを試みる
    if (error.data) {
      const errorSignature = error.data.slice(0, 10); // シグネチャを抽出
      console.error(`Error Signature: ${errorSignature}`);
      // エラーを更にデバッグ可能にする
    }
  }
}

// 実行
setupRoles().then(() => {

  fetchTransactionDetails().then(() => {
    fetchPhaseStatus().then(() => {
      configurePhase().then(() => {
        simulateMintTransaction();
      });
    });
  });

});
