// SPDX-License-Identifier: MIT
pragma solidity=0.8.26;

library ZorkitronLibrary {
    function sortTokens(address currencyA, address currencyB) internal pure returns (
        address currency0,
        address currency1
    ) {
        require(currencyA != currencyB, 'ZorkitronLibrary: IDENTICAL_ADDRESSES');
        (currency0, currency1) = currencyA < currencyB ? (currencyA, currencyB) : (currencyB, currencyA);
    }

}

