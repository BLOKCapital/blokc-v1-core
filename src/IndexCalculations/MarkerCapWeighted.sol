//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title MarketCapCalculationType
    @author BLOK Capital DAO
    @notice Enum for the market cap calculation type

################################################################################*/

import { AssetData } from "../AssetData/AssetData.sol";

contract MarkerCapWeighted {
    AssetData public assetData;

    error MarkerCapWeighted_InvalidAssetDataAddress();

    constructor(address _assetData) {
        if (_assetData == address(0)) revert MarkerCapWeighted_InvalidAssetDataAddress();
        assetData = AssetData(_assetData);
    }

    function getWeightedMarketCap(address[] memory assetAddresses)
        public
        view
        returns (uint256[] memory weightedMarketCaps)
    {
        weightedMarketCaps = new uint256[](assetAddresses.length);

        uint256 totalMarketCap = _getTotalMarketCap(assetAddresses);
        for (uint256 i = 0; i < assetAddresses.length; i++) {
            totalMarketCap += assetData.getAssetMarketCap(assetAddresses[i]);
        }
        for (uint256 i = 0; i < assetAddresses.length; i++) {
            weightedMarketCaps[i] = assetData.getAssetMarketCap(assetAddresses[i]) * 1e18 / totalMarketCap;
        }
        return weightedMarketCaps;
    }

    function _getTotalMarketCap(address[] memory assetAddresses) internal view returns (uint256 totalMarketCap) {
        for (uint256 i = 0; i < assetAddresses.length; i++) {
            totalMarketCap += assetData.getAssetMarketCap(assetAddresses[i]);
        }
        return totalMarketCap;
    }

    function _getWeightedMarketCap(address[] memory assetAddresses)
        internal
        view
        returns (uint256[] memory weightedMarketCaps)
    { }
}
