//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*###############################################################################


    @title Base Registry Receiver Contract for Multichain
    @author BLOK Capital DAO
    @notice Single contract that is responsible for Facet and Pool management with core logic and not 
            orchestration


    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/


import { IFacetRegistry } from "../../interfaces/IFacetRegistry.sol";
import { IPoolRegistry } from "../../interfaces/IPoolRegistry.sol";
import { Client, CCIPReceiver, IAny2EVMMessageReceiver } from "src/interfaces/ICCIP.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract FacetRegistryReceiverV3 is CCIPReceiver, Ownable, IERC165 {
    IFacetRegistry public facetRegistry;
    IPoolRegistry public poolRegistry;

    enum FacetAction { Add, Replace, Remove }
    enum PoolAction { Add, Remove }
     error InvalidMessageType(uint8 typeTag);
    error FacetRegistryNotSet();
    error PoolRegistryNotSet();
    error InvalidFacetAction(uint8 action);
    error InvalidFacetAddress(address facet);
    ///////////////////////////////////////////
    event FacetUpdateReceived(address indexed facet, bytes4[] selectors, FacetAction action);
    event PoolUpdateReceived(address indexed pool, string pairName, string dexId, PoolAction action);
    event FacetRegistrySet(address indexed registry);
    event PoolRegistrySet(address indexed registry);
    
    // Enhanced debug events
    event CCIPDebugInfo(bytes32 messageId, uint64 sourceChain, address sender, uint8 typeTag, address facet, bytes4[] selectors, uint8 action);
    event CCIPMessageReceived(bytes32 messageId, address sender, bytes data);
       
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
        // Emit debug event for all received messages
        emit CCIPMessageReceived(any2EvmMessage.messageId, abi.decode(any2EvmMessage.sender, (address)), any2EvmMessage.data);
        
        (uint8 typeTag, bytes memory payload) = abi.decode(any2EvmMessage.data, (uint8, bytes));

        if (typeTag == 1) {
            (address facet, bytes4[] memory selectors, FacetAction action) = abi.decode(payload, (address, bytes4[], FacetAction));
            
            //@dev RITICAL FIX: Add validation 
            if (facet == address(0)) {
                revert InvalidFacetAddress(facet);
            }
            

            //@dev Validate action enum
            uint8 actionValue = uint8(action);
            if (actionValue > 2) {
                revert InvalidFacetAction(actionValue);
            }
            
            
            emit CCIPDebugInfo(any2EvmMessage.messageId, any2EvmMessage.sourceChainSelector, 
                abi.decode(any2EvmMessage.sender, (address)), typeTag, facet, selectors, actionValue);
            
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
        
        // CRITICAL FIX: Never allow remove operations via CCIP for security
        // @notice Only allow Add and Replace operations
        if (action == FacetAction.Add) {
            registry.addFunctions(facet, selectors);
        } else if (action == FacetAction.Replace) {
            registry.replaceFunctions(facet, selectors);
        } else {
            // For security, revert on Remove operations via CCIP
            // Remove operations should only be done manually
            revert InvalidFacetAction(uint8(action));
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

    //@notice Manual functions for testing/emergency (only owner)
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

    //@dev Proper IERC165 implementation is always necessary for complete ccip execution 
    function supportsInterface(bytes4 interfaceId) public pure virtual override(CCIPReceiver, IERC165) returns (bool) {
        return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || 
               interfaceId == type(IERC165).interfaceId;
    }
}