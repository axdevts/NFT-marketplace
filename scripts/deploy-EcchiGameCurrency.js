async function main() {

    let Ecchicoin = await ethers.getContractFactory("EcchiCoin");

    console.log("Deploying EcchiCoin...");

    EcchiCoin = await Ecchicoin.deploy();

    console.log("EcchiCoin deployed to:", EcchiCoin.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
  