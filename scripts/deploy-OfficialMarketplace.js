async function main() {
	const ArtistNFTaddress = "0x41aA0e5Cfa90ebf051BFC77071E95c5D8471c036";
	const BUSDaddress = "0x12c2945d9eC78e2c3411cF312836Ba4eA9fe009d";
	const EcchiCoinaddress = "0xA9a6B2A70274b3755E3d492D3780E09c68C6C9C6";

	let OfficialMarket = await ethers.getContractFactory("OfficialMarketUpgradeable");

	console.log("Deploying OfficialMarketContract...");

	// OfficialMarketContract = await upgrades.deployProxy(OfficialMarket, [ArtistNFTaddress, BUSDaddress, EcchiCoinaddress]);
	OfficialMarketContract = await OfficialMarket.deploy(ArtistNFTaddress, BUSDaddress, EcchiCoinaddress);
	OfficialMarketContract = await OfficialMarket.deploy();

	console.log("OfficialMarketContract deployed to:", OfficialMarketContract.address);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});