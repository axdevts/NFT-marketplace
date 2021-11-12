import { Address, BigDecimal, BigInt, log } from "@graphprotocol/graph-ts";
import { ZERO_ADDRESS } from "@protofire/subgraph-toolkit";
import {
  ERC1155NFTCreated,
  ERC1155NFTMinted,
  TransferBatch,
  TransferSingle,
} from "../generated/Erc1155contract/Erc1155Contract";
import { Artist, Collector, CollectorNfts, Nft } from "../generated/schema";
import {
  determineRank,
  ERC1155COLLECTIBLE_ADDRESS,
  getAttributesValue,
  OFFICIAL_MARTKETPLACE_ADDRESS,
} from "./helpers";
// import { Erc1155Contract as Erc1155Contract } from "../generated/Erc1155contract/Erc1155Contract";

/**
 * Handler called when NFT minted from ERC1155Collectible
 **/
export function handleErc1155NftMinted(event: ERC1155NFTMinted): void {
  let tokenID = event.params.tokenID;
  let tokenMetadataUri = event.params.tokenMetadataUri;

  // Check if artist exist
  let artist = Artist.load(event.params.creator.toHexString());
  if (!artist) {
    let artist = new Artist(event.params.creator.toHexString());
    artist.save();
  }

  // create NFT
  let nft = Nft.load(
    event.params.tokenID
      .toString()
      .concat(event.params.contractAddress.toHexString())
  );
  if (!nft) {
    nft = new Nft(
      event.params.tokenID
        .toString()
        .concat(event.params.contractAddress.toHexString())
    );
    nft.tokenID = tokenID;
    nft.amountMinted = event.params.amountMinted;
    nft.contractAddress = event.params.contractAddress.toHexString();
    nft.tokenMetadataUri = tokenMetadataUri;
    nft.creator = event.params.creator.toHexString();
    nft.dateMinted = event.block.timestamp;
    nft.isOnSale = false;
    nft.isERC721 = false;
    nft.save();
  } else {
    nft.amountMinted = nft.amountMinted.plus(event.params.amountMinted);
    nft.isERC721 = false;
    nft.save();
  }
}

/**
 *Handler called from ERC1155Collectible when Token is created
 **/
export function handleErc1155NftCreated(event: ERC1155NFTCreated): void {
  let tokenID = event.params.tokenID;
  let tokenMetadataUri = event.params.tokenMetadataUri;

  // Check if artist exist
  let artist = Artist.load(event.params.creator.toHexString());
  if (!artist) {
    let artist = new Artist(event.params.creator.toHexString());
    artist.save();
  }

  // create NFT
  let nft = Nft.load(
    event.params.tokenID
      .toString()
      .concat(event.params.contractAddress.toHexString())
  );
  if (!nft) {
    nft = new Nft(
      event.params.tokenID
        .toString()
        .concat(event.params.contractAddress.toHexString())
    );
    nft.tokenID = tokenID;
    nft.amountMinted = BigInt.fromString("0");
    nft.contractAddress = event.params.contractAddress.toHexString();
    nft.tokenMetadataUri = tokenMetadataUri;
    nft.creator = event.params.creator.toHexString();
    nft.dateMinted = event.block.timestamp;
    // nft.owner = event.params.creator.toHexString();
    nft.isOnSale = false;
    nft.isERC721 = false;
    nft.isPublicAllowed = event.params.publicAllowed;
    nft.save();
  }
}

/**
 * Handler called from ERC1155Collectible when Token is Transfered
 **/
export function handleTransferSingle(event: TransferSingle): void {
  // Check if collector exist
  let collectorToTransfer = Collector.load(event.params.to.toHexString());
  let collectorFromTransfer = Artist.load(event.params.from.toHexString());

  // Required If conditions for transfer event
  if (
    event.params.to.toHexString() != ERC1155COLLECTIBLE_ADDRESS &&
    event.params.to.toHexString() != OFFICIAL_MARTKETPLACE_ADDRESS &&
    event.params.to.toHexString() != ZERO_ADDRESS &&
    event.params.from.toHexString() != collectorFromTransfer.id
  ) {
    // If collector does not exist create one
    if (!collectorToTransfer) {
      collectorToTransfer = new Collector(event.params.to.toHexString());
      collectorToTransfer.totalAttributes = BigInt.fromString(
        getAttributesValue(
          event.params.id.toString(),
          event.params.value.toString()
        )
      );
      collectorToTransfer.rank = determineRank(
        collectorToTransfer.totalAttributes
      );
      collectorToTransfer.save();
    } else {
      //If collector eist update attributes and rank
      let attributesValueToAdd = BigInt.fromString(
        getAttributesValue(
          event.params.id.toString(),
          event.params.value.toString()
        )
      );
      collectorToTransfer.totalAttributes = collectorToTransfer.totalAttributes.plus(
        attributesValueToAdd
      );
      collectorToTransfer.rank = determineRank(
        collectorToTransfer.totalAttributes
      );
      collectorToTransfer.save();
    }

    let collectorNft = CollectorNfts.load(
      event.params.id
        .toString()
        .concat(event.params.from.toHexString()
        .concat(event.params.to.toHexString())));
    
    if (!collectorNft) {
      // Create many to many relation between Nfts and Collector
      collectorNft = new CollectorNfts(
        event.params.id
          .toString()
          .concat(
            event.params.from
              .toHexString()
              .concat(event.params.to.toHexString())
          )
      );

      collectorNft.collector = event.params.to.toHexString();
      collectorNft.nft = event.params.id
        .toString()
        .concat(ERC1155COLLECTIBLE_ADDRESS);
      collectorNft.save();
    }
  }
}

/**
 * Handler called from ERC1155Collectible when batch transfer event is emitted
 **/
export function handleTransferBatch(event: TransferBatch): void {
  let myValue = "A";
  log.info("My value is: {}", [myValue]);
  let ids = event.params.ids;
  let values = event.params.values;
  for (let i = 0; i < ids.length; ++i) {
    // Check if collector exist
    log.info("In loop: {}", [ids[i].toHexString()]);
    let collectorToTransfer = Collector.load(event.params.to.toHexString());
    let collectorFromTransfer = Artist.load(event.params.from.toHexString());

    // Required If conditions for transfer event
    if (
      event.params.to.toHexString() != ERC1155COLLECTIBLE_ADDRESS &&
      event.params.to.toHexString() != OFFICIAL_MARTKETPLACE_ADDRESS &&
      event.params.to.toHexString() != ZERO_ADDRESS
    ) {
      // If collector does not exist create one
      if (!collectorToTransfer) {
        collectorToTransfer = new Collector(event.params.to.toHexString());
        collectorToTransfer.totalAttributes = BigInt.fromString(
          getAttributesValue(ids[i].toString(), values[i].toString())
        );
        collectorToTransfer.rank = determineRank(
          collectorToTransfer.totalAttributes
        );
        collectorToTransfer.save();
      } else {
        //If collector exist update attributes and rank
        let attributesValueToAdd = BigInt.fromString(
          getAttributesValue(ids[i].toString(), values[i].toString())
        );
        collectorToTransfer.totalAttributes = collectorToTransfer.totalAttributes.plus(
          attributesValueToAdd
        );
        collectorToTransfer.rank = determineRank(
          collectorToTransfer.totalAttributes
        );
        collectorToTransfer.save();
      }

      let collectorNft = CollectorNfts.load(
        ids[i].toString()
          .concat(event.params.from.toHexString()
          .concat(event.params.to.toHexString())
          )
      );

      if (!collectorNft) {
        // let myValue = collectorNft.id;
        // log.info("Not fount collectorNft: {}", [myValue]);
        log.info("Timestamp: {}", [event.block.timestamp.toString()]);
        // Create many to many relation between Nfts and Collector
        collectorNft = new CollectorNfts(
          ids[i]
            .toString()
            .concat(
              event.params.from
                .toHexString()
                .concat(event.params.to.toHexString())
            )
        );

        collectorNft.collector = event.params.to.toHexString();

        collectorNft.nft = ids[i].toString().concat(ERC1155COLLECTIBLE_ADDRESS);
        collectorNft.save();
      }
    }
  }
}
