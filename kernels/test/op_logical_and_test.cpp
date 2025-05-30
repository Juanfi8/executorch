/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#include <executorch/kernels/test/BinaryLogicalOpTest.h>
#include <executorch/kernels/test/FunctionHeaderWrapper.h> // Declares the operator

#include <gtest/gtest.h>

using executorch::aten::Tensor;

class OpLogicalAndTest : public torch::executor::testing::BinaryLogicalOpTest {
 protected:
  Tensor& op_out(const Tensor& self, const Tensor& other, Tensor& out)
      override {
    return torch::executor::aten::logical_and_outf(context_, self, other, out);
  }

  double op_reference(double x, double y) const override {
    uint64_t lhs, rhs;
    std::memcpy(&lhs, &x, sizeof(lhs));
    std::memcpy(&rhs, &y, sizeof(rhs));
    return lhs && rhs;
  }
};

IMPLEMENT_BINARY_LOGICAL_OP_TEST(OpLogicalAndTest)
