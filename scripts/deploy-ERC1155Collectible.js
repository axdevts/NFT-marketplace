async function main() {

	let ERC1155Collectible = await ethers.getContractFactory("ERC1155CollectibleUpgradeable");

	console.log("Deploying ERC1155NFT...");

	// ERC1155NFT = await upgrades.deployProxy(ERC1155Collectible);
	ERC1155NFT = await ERC1155Collectible.deploy();

	console.log("ERC1155NFT deployed to:", ERC1155NFT.address);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});