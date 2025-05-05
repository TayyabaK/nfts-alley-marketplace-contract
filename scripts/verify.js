const { ethers, upgrades, network, run } = 'hardhat';

async function verifyContract() {
  const args = [];

  // const nft = await ethers.deployContract(nftFactory, args, {
  //   initializer: "initialize",
  // });
  // await nft.waitForDeployment();
  // console.log(`Deployed!`);
  // console.log(`Simple Storage Address: ${nft.address}`);

  await verify('0x85fc1F3d7FB68Dd7E636d818d419051a3DFfbE9d', args);
}
const verify = async (contractAddress, args) => {
  console.log('Verifying contract...');
  try {
    await hre.run('verify:verify', {
      address: contractAddress,
      constructorArguments: args,
    });
  } catch (e) {
    if (e.message.toLowerCase().includes('already verified')) {
      console.log('Already verified!');
    } else {
      console.log(e);
    }
  }
};

verifyContract()
  .then(() => process.exit(0))
  .catch((error) => {
    console.log(error);
    process.exit(1);
  });
