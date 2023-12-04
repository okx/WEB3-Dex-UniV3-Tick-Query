// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "@openzeppelin-3.4.1/contracts/proxy/BeaconProxy.sol";

contract RamsesBeaconProxy is BeaconProxy {
    // Doing so the CREATE2 hash is easier to calculate
    constructor() payable BeaconProxy(msg.sender, "") {}
}
