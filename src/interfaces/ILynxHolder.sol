//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface ILynxHolder {
    /**
     * Check the total token amount in this contract and return the amount of tokens in tier 1 and tier 2 depending on the amount held by user.
     * @return tier1Divs Amount of tokens in tier 1
     * @return tier2Divs Amount of tokens in tier 2
     */
    function getTiers() external view returns (uint tier1Divs, uint tier2Divs);

    /**
     * @notice This function takes a snapshot of current staked amounts to be used for distribution.
     * @param id The snapshot ID to take
     */
    function takeSnapshot(uint id) external;

    /**
     * @notice This function gets the snapshot of the user at the time of distribution, the SNAP ID is determined by the caller.
     * @param _user The user to get the snapshot for
     * @param snapId The snapshot ID to get the user's balance at
     */
    function getUserBalanceAtSnapId(
        address _user,
        uint snapId
    ) external view returns (uint);
}
