// SPDX-License-Identifier: MIT
pragma solidity=0.8.26;

interface IZorkitronGenerator {
    function depositCollateral(address lpNFT) external returns (bool success);
}