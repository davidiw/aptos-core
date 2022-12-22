
<a name="0x1_object"></a>

# Module `0x1::object`

This defines a proposed Aptos object model with the intent to provide the following properties:
* Decouple data from ownership
* Objects are stored as resources within an account
* OwnerAbility defines ownership of an object
* Heterogeneous types stored in a single container
* Decoupled data from ownership allows or ownership to be to an ambiguous type
* Ambiguous types can be homogeneous thus bypassing restrictions on heterogeneous collections
* Make data immobile, while making ownership of data flexible
* Resources cannot be easily moved without explicit permission by the module that defines them
* OwnerAbility has no restrictions where it flows
* This allows for a creator to always managed all objects created by them
* Data is globally accessible
* Data resides in resources which cannot be moved and therefore are always accessible
* In contrast, storable struct can be placed into an inaccessible space
* Objects can be the source of events
* When data is mutated in a struct, ideally that struct would emit an event.
* The object model allows for events to be directly coupled with data.
* Objects definition / structure can prevented after creation
* At creation, the creator has the ability to configure the account as desired
* Afterward, the creator can delegate signer ability to continue to change definition
but it can also be discarded or access prevented to ensure that an object maintains
consistent shape.
* An object should be highly configurable, the creator the following access privileges:
* Ownership
* Signer
* Deletion
* Mutation
* Reading
* Secure and guaranteed to not collide with existing accounts.
* Each address is generated in a collision-resistant fashion guaranteeing legitimate
accounts cannot be created within the same address.
* Two objects cannot be co-located due to an address being able to only store a single Object

TODO:
* Currently an object will be spread across distinct storage slots, this is not efficient.
We are currently exploring a concept of storage groups that will allow structs marked with
<code>[storage_group(GROUP)]</code> to be co-located in a storage slot.
* There is no means to borrow an object or a reference to an object. We are exploring how to
make it so that a reference to a global object can be returned from a function.
* There's no guarantee of correctness or consistency in object implementation. For example,
the API for generating a TypedOwnerAbility can differ from object to object. An object
could potentially be left in a partially deleted state. We are exploring interfaces that
would allow for calling functions on module, type pairs that implement certain functions.
* The ownership model allows for richer defintion of access control, such as specifying when
an object can be mutated, read, and moved. This can be extended to entry functions to
seamlessly allow a user to know prior to sending a transaction the potential implications
for their owned objects.
* The current demo is rather limited and needs to be extended to demonstrate more end-to-end.


-  [Resource `Object`](#0x1_object_Object)
-  [Struct `CreatorAbility`](#0x1_object_CreatorAbility)
-  [Struct `DeleteAbility`](#0x1_object_DeleteAbility)
-  [Struct `SignerAbility`](#0x1_object_SignerAbility)
-  [Struct `OwnerAbility`](#0x1_object_OwnerAbility)
-  [Struct `TypedOwnerAbility`](#0x1_object_TypedOwnerAbility)
-  [Resource `ObjectStore`](#0x1_object_ObjectStore)
-  [Struct `DepositEvent`](#0x1_object_DepositEvent)
-  [Struct `WithdrawEvent`](#0x1_object_WithdrawEvent)
-  [Constants](#@Constants_0)
-  [Function `init_store`](#0x1_object_init_store)
-  [Function `withdraw`](#0x1_object_withdraw)
-  [Function `deposit`](#0x1_object_deposit)
-  [Function `deposit_typed`](#0x1_object_deposit_typed)
-  [Function `contains`](#0x1_object_contains)
-  [Function `create_object_id`](#0x1_object_create_object_id)
-  [Function `create_object`](#0x1_object_create_object)
-  [Function `create_guid`](#0x1_object_create_guid)
-  [Function `generate_delete_ability`](#0x1_object_generate_delete_ability)
-  [Function `delete`](#0x1_object_delete)
-  [Function `new_event_handle`](#0x1_object_new_event_handle)
-  [Function `create_signer_internal`](#0x1_object_create_signer_internal)
-  [Function `generate_signer_ability`](#0x1_object_generate_signer_ability)
-  [Function `create_signer`](#0x1_object_create_signer)
-  [Function `generate_owner_ability`](#0x1_object_generate_owner_ability)
-  [Function `owner_ability_address`](#0x1_object_owner_ability_address)
-  [Function `typed_owner_ability_address`](#0x1_object_typed_owner_ability_address)
-  [Function `to_typed_owner_ability`](#0x1_object_to_typed_owner_ability)
-  [Function `to_owner_ability`](#0x1_object_to_owner_ability)


<pre><code><b>use</b> <a href="account.md#0x1_account">0x1::account</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/from_bcs.md#0x1_from_bcs">0x1::from_bcs</a>;
<b>use</b> <a href="guid.md#0x1_guid">0x1::guid</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/hash.md#0x1_hash">0x1::hash</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table">0x1::table</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a name="0x1_object_Object"></a>

## Resource `Object`



<pre><code><b>struct</b> <a href="object.md#0x1_object_Object">Object</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>guid_creation_num: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x1_object_CreatorAbility"></a>

## Struct `CreatorAbility`

This is a one time ability given to the creator to configure the object as necessary


<pre><code><b>struct</b> <a href="object.md#0x1_object_CreatorAbility">CreatorAbility</a> <b>has</b> drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>self: <b>address</b></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x1_object_DeleteAbility"></a>

## Struct `DeleteAbility`

The owner of this ability can delete an object


<pre><code><b>struct</b> <a href="object.md#0x1_object_DeleteAbility">DeleteAbility</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>self: <b>address</b></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x1_object_SignerAbility"></a>

## Struct `SignerAbility`

The owner of this ability can generate the object's signer


<pre><code><b>struct</b> <a href="object.md#0x1_object_SignerAbility">SignerAbility</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>self: <b>address</b></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x1_object_OwnerAbility"></a>

## Struct `OwnerAbility`

This implies that this individual owns this object


<pre><code><b>struct</b> <a href="object.md#0x1_object_OwnerAbility">OwnerAbility</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>self: <b>address</b></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x1_object_TypedOwnerAbility"></a>

## Struct `TypedOwnerAbility`

This implies that the individual owns this object and it contains a specific type / resource


<pre><code><b>struct</b> <a href="object.md#0x1_object_TypedOwnerAbility">TypedOwnerAbility</a>&lt;T: key&gt; <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>self: <b>address</b></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x1_object_ObjectStore"></a>

## Resource `ObjectStore`



<pre><code><b>struct</b> <a href="object.md#0x1_object_ObjectStore">ObjectStore</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>inner: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;<b>address</b>, <a href="object.md#0x1_object_OwnerAbility">object::OwnerAbility</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>deposits: <a href="event.md#0x1_event_EventHandle">event::EventHandle</a>&lt;<a href="object.md#0x1_object_DepositEvent">object::DepositEvent</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>withdraws: <a href="event.md#0x1_event_EventHandle">event::EventHandle</a>&lt;<a href="object.md#0x1_object_WithdrawEvent">object::WithdrawEvent</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x1_object_DepositEvent"></a>

## Struct `DepositEvent`



<pre><code><b>struct</b> <a href="object.md#0x1_object_DepositEvent">DepositEvent</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>object_id: <b>address</b></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x1_object_WithdrawEvent"></a>

## Struct `WithdrawEvent`



<pre><code><b>struct</b> <a href="object.md#0x1_object_WithdrawEvent">WithdrawEvent</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>object_id: <b>address</b></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="@Constants_0"></a>

## Constants


<a name="0x1_object_EOBJECT_EXISTS"></a>

An object already exists at this address


<pre><code><b>const</b> <a href="object.md#0x1_object_EOBJECT_EXISTS">EOBJECT_EXISTS</a>: u64 = 0;
</code></pre>



<a name="0x1_object_EOBJECT_TYPE_EXISTS"></a>

An object of that type already exists at this address


<pre><code><b>const</b> <a href="object.md#0x1_object_EOBJECT_TYPE_EXISTS">EOBJECT_TYPE_EXISTS</a>: u64 = 1;
</code></pre>



<a name="0x1_object_OBJECT_ADDRESS_SCHEME"></a>

Scheme identifier used to generate an object's address. This serves as domain separation to
prevent existing authentication key and resource account derivation to produce an object
address.


<pre><code><b>const</b> <a href="object.md#0x1_object_OBJECT_ADDRESS_SCHEME">OBJECT_ADDRESS_SCHEME</a>: u8 = 254;
</code></pre>



<a name="0x1_object_init_store"></a>

## Function `init_store`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_init_store">init_store</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_init_store">init_store</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <b>move_to</b>(
        <a href="account.md#0x1_account">account</a>,
        <a href="object.md#0x1_object_ObjectStore">ObjectStore</a> {
            inner: <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>(),
            deposits: <a href="account.md#0x1_account_new_event_handle">account::new_event_handle</a>(<a href="account.md#0x1_account">account</a>),
            withdraws: <a href="account.md#0x1_account_new_event_handle">account::new_event_handle</a>(<a href="account.md#0x1_account">account</a>),
        },
    )
}
</code></pre>



</details>

<a name="0x1_object_withdraw"></a>

## Function `withdraw`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_withdraw">withdraw</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, addr: <b>address</b>): <a href="object.md#0x1_object_OwnerAbility">object::OwnerAbility</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_withdraw">withdraw</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, addr: <b>address</b>): <a href="object.md#0x1_object_OwnerAbility">OwnerAbility</a> <b>acquires</b> <a href="object.md#0x1_object_ObjectStore">ObjectStore</a> {
    <b>let</b> object_store = <b>borrow_global_mut</b>&lt;<a href="object.md#0x1_object_ObjectStore">ObjectStore</a>&gt;(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(<a href="account.md#0x1_account">account</a>));
    <a href="event.md#0x1_event_emit_event">event::emit_event</a>(&<b>mut</b> object_store.withdraws, <a href="object.md#0x1_object_WithdrawEvent">WithdrawEvent</a> { object_id: addr });
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_remove">table::remove</a>(&<b>mut</b> object_store.inner, addr)
}
</code></pre>



</details>

<a name="0x1_object_deposit"></a>

## Function `deposit`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_deposit">deposit</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="object.md#0x1_object">object</a>: <a href="object.md#0x1_object_OwnerAbility">object::OwnerAbility</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_deposit">deposit</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="object.md#0x1_object">object</a>: <a href="object.md#0x1_object_OwnerAbility">OwnerAbility</a>) <b>acquires</b> <a href="object.md#0x1_object_ObjectStore">ObjectStore</a> {
    <b>let</b> object_store = <b>borrow_global_mut</b>&lt;<a href="object.md#0x1_object_ObjectStore">ObjectStore</a>&gt;(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(<a href="account.md#0x1_account">account</a>));
    <b>let</b> object_addr = <a href="object.md#0x1_object_owner_ability_address">owner_ability_address</a>(&<a href="object.md#0x1_object">object</a>);
    <a href="event.md#0x1_event_emit_event">event::emit_event</a>(&<b>mut</b> object_store.deposits, <a href="object.md#0x1_object_DepositEvent">DepositEvent</a> { object_id: object_addr });
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_add">table::add</a>(&<b>mut</b> object_store.inner, object_addr, <a href="object.md#0x1_object">object</a>);
}
</code></pre>



</details>

<a name="0x1_object_deposit_typed"></a>

## Function `deposit_typed`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_deposit_typed">deposit_typed</a>&lt;T: key&gt;(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="object.md#0x1_object">object</a>: <a href="object.md#0x1_object_TypedOwnerAbility">object::TypedOwnerAbility</a>&lt;T&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_deposit_typed">deposit_typed</a>&lt;T: key&gt;(
    <a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    <a href="object.md#0x1_object">object</a>: <a href="object.md#0x1_object_TypedOwnerAbility">TypedOwnerAbility</a>&lt;T&gt;,
) <b>acquires</b> <a href="object.md#0x1_object_ObjectStore">ObjectStore</a> {
    <a href="object.md#0x1_object_deposit">deposit</a>(<a href="account.md#0x1_account">account</a>, <a href="object.md#0x1_object_to_owner_ability">to_owner_ability</a>(<a href="object.md#0x1_object">object</a>))
}
</code></pre>



</details>

<a name="0x1_object_contains"></a>

## Function `contains`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_contains">contains</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, addr: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_contains">contains</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, addr: <b>address</b>): bool <b>acquires</b> <a href="object.md#0x1_object_ObjectStore">ObjectStore</a> {
    <b>let</b> object_store = <b>borrow_global</b>&lt;<a href="object.md#0x1_object_ObjectStore">ObjectStore</a>&gt;(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(<a href="account.md#0x1_account">account</a>));
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&object_store.inner, addr)
}
</code></pre>



</details>

<a name="0x1_object_create_object_id"></a>

## Function `create_object_id`

Object addresses are equal to the sha3_256([creator addres | seed | 0xFE]).


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_create_object_id">create_object_id</a>(source: &<b>address</b>, seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_create_object_id">create_object_id</a>(source: &<b>address</b>, seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <b>address</b> {
    <b>let</b> bytes = <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(source);
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_append">vector::append</a>(&<b>mut</b> bytes, seed);
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> bytes, <a href="object.md#0x1_object_OBJECT_ADDRESS_SCHEME">OBJECT_ADDRESS_SCHEME</a>);
    <a href="../../aptos-stdlib/doc/from_bcs.md#0x1_from_bcs_to_address">from_bcs::to_address</a>(<a href="../../aptos-stdlib/doc/hash.md#0x1_hash_sha3_256">hash::sha3_256</a>(bytes))
}
</code></pre>



</details>

<a name="0x1_object_create_object"></a>

## Function `create_object`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_create_object">create_object</a>(creator: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="object.md#0x1_object_CreatorAbility">object::CreatorAbility</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_create_object">create_object</a>(creator: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="object.md#0x1_object_CreatorAbility">CreatorAbility</a> {
    // create <a href="object.md#0x1_object">object</a> <b>address</b> needs <b>to</b> be distinct from create_resource_address
    <b>let</b> <b>address</b> = <a href="object.md#0x1_object_create_object_id">create_object_id</a>(&<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(creator), seed);
    <b>assert</b>!(!<b>exists</b>&lt;<a href="object.md#0x1_object_Object">Object</a>&gt;(<b>address</b>), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_already_exists">error::already_exists</a>(<a href="object.md#0x1_object_EOBJECT_EXISTS">EOBJECT_EXISTS</a>));
    <b>let</b> object_signer = <a href="object.md#0x1_object_create_signer_internal">create_signer_internal</a>(<b>address</b>);

    <b>move_to</b>(
        &object_signer,
        <a href="object.md#0x1_object_Object">Object</a> {
            guid_creation_num: 0,
        },
    );
    <a href="object.md#0x1_object_CreatorAbility">CreatorAbility</a> { self: <b>address</b> }
}
</code></pre>



</details>

<a name="0x1_object_create_guid"></a>

## Function `create_guid`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_create_guid">create_guid</a>(<a href="object.md#0x1_object">object</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>): <a href="guid.md#0x1_guid_GUID">guid::GUID</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_create_guid">create_guid</a>(<a href="object.md#0x1_object">object</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>): <a href="guid.md#0x1_guid_GUID">guid::GUID</a> <b>acquires</b> <a href="object.md#0x1_object_Object">Object</a> {
    <b>let</b> addr = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(<a href="object.md#0x1_object">object</a>);
    <b>let</b> object_data = <b>borrow_global_mut</b>&lt;<a href="object.md#0x1_object_Object">Object</a>&gt;(addr);
    <a href="guid.md#0x1_guid_create">guid::create</a>(addr, &<b>mut</b> object_data.guid_creation_num)
}
</code></pre>



</details>

<a name="0x1_object_generate_delete_ability"></a>

## Function `generate_delete_ability`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_generate_delete_ability">generate_delete_ability</a>(ability: &<a href="object.md#0x1_object_CreatorAbility">object::CreatorAbility</a>): <a href="object.md#0x1_object_DeleteAbility">object::DeleteAbility</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_generate_delete_ability">generate_delete_ability</a>(ability: &<a href="object.md#0x1_object_CreatorAbility">CreatorAbility</a>): <a href="object.md#0x1_object_DeleteAbility">DeleteAbility</a> {
    <a href="object.md#0x1_object_DeleteAbility">DeleteAbility</a> { self: ability.self }
}
</code></pre>



</details>

<a name="0x1_object_delete"></a>

## Function `delete`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_delete">delete</a>(ability: <a href="object.md#0x1_object_DeleteAbility">object::DeleteAbility</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_delete">delete</a>(ability: <a href="object.md#0x1_object_DeleteAbility">DeleteAbility</a>) <b>acquires</b> <a href="object.md#0x1_object_Object">Object</a> {
    <b>let</b> <a href="object.md#0x1_object">object</a> = <b>move_from</b>&lt;<a href="object.md#0x1_object_Object">Object</a>&gt;(ability.self);
    <b>let</b> <a href="object.md#0x1_object_Object">Object</a> {
        guid_creation_num: _,
    } = <a href="object.md#0x1_object">object</a>;
}
</code></pre>



</details>

<a name="0x1_object_new_event_handle"></a>

## Function `new_event_handle`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_new_event_handle">new_event_handle</a>&lt;T: drop, store&gt;(<a href="object.md#0x1_object">object</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>): <a href="event.md#0x1_event_EventHandle">event::EventHandle</a>&lt;T&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_new_event_handle">new_event_handle</a>&lt;T: drop + store&gt;(
    <a href="object.md#0x1_object">object</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
): <a href="event.md#0x1_event_EventHandle">event::EventHandle</a>&lt;T&gt; <b>acquires</b> <a href="object.md#0x1_object_Object">Object</a> {
    <a href="event.md#0x1_event_new_event_handle">event::new_event_handle</a>(<a href="object.md#0x1_object_create_guid">create_guid</a>(<a href="object.md#0x1_object">object</a>))
}
</code></pre>



</details>

<a name="0x1_object_create_signer_internal"></a>

## Function `create_signer_internal`



<pre><code><b>fun</b> <a href="object.md#0x1_object_create_signer_internal">create_signer_internal</a>(addr: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>fun</b> <a href="object.md#0x1_object_create_signer_internal">create_signer_internal</a>(addr: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>;
</code></pre>



</details>

<a name="0x1_object_generate_signer_ability"></a>

## Function `generate_signer_ability`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_generate_signer_ability">generate_signer_ability</a>(ability: &<a href="object.md#0x1_object_CreatorAbility">object::CreatorAbility</a>): <a href="object.md#0x1_object_SignerAbility">object::SignerAbility</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_generate_signer_ability">generate_signer_ability</a>(ability: &<a href="object.md#0x1_object_CreatorAbility">CreatorAbility</a>): <a href="object.md#0x1_object_SignerAbility">SignerAbility</a> {
    <a href="object.md#0x1_object_SignerAbility">SignerAbility</a> { self: ability.self }
}
</code></pre>



</details>

<a name="0x1_object_create_signer"></a>

## Function `create_signer`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_create_signer">create_signer</a>(ability: &<a href="object.md#0x1_object_SignerAbility">object::SignerAbility</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_create_signer">create_signer</a>(ability: &<a href="object.md#0x1_object_SignerAbility">SignerAbility</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a> {
    <a href="object.md#0x1_object_create_signer_internal">create_signer_internal</a>(ability.self)
}
</code></pre>



</details>

<a name="0x1_object_generate_owner_ability"></a>

## Function `generate_owner_ability`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_generate_owner_ability">generate_owner_ability</a>(ability: &<a href="object.md#0x1_object_CreatorAbility">object::CreatorAbility</a>): <a href="object.md#0x1_object_OwnerAbility">object::OwnerAbility</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_generate_owner_ability">generate_owner_ability</a>(ability: &<a href="object.md#0x1_object_CreatorAbility">CreatorAbility</a>): <a href="object.md#0x1_object_OwnerAbility">OwnerAbility</a> {
    <a href="object.md#0x1_object_OwnerAbility">OwnerAbility</a> { self: ability.self }
}
</code></pre>



</details>

<a name="0x1_object_owner_ability_address"></a>

## Function `owner_ability_address`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_owner_ability_address">owner_ability_address</a>(ability: &<a href="object.md#0x1_object_OwnerAbility">object::OwnerAbility</a>): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_owner_ability_address">owner_ability_address</a>(ability: &<a href="object.md#0x1_object_OwnerAbility">OwnerAbility</a>): <b>address</b> {
    ability.self
}
</code></pre>



</details>

<a name="0x1_object_typed_owner_ability_address"></a>

## Function `typed_owner_ability_address`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_typed_owner_ability_address">typed_owner_ability_address</a>&lt;T: key&gt;(ability: &<a href="object.md#0x1_object_TypedOwnerAbility">object::TypedOwnerAbility</a>&lt;T&gt;): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_typed_owner_ability_address">typed_owner_ability_address</a>&lt;T: key&gt;(ability: &<a href="object.md#0x1_object_TypedOwnerAbility">TypedOwnerAbility</a>&lt;T&gt;): <b>address</b> {
    ability.self
}
</code></pre>



</details>

<a name="0x1_object_to_typed_owner_ability"></a>

## Function `to_typed_owner_ability`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_to_typed_owner_ability">to_typed_owner_ability</a>&lt;T: key&gt;(ability: <a href="object.md#0x1_object_OwnerAbility">object::OwnerAbility</a>, _t: &T): <a href="object.md#0x1_object_TypedOwnerAbility">object::TypedOwnerAbility</a>&lt;T&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_to_typed_owner_ability">to_typed_owner_ability</a>&lt;T: key&gt;(ability: <a href="object.md#0x1_object_OwnerAbility">OwnerAbility</a>, _t: &T): <a href="object.md#0x1_object_TypedOwnerAbility">TypedOwnerAbility</a>&lt;T&gt; {
    <b>let</b> <a href="object.md#0x1_object_OwnerAbility">OwnerAbility</a> { self } = ability;
    <a href="object.md#0x1_object_TypedOwnerAbility">TypedOwnerAbility</a> { self }
}
</code></pre>



</details>

<a name="0x1_object_to_owner_ability"></a>

## Function `to_owner_ability`



<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_to_owner_ability">to_owner_ability</a>&lt;T: key&gt;(ability: <a href="object.md#0x1_object_TypedOwnerAbility">object::TypedOwnerAbility</a>&lt;T&gt;): <a href="object.md#0x1_object_OwnerAbility">object::OwnerAbility</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="object.md#0x1_object_to_owner_ability">to_owner_ability</a>&lt;T: key&gt;(ability: <a href="object.md#0x1_object_TypedOwnerAbility">TypedOwnerAbility</a>&lt;T&gt;): <a href="object.md#0x1_object_OwnerAbility">OwnerAbility</a> {
    <b>let</b> <a href="object.md#0x1_object_TypedOwnerAbility">TypedOwnerAbility</a> { self } = ability;
    <a href="object.md#0x1_object_OwnerAbility">OwnerAbility</a> { self }
}
</code></pre>



</details>


[move-book]: https://move-language.github.io/move/introduction.html
