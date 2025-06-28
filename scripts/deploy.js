const { ethers, upgrades } = require('hardhat');

const verify = async (contractAddress, args) => {
  console.log('Verifying contract...');
  try {
    await run('verify:verify', {
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

async function deployUpgradeableContract() {
  const args = ['0xe1c1389b9c9ac20c871df594718b918489cee3fc', 50, 50];

  const MyContract = await ethers.getContractFactory('NFTsAlleyNFTMarket');

  const proxy = await upgrades.deployProxy(MyContract, args, {
    initializer: 'initialize',
  });
  await proxy.waitForDeployment(4);
  console.log('Proxy address:', proxy.address);
  console.log('Proxy', proxy.target);
  console.log('Proxy', proxy.BaseContract.target);

  // await verify(nft.address, args);
}

deployUpgradeableContract()
  .then(() => process.exit(0))
  .catch((error) => {
    console.log(error);
    process.exit(1);
  });
