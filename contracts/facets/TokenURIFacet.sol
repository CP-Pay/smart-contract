// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTokenURI} from "../libraries/LibTokenURI.sol";
import {LibERC20} from "../libraries/LibERC20.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract TokenURIFacet {
    function tokenURI() external view returns (string memory) {
        LibTokenURI.TokenURIStorage storage ts = LibTokenURI.tokenURIStorage();
        LibERC20.ERC20Storage storage es = LibERC20.erc20Storage();
        
        string memory svg = _generateSVG();
        string memory svgBase64 = _encodeBase64(bytes(svg));
        
        string memory json = string(abi.encodePacked(
            '{"name":"',
            es.name,
            '","symbol":"',
            es.symbol,
            '","description":"',
            ts.description,
            '","image":"data:image/svg+xml;base64,',
            svgBase64,
            '","external_url":"',
            ts.externalUrl,
            '","background_color":"',
            ts.backgroundColor,
            '","attributes":[{"trait_type":"Type","value":"ERC20"},{"trait_type":"Decimals","value":"',
            _toString(es.decimals),
            '"}]}'
        ));
        
        return string(abi.encodePacked(
            "data:application/json;base64,",
            _encodeBase64(bytes(json))
        ));
    }

    function _generateSVG() internal view returns (string memory) {
        LibERC20.ERC20Storage storage es = LibERC20.erc20Storage();
        
        return string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">',
            '<defs>',
            '<linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">',
            '<stop offset="0%" style="stop-color:#667eea;stop-opacity:1" />',
            '<stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" />',
            '</linearGradient>',
            '<filter id="shadow">',
            '<feDropShadow dx="0" dy="4" stdDeviation="4" flood-opacity="0.3"/>',
            '</filter>',
            '</defs>',
            '<rect width="400" height="400" fill="url(#grad1)"/>',
            '<circle cx="200" cy="200" r="120" fill="white" fill-opacity="0.2" filter="url(#shadow)"/>',
            '<text x="200" y="180" font-family="Arial, sans-serif" font-size="80" font-weight="bold" fill="white" text-anchor="middle" filter="url(#shadow)">',
            es.symbol,
            '</text>',
            '<text x="200" y="240" font-family="Arial, sans-serif" font-size="24" fill="white" fill-opacity="0.9" text-anchor="middle">',
            es.name,
            '</text>',
            '<circle cx="200" cy="200" r="140" fill="none" stroke="white" stroke-width="2" stroke-opacity="0.3"/>',
            '<circle cx="200" cy="200" r="155" fill="none" stroke="white" stroke-width="1" stroke-opacity="0.2"/>',
            '</svg>'
        ));
    }

    function getLogo() external view returns (string memory) {
        return _generateSVG();
    }

    function getMetadata() external view returns (string memory) {
        LibTokenURI.TokenURIStorage storage ts = LibTokenURI.tokenURIStorage();
        LibERC20.ERC20Storage storage es = LibERC20.erc20Storage();
        
        return string(abi.encodePacked(
            '{"name":"',
            es.name,
            '","symbol":"',
            es.symbol,
            '","description":"',
            ts.description,
            '","external_url":"',
            ts.externalUrl,
            '","background_color":"',
            ts.backgroundColor,
            '"}'
        ));
    }

    function _encodeBase64(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";

        string memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        uint256 encodedLen = 4 * ((data.length + 2) / 3);
        string memory result = new string(encodedLen);

        assembly {
            let tablePtr := add(table, 1)
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))
            let resultPtr := add(result, 32)

            for {} lt(dataPtr, endPtr) {}
            {
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1)
            }

            switch mod(mload(data), 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }
        }

        return result;
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
