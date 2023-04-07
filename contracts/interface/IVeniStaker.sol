// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IVeniStaker {
    function chefStake(address to, uint256 amount) external;
}