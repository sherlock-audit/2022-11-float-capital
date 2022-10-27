// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "@prb/math/contracts/PRBMathSD59x18.sol";

library MathUintFloat {
  /// @notice Multiplies two unsigned 60.18-decimal fixed-point numbers together, returning a new unsigned 60.18-decimal
  /// fixed-point number.
  /// @dev See the documentation for the "PRBMath.mulDivFixedPoint" function.
  /// @param x The multiplicand as an unsigned 60.18-decimal fixed-point number.
  /// @param y The multiplier as an unsigned 60.18-decimal fixed-point number.
  /// @return The product as an unsigned 60.18-decimal fixed-point number.
  function mul(uint256 x, uint256 y) internal pure returns (uint256) {
    // NOTE: this truncates rather than rounds the result:
    // return (x * y) / 1e18;
    return Math.mulDiv(x, y, 1e18);
  }

  /// @notice Divides two unsigned 60.18-decimal fixed-point numbers, returning a new unsigned 60.18-decimal fixed-point number.
  /// @dev
  /// Requirements:
  /// - The denominator cannot be zero.
  ///
  /// @param x The numerator as an unsigned 60.18-decimal fixed-point number.
  /// @param y The denominator as an unsigned 60.18-decimal fixed-point number.
  /// @return The quotient as an unsigned 60.18-decimal fixed-point number.
  function div(uint256 x, uint256 y) internal pure returns (uint256) {
    // return (x * 1e18) / y;
    return Math.mulDiv(x, 1e18, y);
  }
}

library MathIntFloat {
  function mul(int256 x, int256 y) internal pure returns (int256) {
    return (x * y) / 1e18;
    // return PRBMathSD59x18.mul(x, y);
  }

  function div(int256 x, int256 y) internal pure returns (int256) {
    // return (x * ]1e18) / y;
    return PRBMathSD59x18.div(x, y);
  }

  // Function copied from Openzeppelin: @openzeppelin/contracts/utils/math/SignedMath.sol
  function abs(int256 n) internal pure returns (uint256) {
    unchecked {
      // must be unchecked in order to support `n = type(int256).min`
      return uint256(n >= 0 ? n : -n);
    }
  }
}
