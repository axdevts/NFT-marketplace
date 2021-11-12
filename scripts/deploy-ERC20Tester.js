async function main() {

    let TestToken = await ethers.getContractFactory("TestTokenUpgradeable");
    
    console.log("Deploying BUSD...");

    BUSD = await upgrades.deployProxy(TestToken);

    console.log("BUSD deployed to:", BUSD.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
  