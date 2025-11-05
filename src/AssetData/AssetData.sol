//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/*###############################################################################

    @title AssetData
    @author BLOK Capital DAO
    @notice Contract that manages the data for an asset.
    @dev This contract uses the Transparent Proxy pattern and is upgradeable.
         It uses OpenZeppelin's upgradeable contracts library for security and reliability.

################################################################################*/

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Chainlink AggregatorV3Interface for price feeds
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);
    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract AssetData is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor() Ownable(msg.sender) { }

    error AssetData_InvalidAssetAddress();
    error AssetData_AssetNotRegistered();
    error AssetData_InvalidPrice();
    error AssetData_InvalidMarketCap();
    error AssetData_AssetAlreadyRegistered();
    error AssetData_AssetNameEmpty();
    error AssetData_InvalidCirculatingSupply();
    error AssetData_InvalidLastUpdatedTimestamp();
    error AssetData_InvalidPriceFeedDataStale();
    error AssetData_InvalidPriceFeedNotUpdated();

    event AssetPriceUpdated(address assetAddress, uint256 price, uint256 timestamp);
    event AssetMarketCapUpdated(address assetAddress, uint256 marketCap, uint256 timestamp);

    struct AssetInfo {
        string name;
        address assetAddress;
        uint256 price;
        address priceFeedAddress;
        uint256 marketCap;
        uint256 circulatingSupply;
        uint256 lastUpdatedTimestamp;
    }

    mapping(address => AssetInfo) public assetInfo;
    EnumerableSet.AddressSet private _assetAddresses;

    modifier onlyAssetRegistered(address assetAddress) {
        if (assetAddress == address(0)) revert AssetData_InvalidAssetAddress();
        if (!_assetAddresses.contains(assetAddress)) revert AssetData_AssetNotRegistered();
        _;
    }

    function addAsset(
        string memory name,
        address assetAddress,
        uint256 circulatingSupply,
        address priceFeedAddress
    )
        public
        onlyOwner
    {
        if (assetAddress == address(0)) revert AssetData_InvalidAssetAddress();
        if (_assetAddresses.contains(assetAddress)) revert AssetData_AssetAlreadyRegistered();
        if (bytes(name).length == 0) revert AssetData_AssetNameEmpty();
        assetInfo[assetAddress] = AssetInfo({
            name: name,
            assetAddress: assetAddress,
            price: getAssetPrice(assetAddress),
            priceFeedAddress: priceFeedAddress,
            marketCap: getAssetMarketCap(assetAddress),
            circulatingSupply: circulatingSupply,
            lastUpdatedTimestamp: block.timestamp
        });
        _assetAddresses.add(assetAddress);
    }

    function removeAsset(address assetAddress) public onlyAssetRegistered(assetAddress) onlyOwner {
        delete assetInfo[assetAddress];
        _assetAddresses.remove(assetAddress);
    }

    function setAssetPrice(address assetAddress) public onlyAssetRegistered(assetAddress) {
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            AggregatorV3Interface(assetInfo[assetAddress].priceFeedAddress).latestRoundData();

        if (answer <= 0) revert AssetData_InvalidPrice();
        if (updatedAt == 0) revert AssetData_InvalidPriceFeedNotUpdated();
        if (answeredInRound < roundId) revert AssetData_InvalidPriceFeedDataStale();

        assetInfo[assetAddress].price = uint256(answer);
        assetInfo[assetAddress].lastUpdatedTimestamp = block.timestamp;
        emit AssetPriceUpdated(assetAddress, assetInfo[assetAddress].price, block.timestamp);
    }

    function setAssetMarketCap(address assetAddress) public onlyAssetRegistered(assetAddress) {
        assetInfo[assetAddress].marketCap = getAssetPrice(assetAddress) * getAssetCirculatingSupply(assetAddress);
        emit AssetMarketCapUpdated(assetAddress, assetInfo[assetAddress].marketCap, block.timestamp);
    }

    function getAssetName(address assetAddress)
        public
        view
        onlyAssetRegistered(assetAddress)
        returns (string memory name)
    {
        return assetInfo[assetAddress].name;
    }

    function getAssetPrice(address assetAddress)
        public
        view
        onlyAssetRegistered(assetAddress)
        returns (uint256 price)
    {
        return assetInfo[assetAddress].price;
    }

    function getAssetCirculatingSupply(address assetAddress)
        public
        view
        onlyAssetRegistered(assetAddress)
        returns (uint256 circulatingSupply)
    {
        return assetInfo[assetAddress].circulatingSupply;
    }

    function getAssetLatestUpdatedTimestamp(address assetAddress)
        public
        view
        onlyAssetRegistered(assetAddress)
        returns (uint256 lastUpdatedTimestamp)
    {
        return assetInfo[assetAddress].lastUpdatedTimestamp;
    }

    function getAssetPriceFeedAddress(address assetAddress)
        public
        view
        onlyAssetRegistered(assetAddress)
        returns (address priceFeedAddress)
    {
        return assetInfo[assetAddress].priceFeedAddress;
    }

    function getAssetMarketCap(address assetAddress)
        public
        view
        onlyAssetRegistered(assetAddress)
        returns (uint256 marketCap)
    {
        return assetInfo[assetAddress].marketCap;
    }

    function getAssetInfo(address assetAddress)
        public
        view
        onlyAssetRegistered(assetAddress)
        returns (AssetInfo memory)
    {
        return assetInfo[assetAddress];
    }

    function getAssetAddresses() public view returns (address[] memory) {
        return _assetAddresses.values();
    }
}
