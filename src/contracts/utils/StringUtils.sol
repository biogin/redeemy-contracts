// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library StringUtils {
    function trim(string memory str) internal pure returns (string memory) {
        bytes memory _str = bytes(str);

        if (_str.length == 0) {
            return "";
        }

        uint start = 0;
        uint end = _str.length;
        uint trimmedLength;

        // Find the start index of non-space characters
        for (uint i = 0; i < _str.length; i++) {
            if (_str[i] != 0x20) {
                start = i;
                break;
            }
        }

        // Find the end index of non-space characters
        for (uint i = _str.length - 1; i >= start; i--) {
            if (_str[i] != 0x20) {
                end = i + 1;
                break;
            }
        }

        trimmedLength = end - start;
        bytes memory trimmed = new bytes(trimmedLength);

        // Trim and convert to lowercase simultaneously
        for (uint i = start; i < end; i++) {
            trimmed[i - start] = _str[i];
        }

        return string(trimmed);
    }
}
