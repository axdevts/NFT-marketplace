async function main() {

    let Artistnft = await ethers.getContractFactory("ArtistNFT");
    
    console.log("Deploying ArtistNFT...");

    // ArtistNFT = await upgrades.deployProxy(Artistnft);
    ArtistNFT_contract = await Artistnft.deploy();

    console.log("ArtistNFT deployed to:", ArtistNFT_contract.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
  