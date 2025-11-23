//SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { IndexComponentRegistry } from "src/BlokcIndices/IndexComponentRegistry.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract CirculatingSupply is Ownable {
    error CirculatingSupply_ComponentNotRegistered(address componentAddress);
    error CirculatingSupply_InvalidCirculatingSupply(uint256 circulatingSupply);
    error CirculatingSupply_OwnerIsZeroAddress();
    error CirculatingSupply_InvalidIndexComponentRegistryAddress(address indexComponentRegistryAddress);

    event CirculatingSupplySet(address componentAddress, uint256 circulatingSupply);

    IndexComponentRegistry private immutable _indexComponentRegistry;

    constructor(address _indexComponentRegistryAddress, address initialOwner) Ownable(initialOwner) {
        if (_indexComponentRegistryAddress == address(0)) {
            revert CirculatingSupply_InvalidIndexComponentRegistryAddress(_indexComponentRegistryAddress);
        }
        _indexComponentRegistry = IndexComponentRegistry(_indexComponentRegistryAddress);
    }

    mapping(address componentAddress => uint256 circulatingSupply) private _circulatingSupply;

    function getCirculatingSupply(address componentAddress) public view returns (uint256) {
        if (!_indexComponentRegistry.isComponentRegistered(componentAddress)) {
            revert CirculatingSupply_ComponentNotRegistered(componentAddress);
        }
        return _circulatingSupply[componentAddress];
    }

    function setCirculatingSupply(address componentAddress, uint256 circulatingSupply) public onlyOwner {
        if (!_indexComponentRegistry.isComponentRegistered(componentAddress)) {
            revert CirculatingSupply_ComponentNotRegistered(componentAddress);
        }
        if (circulatingSupply == 0) {
            revert CirculatingSupply_InvalidCirculatingSupply(circulatingSupply);
        }
        _circulatingSupply[componentAddress] = circulatingSupply;
        emit CirculatingSupplySet(componentAddress, circulatingSupply);
    }
}
