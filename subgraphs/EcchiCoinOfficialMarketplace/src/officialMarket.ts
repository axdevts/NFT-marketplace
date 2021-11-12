import {
    FixedSaleCreated, FixedSaleSuccessful
  } from "../generated/OfficialMarketplaceContract/OfficialMarkerplaceContract";
import { Collector, FixedPriceSale, Nft, NftSale } from "../generated/schema";
import { decimal } from "@protofire/subgraph-toolkit";
import { Address, store, BigInt, BigDecimal } from "@graphprotocol/graph-ts";
import { getAttributesValue  } from "./helpers"



/**
 * Handler called when Fixed Sale created from Official Marketplace
 **/
 export function handleFixedSaleCreated(event: FixedSaleCreated): void {

    let nftSale = new NftSale(event.params.saleId.toString())
    nftSale.soldPrice = decimal.ZERO;
    nftSale.nft = event.params.tokenId.toString().concat(event.params.nftContract.toHexString())

    // Set isOnsale true
    let nft =  Nft.load(event.params.tokenId.toString().concat(event.params.nftContract.toHexString()));
    nft.isOnSale = true;
    nft.save();
    nftSale.dateListed = event.block.timestamp;
    if(event.params.isERC721 == true){
        nftSale.amountOnSale = BigInt.fromString("1");
    }
    else{
        nftSale.amountOnSale = event.params.amount;
    }
    nftSale.save();

    // create Fixed Sale
    let fixedSale = new FixedPriceSale(event.params.saleId.toString().concat(event.params.tokenId.toString()));

    fixedSale.saleId = event.params.saleId;
    fixedSale.tokenID = event.params.tokenId.toString();
    fixedSale.fixedArtworkSale = event.params.saleId.toString();
    fixedSale.fixedPrice = event.params.fixedPrice.toBigDecimal();
    fixedSale.startingDateTime = event.block.timestamp;
    fixedSale.status = "Active";

    fixedSale.save();
  }


  /**
 * Handler called when Fixed Sale Successful from Official Marketplace
 **/
 export function handleFixedSaleSuccessful(event: FixedSaleSuccessful): void {


    // let collector = Collector.load(event.params.winner.toHexString());


    let nftSale = NftSale.load(event.params.saleId.toString())
    nftSale.soldPrice = event.params.totalPrice.toBigDecimal();
    nftSale.save();

    let nft = Nft.load(event.params.tokenId.toString().concat(event.params.nftContract.toHexString()));
    nft.isOnSale = false;
    if(nft.isERC721 == true){
      nft.erc721Owner = event.params.winner.toHexString();
    }
    nft.save();
    let fixedSale = FixedPriceSale.load(event.params.saleId.toString().concat(event.params.tokenId.toString()));
    fixedSale.status = "Successful";
    fixedSale.save();
  }