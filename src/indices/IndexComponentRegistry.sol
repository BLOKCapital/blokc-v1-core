//SPDX-License-Identifier: MIT
pragma solidity >=0.8.31;

/*###############################################################################

    @title IndexComponentRegistry
    @author BLOK Capital DAO
    @notice Registry for approved index components and their Chainlink price feeds
    @dev Manages a whitelist of ERC20 tokens that can be included in indices.
         Each component is paired with a Chainlink price feed for accurate pricing.
         This is NOT upgradeable - it's a simple Ownable contract.

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AggregatorV3Interface } from "src/interfaces/AggregatorV3Interface.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IndexMath } from "src/indices/libraries/IndexMath.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when component token address is zero
error IndexComponentRegistry_InvalidComponentAddress();

/// @notice Thrown when price feed address is zero
error IndexComponentRegistry_InvalidPriceFeedAddress();

/// @notice Thrown when attempting to register an already registered component
error IndexComponentRegistry_ComponentAlreadyRegistered();

/// @notice Thrown when attempting to operate on an unregistered component
error IndexComponentRegistry_ComponentNotRegistered();

/// @notice Thrown when component and price feed array lengths don't match
error IndexComponentRegistry_TotalComponentsAndPriceFeedsMismatch();

/// @notice Thrown when component and symbol array lengths don't match
error IndexComponentRegistry_TotalComponentsAndSymbolsMismatch();

contract IndexComponentRegistry is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Component {
        string symbol;
        address tokenAddress;
        address priceFeedAddress;
    }

    mapping(address => Component) private _components;

    /// @notice Set of all registered component token addresses
    /// @dev Provides efficient lookup and iteration
    EnumerableSet.AddressSet private _componentAddresses;

    /// @notice Constructs the IndexComponentRegistry
    /// @param initialOwner Address of the contract owner
    constructor(address initialOwner) Ownable(initialOwner) { }

    /// @notice Registers multiple components with their corresponding price feeds
    /// @param componentAddresses Array of ERC20 token addresses to register
    /// @param priceFeedAddresses Array of Chainlink price feed addresses (parallel to componentAddresses)
    /// @dev Only callable by owner. Arrays must have equal length. Components must not already be registered.
    function registerComponents(
        address[] memory componentAddresses,
        address[] memory priceFeedAddresses,
        string[] memory symbols
    )
        public
        onlyOwner
    {
        uint256 totalComponents = componentAddresses.length;
        uint256 totalPriceFeeds = priceFeedAddresses.length;
        if (totalComponents != totalPriceFeeds) revert IndexComponentRegistry_TotalComponentsAndPriceFeedsMismatch();
        if (totalComponents != symbols.length) revert IndexComponentRegistry_TotalComponentsAndSymbolsMismatch();
        for (uint256 i = 0; i < totalComponents; i++) {
            address componentAddress = componentAddresses[i];
            address priceFeedAddress = priceFeedAddresses[i];
            string memory symbol = symbols[i];
            if (componentAddress == address(0)) revert IndexComponentRegistry_InvalidComponentAddress();
            if (priceFeedAddress == address(0)) revert IndexComponentRegistry_InvalidPriceFeedAddress();
            if (_componentAddresses.contains(componentAddress)) {
                revert IndexComponentRegistry_ComponentAlreadyRegistered();
            }
            _componentAddresses.add(componentAddress);
            _components[componentAddress] =
                Component({ symbol: symbol, tokenAddress: componentAddress, priceFeedAddress: priceFeedAddress });
        }
    }

    /// @notice Unregisters multiple components from the registry
    /// @param componentAddresses Array of component addresses to unregister
    /// @dev Only callable by owner. All components must be registered.
    function unregisterComponents(address[] memory componentAddresses) public onlyOwner {
        uint256 totalComponents = componentAddresses.length;
        for (uint256 i = 0; i < totalComponents; i++) {
            address componentAddress = componentAddresses[i];
            if (!_componentAddresses.contains(componentAddress)) {
                revert IndexComponentRegistry_ComponentNotRegistered();
            }
            _componentAddresses.remove(componentAddress);
            delete _components[componentAddress];
        }
    }

    /// @notice Checks if a component is registered
    /// @param componentAddress Address to check
    /// @return True if the component is registered, false otherwise
    function isComponentRegistered(address componentAddress) public view returns (bool) {
        return _componentAddresses.contains(componentAddress);
    }

    /// @notice Returns all registered component addresses
    /// @return Array of registered component token addresses
    function getComponentAddresses() public view returns (address[] memory) {
        address[] memory componentAddresses = new address[](_componentAddresses.length());
        for (uint256 i = 0; i < _componentAddresses.length(); i++) {
            componentAddresses[i] = _componentAddresses.at(i);
        }
        return componentAddresses;
    }

    /// @notice Returns all registered components and their price feed addresses
    /// @return components Array of component token addresses
    /// @return priceFeedAddresses Array of corresponding Chainlink price feed addresses
    /// @dev Returned arrays are parallel - priceFeedAddresses[i] is the feed for components[i]
    function getComponentsAndPriceFeedAddresses() public view returns (address[] memory, address[] memory) {
        address[] memory components = new address[](_componentAddresses.length());
        address[] memory priceFeedAddresses = new address[](_componentAddresses.length());
        for (uint256 i = 0; i < _componentAddresses.length(); i++) {
            components[i] = _components[_componentAddresses.at(i)].tokenAddress;
            priceFeedAddresses[i] = _components[_componentAddresses.at(i)].priceFeedAddress;
        }
        return (components, priceFeedAddresses);
    }

    /// @notice Returns the price feed address for a specific component
    /// @param componentAddress The component token address
    /// @return The Chainlink price feed address for the component
    function getComponentAddressToPriceFeedAddress(address componentAddress) public view returns (address) {
        return _components[componentAddress].priceFeedAddress;
    }

    /// @notice Returns price feed addresses for multiple components
    /// @param componentAddresses Array of component addresses
    /// @return priceFeedAddresses Array of corresponding Chainlink price feed addresses
    /// @dev All components must be registered. Returns parallel array to input.
    function getPriceFeedAddresses(address[] memory componentAddresses) public view returns (address[] memory) {
        uint256 totalComponents = componentAddresses.length;
        address[] memory priceFeedAddresses = new address[](totalComponents);
        for (uint256 i = 0; i < totalComponents; i++) {
            if (!_componentAddresses.contains(componentAddresses[i])) {
                revert IndexComponentRegistry_ComponentNotRegistered();
            }
            priceFeedAddresses[i] = _components[componentAddresses[i]].priceFeedAddress;
            if (priceFeedAddresses[i] == address(0)) {
                revert IndexComponentRegistry_InvalidPriceFeedAddress();
            }
        }
        return priceFeedAddresses;
    }

    /// @notice Returns the symbol of a specific component
    /// @param componentAddress The component token address
    /// @return The symbol of the component
    function getComponentSymbol(address componentAddress) public view returns (string memory) {
        return _components[componentAddress].symbol;
    }
}
