pragma solidity ^0.8.0;

interface IEcchiGameCurrency {
    // corresponds to the EcchiGameCurrency contract
    enum GameCurrency {
        GoldCoin,
        CommonSilverShard,
        PoweredSilverShard,
        CommonGoldShard,
        PoweredGoldShard
    }
}
