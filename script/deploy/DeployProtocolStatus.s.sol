// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import { ENSRegistry } from "src/ENS/ENSRegistry.sol";
import { ENSResolver } from "src/ENS/ENSResolver.sol";
import { ProtocolStatus } from "src/protocolStatus/ProtocolStatus.sol";

contract DeployProtocolStatusArbitrum is Script {
    function run() external {
        vm.startBroadcast();

        // ----------------------------------------------------
        // 1. Deploy your custom ENS registry + resolver on Arbitrum
        // ----------------------------------------------------
        ENSRegistry registry = new ENSRegistry(msg.sender);
        ENSResolver resolver = new ENSResolver(msg.sender);


        console2.log("ENSRegistry:", address(registry));
        console2.log("ENSResolver:", address(resolver));

        // Transfer ownership to deployer
        registry.transferOwnership(msg.sender);
        resolver.transferOwnership(msg.sender);

        // ----------------------------------------------------
        // 2. REAL SCM ENTRY: 0xnishil.eth
        // ----------------------------------------------------
        // Precomputed namehash for "0xnishil.eth"
        bytes32 nh_nishil = 0x80e85b22ecad57c0365a65fc97da8907ce392e350138d9eebd2dda9487b5e4a8;

        // 2A: Wire registry → resolver
        registry.setResolver(nh_nishil, address(resolver));

        // 2B: Set ENS resolved address
        // MUST be the real owner of 0xnishil.eth on mainnet ENS!
        address resolvedNishil = 0xe233e3F36674A744d62e52d032a2126EF6aDCbC5; // your real wallet

        resolver.setAddr(nh_nishil, resolvedNishil);

        console2.log("Registered 0xnishil.eth =>", resolvedNishil);

        // ----------------------------------------------------
        // 3. Bootstrap arrays (ONLY 1 real SCM: Nishil)
        // ----------------------------------------------------
        bytes32[] memory initialNamehashes = new bytes32[](1);
        string[] memory initialNames = new string[](1);
        uint256[] memory initialExpiries = new uint256[](1);

        initialNamehashes[0] = nh_nishil;
        initialNames[0] = "0xnishil.eth";

        // Your real ENS expiry for 0xnishil.eth
        // Replace with real expiry timestamp from app.ens.domains
        initialExpiries[0] = 1793894400; // example you earlier used

        // ----------------------------------------------------
        // 4. Deploy ProtocolStatus (OWNER = msg.sender)
        // ----------------------------------------------------
        ProtocolStatus ps = new ProtocolStatus(
            msg.sender,
            address(registry),
            initialNamehashes,
            initialNames,
            initialExpiries
        );

        console2.log("ProtocolStatus deployed:", address(ps));

        // ----------------------------------------------------
        // 5. Activate protocol
        // ----------------------------------------------------
        ps.activateProtocol();
        console2.log("Protocol activated");

        vm.stopBroadcast();
    }
}
