// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "openzeppelin/token/ERC20/IERC20.sol";

interface ILynx is IERC20 {
    function getUserSnapshotAt(
        address user,
        uint snapId
    ) external view returns (uint);

    function takeSnapshot() external;

    function snapshots(
        uint snapshotId
    ) external view returns (uint t1Total, uint t2Total, uint timestamp);

    function currentSnapId() external view returns (uint);

    function isDividendExempt(address user) external view returns (bool);
}
