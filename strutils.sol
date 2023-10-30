// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library strutils {
        struct slice {
        uint _len;
        uint _ptr;
    }

    function toString(uint256 value, uint8 digits) internal pure returns (string memory) {
        bytes memory result = new bytes(digits);
        for (uint8 i = 0; i < digits; i++) {
            result[digits - 1 - i] = bytes1(uint8(48 + (value / (10**i)) % 10));
        }
        return string(result);
    }
        function toSlice(string memory self) internal pure returns (slice memory) {
        uint ptr;
        assembly {
            ptr := add(self, 0x20)
        }
        return slice(bytes(self).length, ptr);
    }

    function len(slice memory self) internal pure returns (uint) {
        return self._len;
    }
        function equals(slice memory self, slice memory other) internal pure returns (bool) {
        if (self._len != other._len) {
            return false;
        } else {
            for (uint i = 0; i < self._len; i++) {
                if (load(self, i) != load(other, i)) {
                    return false;
                }
            }
            return true;
        }
    }

    function load(slice memory self, uint index) internal pure returns (bytes1) {
        require(index < self._len, "Index out of range");
        return bytes1(uint8(loadPtr(self, index)));
    }

    function loadPtr(slice memory self, uint index) internal pure returns (uint) {
        require(index < self._len, "Index out of range");
        return self._ptr + index;
    }
    function substringFromIndex(slice memory self, uint start, uint length) internal pure returns (slice memory) {
        require(start + length <= self._len, "Substr out of range");
        return slice(length, self._ptr + start);
    }
}
