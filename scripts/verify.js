const { ethers, upgrades, network, run } = 'hardhat';

async function verifyContract() {
  const args = [];

  // const nft = await ethers.deployContract(nftFactory, args, {
  //   initializer: "initialize",
  // });
  // await nft.waitForDeployment();
  // console.log(`Deployed!`);
  // console.log(`Simple Storage Address: ${nft.address}`);

  await verify('0x0716fF49010231942AedCc1d77985372a80c982d', args);
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
