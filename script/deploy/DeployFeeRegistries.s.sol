// SPDX-License-Identifier: MIT License
pragma solidity >=0.8.31;

import { BaseScript } from "script/Base.s.sol";
import { console2 } from "forge-std/console2.sol";

import { FeeRegistry } from "src/fees/FeeRegistry.sol";
import { TreasuryRegistry } from "src/fees/TreasuryRegistry.sol";
import { OnboarderRegistry } from "src/fees/OnboarderRegistry.sol";

/**
 * @title DeployFeeRegistries
 * @notice Deploys the three DAO-owned fee registries: FeeRegistry (fee schedule + safety caps),
 *         TreasuryRegistry (single USDC receiver), OnboarderRegistry (onboarder eligibility).
 *         All are deployer-owned at deploy — transfer ownership to the DAO multisig after wiring.
 *
 *         Post-deploy DAO ops:
 *           1. TreasuryRegistry.setTreasuryAddress(treasury, proposalRef)
 *           2. OnboarderRegistry.addOnboarder(...) for each eligible community onboarder
 *           3. (optional) FeeRegistry.set* — the spec's initial rates are already set
 */
contract DeployFeeRegistries is BaseScript {
    function run() public broadcaster {
        setUp();

        FeeRegistry feeRegistry = new FeeRegistry(deployer);
        console2.log("FeeRegistry deployed at:", address(feeRegistry));

        TreasuryRegistry treasuryRegistry = new TreasuryRegistry(deployer);
        console2.log("TreasuryRegistry deployed at:", address(treasuryRegistry));

        OnboarderRegistry onboarderRegistry = new OnboarderRegistry(deployer);
        console2.log("OnboarderRegistry deployed at:", address(onboarderRegistry));

        console2.log("");
        console2.log("Next steps:");
        console2.log("1. DAO: transfer ownership of all three registries to the DAO multisig");
        console2.log("2. DAO: treasuryRegistry.setTreasuryAddress(<treasury>, <proposalRef>)");
        console2.log("3. DAO: onboarderRegistry.addOnboarder(<wallet>) per eligible onboarder");
        console2.log("4. Deployer: configureFeeModule on each garden (ConfigureFeeModules script)");
    }
}
