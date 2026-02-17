// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

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

/**
 * @title IndexComponentRegistry
 * @notice Registry contract for managing index components and their associated price feeds. This contract allows the
 * owner to register and unregister components, which consist of a symbol, token address, and Chainlink price feed
 * address. The registry provides functions for retrieving component data and validating component registration status.
 * It uses OpenZeppelin's Ownable for access control and EnumerableSet for efficient management of registered component
 * addresses.
 */
contract IndexComponentRegistry is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Represents an index component with its symbol, token address, and price feed
    /// @param symbol Ticker symbol of the component (e.g., "WETH", "USDC")
    /// @param tokenAddress ERC20 token contract address
    /// @param priceFeedAddress Chainlink AggregatorV3 price feed address
    struct Component {
        string symbol;
        address tokenAddress;
        address priceFeedAddress;
    }

    /// @notice Mapping from symbol to component data
    mapping(string => Component) private _components;

    /// @notice Set of all registered component token addresses
    /// @dev Provides efficient lookup and iteration
    EnumerableSet.AddressSet private _componentAddresses;

    /// @notice Constructs the IndexComponentRegistry
    /// @param initialOwner Address of the contract owner
    constructor(address initialOwner) Ownable(initialOwner) { }

    /// @notice Registers multiple components with their corresponding price feeds
    /// @param components Array of Component structs to register
    /// @dev Only callable by owner. Components must not already be registered.
    function registerComponents(Component[] memory components) public onlyOwner {
        uint256 totalComponents = components.length;
        for (uint256 i = 0; i < totalComponents; i++) {
            Component memory component = components[i];
            if (component.tokenAddress == address(0)) revert IndexComponentRegistry_InvalidComponentAddress();
            if (component.priceFeedAddress == address(0)) revert IndexComponentRegistry_InvalidPriceFeedAddress();
            if (_components[component.symbol].tokenAddress != address(0)) {
                revert IndexComponentRegistry_ComponentAlreadyRegistered();
            }
            _componentAddresses.add(component.tokenAddress);
            _components[component.symbol] = component;
        }
    }

    /// @notice Unregisters multiple components from the registry
    /// @param symbols Array of component symbols to unregister
    /// @dev Only callable by owner. All components must be registered.
    function unregisterComponents(string[] memory symbols) public onlyOwner {
        uint256 totalSymbols = symbols.length;
        for (uint256 i = 0; i < totalSymbols; i++) {
            string memory symbol = symbols[i];
            if (_components[symbol].tokenAddress == address(0)) {
                revert IndexComponentRegistry_ComponentNotRegistered();
            }
            delete _components[symbol];
        }
    }

    /// @notice Checks if a component is registered
    /// @param symbol Symbol to check
    /// @return True if the component is registered, false otherwise
    function isComponentRegistered(string memory symbol) public view returns (bool) {
        return _components[symbol].tokenAddress != address(0);
    }

    /// @notice Returns the price feed address for a specific component
    /// @param symbol The component symbol
    /// @return The Chainlink price feed address for the component
    function getComponentSymbolToPriceFeedAddress(string memory symbol) public view returns (address) {
        return _components[symbol].priceFeedAddress;
    }

    /// @notice Returns price feed addresses for multiple components
    /// @param symbols Array of component symbols
    /// @return priceFeedAddresses Array of corresponding Chainlink price feed addresses
    /// @dev All components must be registered. Returns parallel array to input.
    function getPriceFeedAddresses(string[] memory symbols) public view returns (address[] memory) {
        uint256 totalSymbols = symbols.length;
        address[] memory priceFeedAddresses = new address[](totalSymbols);
        for (uint256 i = 0; i < totalSymbols; i++) {
            if (_components[symbols[i]].tokenAddress == address(0)) {
                revert IndexComponentRegistry_ComponentNotRegistered();
            }
            priceFeedAddresses[i] = _components[symbols[i]].priceFeedAddress;
            if (priceFeedAddresses[i] == address(0)) {
                revert IndexComponentRegistry_InvalidPriceFeedAddress();
            }
        }
        return priceFeedAddresses;
    }

    /// @notice Returns the token address for a specific component
    /// @param symbol The component symbol
    /// @return The token address for the component
    function getComponentAddress(string memory symbol) public view returns (address) {
        return _components[symbol].tokenAddress;
    }
}
