// RUN: %target-build-swift %s
// RUN: %target-swift-frontend -emit-sil %s | %FileCheck %s

// SR-12493: SIL memory lifetime verification error due to
// `SILCloner::visitAllocStack` not copying the `[dynamic_lifetime]` attribute.

import _Differentiation

enum Enum {
  case a
}

struct Tensor<T>: Differentiable {
  @noDerivative var x: T
  @noDerivative var optional: Int?

  init(_ x: T, _ e: Enum) {
    self.x = x
    switch e {
      case .a: optional = 1
    }
  }

  // Definite initialization triggers for this initializer.
  @differentiable
  init(_ x: T, _ other: Self) {
    self = Self(x, Enum.a)
  }
}

// Check that `allock_stack [dynamic_lifetime]` attribute is correctly cloned.

// CHECK-LABEL: sil hidden @$s4main6TensorVyACyxGx_ADtcfC : $@convention(method) <T> (@in T, @in Tensor<T>, @thin Tensor<T>.Type) -> @out Tensor<T> {
// CHECK: [[SELF_ALLOC:%.*]] = alloc_stack [dynamic_lifetime] $Tensor<T>, var, name "self"

// CHECK-LABEL: sil hidden @AD__$s4main6TensorVyACyxGx_ADtcfC__vjp_src_0_wrt_1_l : $@convention(method) <τ_0_0> (@in τ_0_0, @in Tensor<τ_0_0>, @thin Tensor<τ_0_0>.Type) -> (@out Tensor<τ_0_0>, @owned @callee_guaranteed @substituted <τ_0_0, τ_0_1> (@in_guaranteed τ_0_0) -> @out τ_0_1 for <Tensor<τ_0_0>.TangentVector, Tensor<τ_0_0>.TangentVector>) {
// CHECK: [[SELF_ALLOC:%.*]] = alloc_stack [dynamic_lifetime] $Tensor<τ_0_0>, var, name "self"

// Original error:
// SIL memory lifetime failure in @AD__$s5crash6TensorVyACyxGx_ADtcfC__vjp_src_0_wrt_1_l: memory is not initialized, but should
// memory location:   %29 = struct_element_addr %5 : $*Tensor<τ_0_0>, #Tensor.x // user: %30
// at instruction:   destroy_addr %29 : $*τ_0_0                     // id: %30
