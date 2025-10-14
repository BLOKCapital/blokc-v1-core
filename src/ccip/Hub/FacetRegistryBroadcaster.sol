// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Client, IRouterClient } from "src/interfaces/ICCIP.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract FacetRegistryBroadcaster is Ownable, Pausable {
    IRouterClient public ccipRouter;
    uint64 public destinationChainSelector; 
    address public receiver;

    enum FacetAction { Add, Replace, Remove }
    enum PoolAction { Add, Remove }

    error ReceiverNotSet();
    error InsufficientETHBalance(uint256 required, uint256 available);
    error InvalidChainSelector();

    event FacetUpdateSent(address indexed facet, bytes4[] selectors, FacetAction action, uint256 fee);
    event PoolUpdateSent(address indexed pool, string pairName, string dexId, PoolAction action, uint256 fee);
    event ReceiverSet(address indexed receiver);
    event DestinationChainSelectorSet(uint64 indexed chainSelector);
    event ETHWithdrawn(address indexed to, uint256 amount);

    /// @dev This is the broadcasting contract that sends facet update instructions to the receiver contract on another chain.
    /// @dev The broadcaster does not manage facets itself; it only sends updates.
    /// @dev The broadcaster contract is solely responsible for dealing with native ETH for paying CCIP fees. 

    /// @dev For building & testing purposes upgradeable addresses are used at constructor level to allow easy changes.

    /// @param _ccipRouter The address of the CCIP router contract. (In this case, the router on Arbitrum mainnet).
    /// @param _destinationChainSelector The chain selector for the destination chain. Here the destination chain is Base mainnet.
    constructor(address initialOwner, address _ccipRouter, uint64 _destinationChainSelector) Ownable(initialOwner) {
        require(_ccipRouter != address(0), "Invalid router address");
        require(_destinationChainSelector != 0, "Invalid chain selector");
        ccipRouter = IRouterClient(_ccipRouter);
        destinationChainSelector = _destinationChainSelector;
    }
    
    /// @notice Set the receiver contract address on the destination chain.
    function setReceiver(address _receiver) external onlyOwner {
        require(_receiver != address(0), "Invalid receiver address");
        receiver = _receiver;
        emit ReceiverSet(_receiver);
    }

    /// @notice Set the destination chain selector
    function setDestinationChainSelector(uint64 _chainSelector) external onlyOwner {
        require(_chainSelector != 0, "Invalid chain selector");
        destinationChainSelector = _chainSelector;
        emit DestinationChainSelectorSet(_chainSelector);
    }
    
    ///@dev Only prepares and broadcasts facet update instructions. Does not perform facet management.
    function broadcastFacetUpdate(address facet, bytes4[] memory selectors, FacetAction action) public onlyOwner whenNotPaused {
        
        ///@notice Receiver must be configured
        address _receiver = receiver; 
        if (_receiver == address(0)) revert ReceiverNotSet();
        
        // typeTag 1 = Facet
        bytes memory data = abi.encode(uint8(1), abi.encode(facet, selectors, action));

        bytes memory extraArgs = Client._argsToBytes(
            Client.EVMExtraArgsV1({ gasLimit: 300000 })
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: extraArgs,
            feeToken: address(0) // Native ETH
        });

        uint256 fee = ccipRouter.getFee(destinationChainSelector, message);
        uint256 balance = address(this).balance;

        ///@notice Ensure the contract has enough ETH to pay the fee
        if (balance < fee) revert InsufficientETHBalance(fee, balance);
        
        /// @notice Actual message sending to the destination chain with native ETH
        ccipRouter.ccipSend{value: fee}(destinationChainSelector, message);
        emit FacetUpdateSent(facet, selectors, action, fee);
    }

    /// @notice Broadcast add facet functions instruction
    function broadcastAddFunctions(address facet, bytes4[] memory selectors) external onlyOwner {
        broadcastFacetUpdate(facet, selectors, FacetAction.Add);
    }

    /// @notice Broadcast replace facet functions instruction
    function broadcastReplaceFunctions(address facet, bytes4[] memory selectors) external onlyOwner {
        broadcastFacetUpdate(facet, selectors, FacetAction.Replace);
    }

    /// @notice Broadcast remove facet functions instruction
    function broadcastRemoveFunctions(bytes4[] memory selectors) external onlyOwner {
        // For remove, facet address should be address(0) according to FacetRegistry implementation
        broadcastFacetUpdate(address(0), selectors, FacetAction.Remove);
    }

    /// @dev Broadcast liquidity pool registry update (add/remove). Management is performed on receiver chain.
    function broadcastPoolUpdate(address pool, string memory pairName, string memory dexId, PoolAction action) public onlyOwner whenNotPaused {
        ///@notice Receiver must be configured
        address _receiver = receiver;
        if (_receiver == address(0)) revert ReceiverNotSet();
        
        // typeTag 2 = Pool
        bytes memory data = abi.encode(uint8(2), abi.encode(pool, pairName, dexId, action));

        bytes memory extraArgs = Client._argsToBytes(
            Client.EVMExtraArgsV1({ gasLimit: 300000 })
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: extraArgs,
            feeToken: address(0) // Native ETH
        });

        uint256 fee = ccipRouter.getFee(destinationChainSelector, message);
        uint256 balance = address(this).balance;

        if (balance < fee) revert InsufficientETHBalance(fee, balance);

        ccipRouter.ccipSend{value: fee}(destinationChainSelector, message);
        emit PoolUpdateSent(pool, pairName, dexId, action, fee);
    }

    /// @notice Broadcast add pool instruction
    function broadcastAddPool(address pool, string memory pairName, string memory dexId) external onlyOwner {
        broadcastPoolUpdate(pool, pairName, dexId, PoolAction.Add);
    }

    /// @notice Broadcast remove pool instruction
    function broadcastRemovePool(address pool) external onlyOwner {
        // For remove, we don't need pairName and dexId, but they're required by the function signature
        broadcastPoolUpdate(pool, "", "", PoolAction.Remove);
    }

    /// @notice Batch broadcast multiple facet updates
    function batchBroadcastFacetUpdates(
        address[] memory facets,
        bytes4[][] memory selectors,
        FacetAction[] memory actions
    ) external onlyOwner {
        require(facets.length == selectors.length && selectors.length == actions.length, "Array length mismatch");
        
        for (uint256 i = 0; i < facets.length; i++) {
            broadcastFacetUpdate(facets[i], selectors[i], actions[i]);
        }
    }

    /// @notice Batch broadcast multiple pool updates
    function batchBroadcastPoolUpdates(
        address[] memory pools,
        string[] memory pairNames,
        string[] memory dexIds,
        PoolAction[] memory actions
    ) external onlyOwner {
        require(
            pools.length == pairNames.length && 
            pairNames.length == dexIds.length && 
            dexIds.length == actions.length, 
            "Array length mismatch"
        );
        
        for (uint256 i = 0; i < pools.length; i++) {
            broadcastPoolUpdate(pools[i], pairNames[i], dexIds[i], actions[i]);
        }
    }

    /// @dev Allow the contract to receive ETH
    receive() external payable {}

    /// @dev Allow the contract to receive ETH via fallback
    fallback() external payable {}

    /// @notice Withdraw ETH from the contract (only owner)
    function withdrawETH(uint256 amount) external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance < amount) revert InsufficientETHBalance(amount, balance);
        
        address ownerAddr = owner();
        payable(ownerAddr).transfer(amount);
        emit ETHWithdrawn(ownerAddr, amount);
    }

    /// @notice Withdraw all ETH from the contract (only owner)
    function withdrawAllETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        
        address ownerAddr = owner();
        payable(ownerAddr).transfer(balance);
        emit ETHWithdrawn(ownerAddr, balance);
    }

    /// @notice Get the current ETH balance of the contract
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Estimate the fee for broadcasting a facet update
    function estimateFacetUpdateFee(address facet, bytes4[] memory selectors, FacetAction action) external view returns (uint256) {
        bytes memory data = abi.encode(uint8(1), abi.encode(facet, selectors, action));
        
        bytes memory extraArgs = Client._argsToBytes(
            Client.EVMExtraArgsV1({ gasLimit: 300000 })
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: extraArgs,
            feeToken: address(0)
        });

        return ccipRouter.getFee(destinationChainSelector, message);
    }

    /// @notice Estimate the fee for broadcasting a pool update
    function estimatePoolUpdateFee(address pool, string memory pairName, string memory dexId, PoolAction action) external view returns (uint256) {
        bytes memory data = abi.encode(uint8(2), abi.encode(pool, pairName, dexId, action));
        
        bytes memory extraArgs = Client._argsToBytes(
            Client.EVMExtraArgsV1({ gasLimit: 300000 })
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: extraArgs,
            feeToken: address(0)
        });

        return ccipRouter.getFee(destinationChainSelector, message);
    }

    /// @notice Pause the contract (only owner)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract (only owner)
    function unpause() external onlyOwner {
        _unpause();
    }
}
