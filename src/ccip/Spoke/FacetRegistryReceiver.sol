//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IFacetRegistry } from "../../interfaces/IFacetRegistry.sol";
import { IPoolRegistry } from "../../interfaces/IPoolRegistry.sol";
import { Client, CCIPReceiver } from "src/interfaces/ICCIP.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";


contract FacetRegistryReceiver is CCIPReceiver, Ownable {
    IFacetRegistry public facetRegistry;
    IPoolRegistry public poolRegistry;

    /// @dev This contract receives facet update instructions from the broadcaster contract on another chain.
    /// @dev The receiver contract manages facets based on the received instructions.
    /// @dev The receiver contract doesn't deal with ETH or any fee token as the broadcaster contract handles that.

    enum FacetAction { Add, Replace, Remove }
    enum PoolAction { Add, Remove }

    error InvalidMessageType(uint8 typeTag);
    error FacetRegistryNotSet();
    error PoolRegistryNotSet();

    event FacetUpdateReceived(address indexed facet, bytes4[] selectors, FacetAction action);
    event PoolUpdateReceived(address indexed pool, string pairName, string dexId, PoolAction action);
    event FacetRegistrySet(address indexed registry);
    event PoolRegistrySet(address indexed registry);
       
       /// @dev For building & testing purposes upgradeable addresses are used at constructor level to allow easy changes.
       /// @notice The argument address is here the router address on Base mainnet
        constructor() CCIPReceiver(0x881e3A65B4d4a04dD529061dd0071cf975F58bCD) Ownable(msg.sender) {}

    function setFacetRegistry(address registry) external onlyOwner {
        require(registry != address(0), "Invalid registry address");
        facetRegistry = IFacetRegistry(registry);
        emit FacetRegistrySet(registry);
    }

    function setPoolRegistry(address registry) external onlyOwner {
        require(registry != address(0), "Invalid registry address");
        poolRegistry = IPoolRegistry(registry);
        emit PoolRegistrySet(registry);
    }
    
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
        (uint8 typeTag, bytes memory payload) = abi.decode(any2EvmMessage.data, (uint8, bytes));

        if (typeTag == 1) {
            (address facet, bytes4[] memory selectors, FacetAction action) = abi.decode(payload, (address, bytes4[], FacetAction));
            _handleFacetUpdate(facet, selectors, action);
            emit FacetUpdateReceived(facet, selectors, action);
            return;
        }

        if (typeTag == 2) {
            (address pool, string memory pairName, string memory dexId, PoolAction action) = abi.decode(payload, (address, string, string, PoolAction));
            _handlePoolUpdate(pool, pairName, dexId, action);
            emit PoolUpdateReceived(pool, pairName, dexId, action);
            return;
        }

        revert InvalidMessageType(typeTag);
    }

    function _handleFacetUpdate(address facet, bytes4[] memory selectors, FacetAction action) internal {
        IFacetRegistry registry = facetRegistry;
        if (address(registry) == address(0)) revert FacetRegistryNotSet();
        
        if (action == FacetAction.Add) {
            registry.addFunctions(facet, selectors);
        } else if (action == FacetAction.Replace) {
            registry.replaceFunctions(facet, selectors);
        } else if (action == FacetAction.Remove) {
            // For remove action, we need to pass address(0) as facetAddress according to FacetRegistry implementation
            registry.removeFunctions(address(0), selectors);
        }
    }

    function _handlePoolUpdate(address pool, string memory pairName, string memory dexId, PoolAction action) internal {
        IPoolRegistry registry = poolRegistry;
        if (address(registry) == address(0)) revert PoolRegistryNotSet();
        
        if (action == PoolAction.Add) {
            registry.addPool(pool, pairName, dexId);
        } else if (action == PoolAction.Remove) {
            registry.removePool(pool);
        }
    }

    /// @notice Manual facet update functions (only owner) for emergency/testing purposes
    function addFunctions(address facet, bytes4[] memory selectors) external onlyOwner {
        IFacetRegistry registry = facetRegistry;
        if (address(registry) == address(0)) revert FacetRegistryNotSet();
        registry.addFunctions(facet, selectors);
    }

    function replaceFunctions(address facet, bytes4[] memory selectors) external onlyOwner {
        IFacetRegistry registry = facetRegistry;
        if (address(registry) == address(0)) revert FacetRegistryNotSet();
        registry.replaceFunctions(facet, selectors);
    }



    function removeFunctions(bytes4[] memory selectors) external onlyOwner {
        IFacetRegistry registry = facetRegistry;
        if (address(registry) == address(0)) revert FacetRegistryNotSet();
        registry.removeFunctions(address(0), selectors);
    }

    /// @notice Manual pool update functions/ for emergency/testing purposes
    function addPool(address pool, string calldata pairName, string calldata dexId) external onlyOwner {
        IPoolRegistry registry = poolRegistry;
        if (address(registry) == address(0)) revert PoolRegistryNotSet();
        registry.addPool(pool, pairName, dexId);
    }

    function removePool(address pool) external onlyOwner {
        IPoolRegistry registry = poolRegistry;
        if (address(registry) == address(0)) revert PoolRegistryNotSet();
        registry.removePool(pool);
    }
}
