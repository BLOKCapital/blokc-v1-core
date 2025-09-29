// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * \
 * Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
 * EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
 *
 * Implementation of a diamond.
 * /*****************************************************************************
 */
import { LibDiamond } from "./libraries/LibDiamond.sol";
import { IDiamondCut } from "src/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "src/interfaces/IDiamondLoupe.sol";
import { IUpgrade } from "src/interfaces/IUpgrade.sol";
import { IERC173 } from "src/interfaces/IERC173.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";
import { IFacetRegistry } from "src/interfaces/IFacetRegistry.sol";

error InvalidCallToDiamond(address facet, bytes4 selector);

contract Diamond {
    constructor(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _contractOwner,
        address _facetRegistry,
        address _liquidityPoolRegistry,
        address _killSwitch
    )
        payable
    {
        LibDiamond.setContractOwner(_contractOwner);
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.facetRegistry = _facetRegistry;
        ds.liquidityPoolRegistry = _liquidityPoolRegistry;
        ds.killSwitch = _killSwitch;
        LibDiamond.diamondCut(_diamondCut, address(0), "");

        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
        ds.supportedInterfaces[type(IUpgrade).interfaceId] = true;
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        // get diamond storage
        assembly {
            ds.slot := position
        }
        // get facet from function selector
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;

        if (!IFacetRegistry(ds.facetRegistry).isSelectorRegistered(facet, msg.sig)) {
            revert InvalidCallToDiamond(facet, msg.sig);
        }
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable { }
}
