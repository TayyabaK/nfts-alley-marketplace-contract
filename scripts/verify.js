const { ethers, upgrades, network, run } = 'hardhat';

async function verifyContract() {
  const args = [];

  // const nft = await ethers.deployContract(nftFactory, args, {
  //   initializer: "initialize",
  // });
  // await nft.waitForDeployment();
  // console.log(`Deployed!`);
  // console.log(`Simple Storage Address: ${nft.address}`);

  await verify('0x05676f9210391650F5F27fe154B9E3c849771735', args);
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
