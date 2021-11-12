pragma solidity ^0.8.0;

interface IEcchiGameCurrencyUpgradeable {
    // corresponds to the EcchiGameCurrency contract
    enum GameCurrency {
        GoldCoin,
        CommonSilverShard,
        PoweredSilverShard,
        CommonGoldShard,
        PoweredGoldShard
    }
}
