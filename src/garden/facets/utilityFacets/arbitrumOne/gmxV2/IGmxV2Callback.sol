// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

/*
 * GMX V2 order-callback types.
 * The EventLogData shape is copied VERBATIM from gmx-synthetics contracts/event/EventUtils.sol so that
 * the afterOrder* selectors match what GMX's keepers call. Field names are irrelevant to the ABI; the
 * nested tuple shape is what fixes the selector. This contract never reads the event payload — it
 * correlates work by the `key` argument alone — but the parameters must still decode what GMX sends.
 */
library GmxEventUtils {
    struct EventLogData {
        AddressItems addressItems;
        UintItems uintItems;
        IntItems intItems;
        BoolItems boolItems;
        Bytes32Items bytes32Items;
        BytesItems bytesItems;
        StringItems stringItems;
    }

    struct AddressItems {
        AddressKeyValue[] items;
        AddressArrayKeyValue[] arrayItems;
    }

    struct UintItems {
        UintKeyValue[] items;
        UintArrayKeyValue[] arrayItems;
    }

    struct IntItems {
        IntKeyValue[] items;
        IntArrayKeyValue[] arrayItems;
    }

    struct BoolItems {
        BoolKeyValue[] items;
        BoolArrayKeyValue[] arrayItems;
    }

    struct Bytes32Items {
        Bytes32KeyValue[] items;
        Bytes32ArrayKeyValue[] arrayItems;
    }

    struct BytesItems {
        BytesKeyValue[] items;
        BytesArrayKeyValue[] arrayItems;
    }

    struct StringItems {
        StringKeyValue[] items;
        StringArrayKeyValue[] arrayItems;
    }

    struct AddressKeyValue {
        string key;
        address value;
    }

    struct AddressArrayKeyValue {
        string key;
        address[] value;
    }

    struct UintKeyValue {
        string key;
        uint256 value;
    }

    struct UintArrayKeyValue {
        string key;
        uint256[] value;
    }

    struct IntKeyValue {
        string key;
        int256 value;
    }

    struct IntArrayKeyValue {
        string key;
        int256[] value;
    }

    struct BoolKeyValue {
        string key;
        bool value;
    }

    struct BoolArrayKeyValue {
        string key;
        bool[] value;
    }

    struct Bytes32KeyValue {
        string key;
        bytes32 value;
    }

    struct Bytes32ArrayKeyValue {
        string key;
        bytes32[] value;
    }

    struct BytesKeyValue {
        string key;
        bytes value;
    }

    struct BytesArrayKeyValue {
        string key;
        bytes[] value;
    }

    struct StringKeyValue {
        string key;
        string value;
    }

    struct StringArrayKeyValue {
        string key;
        string[] value;
    }

}

/// @title IOrderCallbackReceiver
/// @notice GMX V2 order lifecycle callbacks. Selectors must match gmx-synthetics
/// contracts/callback/IOrderCallbackReceiver.sol.
interface IOrderCallbackReceiver {
    function afterOrderExecution(bytes32 key, GmxEventUtils.EventLogData memory orderData, GmxEventUtils.EventLogData memory eventData) external;
    function afterOrderCancellation(bytes32 key, GmxEventUtils.EventLogData memory orderData, GmxEventUtils.EventLogData memory eventData) external;
    function afterOrderFrozen(bytes32 key, GmxEventUtils.EventLogData memory orderData, GmxEventUtils.EventLogData memory eventData) external;
}
