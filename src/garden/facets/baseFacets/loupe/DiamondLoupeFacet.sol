// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*###############################################################################

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘


################################################################################*/

// Local Interfaces
import { IDiamondLoupe } from "src/garden/facets/baseFacets/loupe/IDiamondLoupe.sol";
import { IERC165 } from "src/interfaces/IERC165.sol";

// Local Libraries
import { DiamondLoupeBase } from "src/garden/facets/baseFacets/loupe/DiamondLoupeBase.sol";
import { Facet } from "src/garden/facets/Facet.sol";

// ============================================================================
// DiamondLoupeFacet
// ============================================================================

/**
 * @title DiamondLoupeFacet
 * @author Blok Capital DAO
 * @notice Facet that implements the IDiamondLoupe interface to allow querying of diamond facets and function selectors
 * according to the EIP-2535 Diamond Standard. This facet is included in the base set of facets for all gardens to
 * provide standard loupe functionality for introspection of the diamond's facets and selectors. It also implements
 * ERC-165 to allow interface detection.
 */
contract DiamondLoupeFacet is IDiamondLoupe, IERC165, DiamondLoupeBase, Facet {
    /// @inheritdoc IDiamondLoupe
    function facets() external view override returns (IDiamondLoupe.Facet[] memory facets_) {
        facets_ = _facets();
    }

    /// @inheritdoc IDiamondLoupe
    function facetFunctionSelectors(address _facet)
        external
        view
        override
        returns (bytes4[] memory facetFunctionSelectors_)
    {
        facetFunctionSelectors_ = _facetFunctionSelectors(_facet);
    }

    /// @inheritdoc IDiamondLoupe
    function facetAddresses() external view override returns (address[] memory facetAddresses_) {
        facetAddresses_ = _facetAddresses();
    }

    /// @inheritdoc IDiamondLoupe
    function facetAddress(bytes4 _functionSelector) external view override returns (address facetAddress_) {
        facetAddress_ = _facetAddress(_functionSelector);
    }

    // ========================================================================
    // IERC165 Implementation
    // ========================================================================

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 _interfaceId) external view override returns (bool) {
        return _supportsInterface(_interfaceId);
    }
}
