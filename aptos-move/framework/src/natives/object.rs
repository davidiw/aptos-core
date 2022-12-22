// Copyright (c) Aptos
// SPDX-License-Identifier: Apache-2.0

use crate::natives::account::{CreateSignerGasParameters, GasParameters};
use move_binary_format::errors::PartialVMResult;
use move_core_types::account_address::AccountAddress;
use move_vm_runtime::native_functions::{NativeContext, NativeFunction};
use move_vm_types::{
    loaded_data::runtime_types::Type, natives::function::NativeResult, pop_arg, values::Value,
};
use smallvec::smallvec;
use std::collections::VecDeque;
use std::sync::Arc;

/***************************************************************************************************
 * native fun create_signer_internal
 *
 *   gas cost: base_cost
 *
 **************************************************************************************************/
fn native_create_signer_internal(
    gas_params: &CreateSignerGasParameters,
    _context: &mut NativeContext,
    ty_args: Vec<Type>,
    mut arguments: VecDeque<Value>,
) -> PartialVMResult<NativeResult> {
    debug_assert!(ty_args.is_empty());
    debug_assert!(arguments.len() == 1);

    let address = pop_arg!(arguments, AccountAddress);
    Ok(NativeResult::ok(
        gas_params.base,
        smallvec![Value::signer(address)],
    ))
}

pub fn make_native_create_signer_internal(gas_params: CreateSignerGasParameters) -> NativeFunction {
    Arc::new(move |context, ty_args, args| {
        native_create_signer_internal(&gas_params, context, ty_args, args)
    })
}

/***************************************************************************************************
 * module
 *
 **************************************************************************************************/
pub fn make_all(gas_params: GasParameters) -> impl Iterator<Item = (String, NativeFunction)> {
    let natives = [(
        "create_signer_internal",
        make_native_create_signer_internal(gas_params.create_signer),
    )];

    crate::natives::helpers::make_module_natives(natives)
}
