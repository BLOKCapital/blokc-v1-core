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
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IndexMath } from "src/BlokcIndices/libraries/IndexMath.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

error IndexComponentRegistry_InvalidComponentAddress();
error IndexComponentRegistry_InvalidPriceFeedAddress();
error IndexComponentRegistry_ComponentAlreadyRegistered();
error IndexComponentRegistry_ComponentNotRegistered();
error IndexComponentRegistry_TotalComponentsAndPriceFeedsMismatch();

contract IndexComponentRegistry is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _componentAddresses;
    mapping(address => address) private _componentAddressToPriceFeedAddress;

    constructor(address initialOwner) Ownable(initialOwner) { }

    function registerComponents(
        address[] memory componentAddresses,
        address[] memory priceFeedAddresses
    )
        public
        onlyOwner
    {
        uint256 totalComponents = componentAddresses.length;
        uint256 totalPriceFeeds = priceFeedAddresses.length;
        if (totalComponents != totalPriceFeeds) revert IndexComponentRegistry_TotalComponentsAndPriceFeedsMismatch();
        for (uint256 i = 0; i < totalComponents; i++) {
            address componentAddress = componentAddresses[i];
            address priceFeedAddress = priceFeedAddresses[i];
            if (componentAddress == address(0)) revert IndexComponentRegistry_InvalidComponentAddress();
            if (priceFeedAddress == address(0)) revert IndexComponentRegistry_InvalidPriceFeedAddress();
            if (_componentAddresses.contains(componentAddress)) {
                revert IndexComponentRegistry_ComponentAlreadyRegistered();
            }
            _componentAddresses.add(componentAddress);
            _componentAddressToPriceFeedAddress[componentAddress] = priceFeedAddress;
        }
    }

    function unregisterComponents(address[] memory componentAddresses) public onlyOwner {
        uint256 totalComponents = componentAddresses.length;
        for (uint256 i = 0; i < totalComponents; i++) {
            address componentAddress = componentAddresses[i];
            if (!_componentAddresses.contains(componentAddress)) {
                revert IndexComponentRegistry_ComponentNotRegistered();
            }
            _componentAddresses.remove(componentAddress);
            delete _componentAddressToPriceFeedAddress[componentAddress];
        }
    }

    function isComponentRegistered(address componentAddress) public view returns (bool) {
        return _componentAddresses.contains(componentAddress);
    }

    function getComponentAddresses() public view returns (address[] memory) {
        address[] memory componentAddresses = new address[](_componentAddresses.length());
        for (uint256 i = 0; i < _componentAddresses.length(); i++) {
            componentAddresses[i] = _componentAddresses.at(i);
        }
        return componentAddresses;
    }

    function getComponentsAndPriceFeedAddresses() public view returns (address[] memory, address[] memory) {
        address[] memory components = new address[](_componentAddresses.length());
        address[] memory priceFeedAddresses = new address[](_componentAddresses.length());
        for (uint256 i = 0; i < _componentAddresses.length(); i++) {
            components[i] = _componentAddresses.at(i);
            priceFeedAddresses[i] = _componentAddressToPriceFeedAddress[_componentAddresses.at(i)];
        }
        return (components, priceFeedAddresses);
    }

    function getComponentAddressToPriceFeedAddress(address componentAddress) public view returns (address) {
        return _componentAddressToPriceFeedAddress[componentAddress];
    }

    function getPriceFeedAddresses(address[] memory componentAddresses) public view returns (address[] memory) {
        uint256 totalComponents = componentAddresses.length;
        address[] memory priceFeedAddresses = new address[](totalComponents);
        for (uint256 i = 0; i < totalComponents; i++) {
            if (!_componentAddresses.contains(componentAddresses[i])) {
                revert IndexComponentRegistry_ComponentNotRegistered();
            }
            priceFeedAddresses[i] = _componentAddressToPriceFeedAddress[componentAddresses[i]];
            if (priceFeedAddresses[i] == address(0)) {
                revert IndexComponentRegistry_InvalidPriceFeedAddress();
            }
        }
        return priceFeedAddresses;
    }
}
