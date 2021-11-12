import { Address, store, BigInt } from "@graphprotocol/graph-ts";
import {
    ArtistNFTMinted,
  } from "../generated/artistcontract/artistcontract";

import { Nft, Artist} from "../generated/schema";
import { AMOUNT_MINTED_ERC721 } from "./helpers"

/**
 * Handler called when Artist NFT is created
 **/
 export function handleArtistNftMinted(event: ArtistNFTMinted): void {
    let tokenID = event.params.tokenID;
    let tokenMetadataUri = event.params.tokenMetadataUri;
    
    // Check if artist exist 
    let artist = Artist.load(event.params.creator.toHexString());
    if(!artist){
        let artist = new Artist(event.params.creator.toHexString());
        artist.save();
    }

    // create NFT
    let nft = new Nft(event.params.tokenID.toString().concat(event.params.contractAddress.toHexString()));
    nft.tokenID = tokenID;
    nft.amountMinted = event.params.amountMinted;
    nft.contractAddress= event.params.contractAddress.toHexString();
    nft.tokenMetadataUri= tokenMetadataUri;
    nft.creator = event.params.creator.toHexString();
    nft.dateMinted = event.block.timestamp;
    nft.erc721Owner = event.params.creator.toHexString();
    nft.isOnSale= false;
    nft.type = "Artist";
    nft.isERC721 = true;
    nft.save();
}


  