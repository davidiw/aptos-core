/// This defines a proposed Aptos object model with the intent to provide the following properties:
/// * Decouple owner from data
///   * Objects are stored as resources within an account
///   * Ownership is defined in the object itself, no moving around stores
/// * Heterogeneous types stored in a single container
///   * Decoupled data from identifier allows for referencing ambiguous types
///   * Ambiguous types can be homogeneous thus bypassing restrictions on heterogeneous collections
/// * Make data immobile, while leaving ownership flexible
///   * Resources cannot be easily moved without explicit permission by the module that defines them
///   * The various refs enable extensible definition on ownership
/// * Data is globally accessible
///   * Data resides in resources which cannot be moved and therefore are always accessible
///   * In contrast, storable struct can be placed into an inaccessible space
/// * Objects can be the source of events
///   * When data is mutated in a struct, ideally that struct would emit an event.
///   * The object model allows for events to be directly coupled with data.
/// * Objects definition / structure can prevented after creation
///   * At creation, the creator has the ability to configure the account as desired
///   * Afterward, the creator can delegate signer ability to continue to change definition
///     but it can also be discarded or access prevented to ensure that an object maintains
///     consistent shape.
/// * Secure and guaranteed to not collide with existing accounts.
///   * Each address is generated in a collision-resistant fashion guaranteeing legitimate
///     accounts cannot be created within the same address.
///   * Two objects cannot be co-located due to an address being able to only store a single Object
///
/// TODO:
/// * There is no means to borrow an object or a reference to an object. We are exploring how to
///   make it so that a reference to a global object can be returned from a function.
module aptos_framework::object {
    use std::bcs;
    use std::error;
    use std::hash;
    use std::signer;
    use std::vector;

    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::from_bcs;
    use aptos_framework::guid;

    /// An object already exists at this address
    const EOBJECT_EXISTS: u64 = 0;
    /// An object of that type already exists at this address
    const EOBJECT_TYPE_EXISTS: u64 = 1;
    /// An object does not exist at this address
    const EOBJECT_DOES_NOT_EXIST: u64 = 2;
    /// The object does not have ungated transfers enabled
    const ENO_UNGATED_TRANSFERS: u64 = 3;
    /// The caller does not have ownership permissions
    const ENOT_OBJECT_OWNER: u64 = 4;
    /// The object does not allow for deletion
    const ECANNOT_DELETE: u64 = 5;

    /// Scheme identifier used to generate an object's address. This serves as domain separation to
    /// prevent existing authentication key and resource account derivation to produce an object
    /// address.
    const OBJECT_ADDRESS_SCHEME: u8 = 0xFE;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Object has key {
        guid_creation_num: u64,
        owner: address,
        allow_ungated_transfer: bool,
        transfer_events: event::EventHandle<TransferEvent>,
    }

    #[resource_group(scope = global)]
    struct ObjectGroup { }

    /// Type safe way of designate an object as at this address
    struct ObjectId has copy, drop, store {
        inner: address,
    }

    /// This is a one time ability given to the creator to configure the object as necessary
    struct CreatorRef has drop {
        self: ObjectId,
        can_delete: bool,
    }

    /// The owner of this ability can delete an object
    struct DeleteRef has drop, store {
        self: ObjectId,
    }

    /// Access to this ref allows for creation of the signer to add new resources
    struct ExtendRef has drop, store {
        self: ObjectId,
    }

    /// Access to this ref allows for owner to transfer the resources between two addresses
    struct TransferRef has drop, store {
        self: ObjectId,
    }

    /// Access to this ref allows for owner to transfer the resources between two addresses
    struct LinearTransferRef has drop {
        self: ObjectId,
    }

    struct TransferEvent has drop, store {
        object_id: ObjectId,
        from: address,
        to: address,
    }

    /// Produces an ObjectId from the given address.
    public fun create_object_id(object_id: address): ObjectId {
        ObjectId { inner: object_id }
    }

    /// Derives an object id from source material: sha3_256([creator address | seed | 0xFE]).
    /// The ObjectId needs to be distinct from create_resource_address
    public fun derive_object_id(source: &address, seed: vector<u8>): ObjectId {
        let bytes = bcs::to_bytes(source);
        vector::append(&mut bytes, seed);
        vector::push_back(&mut bytes, OBJECT_ADDRESS_SCHEME);
        ObjectId { inner: from_bcs::to_address(hash::sha3_256(bytes)) }
    }


    /// Returns the address of an ObjectId
    public fun object_id_address(object_id: &ObjectId): address {
        object_id.inner
    }

    /// Create a new named object and return the CreatorRef. Named objects can be queried globally
    /// by knowing the user generated seed used to create them. Named objects cannot be deleted.
    public fun create_named_object(creator: &signer, seed: vector<u8>): CreatorRef {
        let creator_address = signer::address_of(creator);
        let id = derive_object_id(&creator_address, seed);
        create_object_internal(creator_address, id, false)
    }

    public fun create_object_from_account(creator: &signer): CreatorRef {
        let guid = account::create_guid(creator);
        create_object_from_guid(signer::address_of(creator), guid)
    }

    public fun create_object_from_object(creator: &signer): CreatorRef acquires Object {
        let guid = create_guid(creator);
        create_object_from_guid(signer::address_of(creator), guid)
    }

    fun create_object_from_guid(creator_address: address, guid: guid::GUID): CreatorRef {
        let bytes = bcs::to_bytes(&guid);
        vector::push_back(&mut bytes, OBJECT_ADDRESS_SCHEME);
        let object_id = ObjectId { inner: from_bcs::to_address(hash::sha3_256(bytes)) };
        create_object_internal(creator_address, object_id, true)
    }

    fun create_object_internal(
        creator_address: address,
        id: ObjectId,
        can_delete: bool,
    ): CreatorRef {
        assert!(!exists<Object>(id.inner), error::already_exists(EOBJECT_EXISTS));

        let object_signer = create_signer(id.inner);
        let guid_creation_num = 0;
        let transfer_events_guid = guid::create(id.inner, &mut guid_creation_num);

        move_to(
            &object_signer,
            Object {
                guid_creation_num,
                owner: creator_address,
                allow_ungated_transfer: true,
                transfer_events: event::new_event_handle(transfer_events_guid),
            },
        );
        CreatorRef { self: id, can_delete }
    }

    // Creation helpers

    public fun disallow_ungated_transfer(ref: &CreatorRef) acquires Object {
        let object = borrow_global_mut<Object>(ref.self.inner);
        object.allow_ungated_transfer = false;
    }

    public fun generate_delete_ref(ref: &CreatorRef): DeleteRef {
        assert!(ref.can_delete, error::permission_denied(ECANNOT_DELETE));
        DeleteRef { self: ref.self }
    }

    /// Create a signer for the CreatorRef
    public fun generate_signer(ref: &CreatorRef): signer {
        create_signer(ref.self.inner)
    }

    public fun object_id_from_creator_ref(ref: &CreatorRef): ObjectId {
        ref.self
    }

    // Signer please...

    /// Create a guid for the object, typically used for events
    public fun create_guid(object: &signer): guid::GUID acquires Object {
        let addr = signer::address_of(object);
        let object_data = borrow_global_mut<Object>(addr);
        guid::create(addr, &mut object_data.guid_creation_num)
    }

    /// Generate a new event handle
    public fun new_event_handle<T: drop + store>(
        object: &signer,
    ): event::EventHandle<T> acquires Object {
        event::new_event_handle(create_guid(object))
    }

    // Deletion helpers

    public fun delete_ref_id(ref: &DeleteRef): ObjectId {
        ref.self
    }

    public fun delete(ref: DeleteRef) acquires Object {
        let object = move_from<Object>(ref.self.inner);
        let Object {
            guid_creation_num: _,
            owner: _,
            allow_ungated_transfer: _,
            transfer_events,
        } = object;
        event::destroy_handle(transfer_events);
    }

    // Extension helpers

    public fun generate_extend_ref(ref: &CreatorRef): ExtendRef {
        ExtendRef { self: ref.self }
    }

    /// Create a signer for the ExtendRef
    public fun generate_signer_for_extending(ref: &ExtendRef): signer {
        create_signer(ref.self.inner)
    }

    // Transfer functionality

    public fun generate_transfer_ref(ref: &CreatorRef): TransferRef {
        TransferRef { self: ref.self }
    }

    public fun generate_linear_transfer_ref(ref: TransferRef): LinearTransferRef {
        LinearTransferRef { self: ref.self }
    }

    public fun transfer_with_ref(ref: LinearTransferRef, to: address) acquires Object {
        let object = borrow_global_mut<Object>(ref.self.inner);
        event::emit_event(
            &mut object.transfer_events,
            TransferEvent {
                object_id: ref.self,
                from: object.owner,
                to,
            },
        );
        object.owner = to;
    }

    public entry fun entry_transfer(
        owner: &signer,
        object_id: address,
        to: address,
    ) acquires Object {
        transfer(owner, ObjectId { inner: object_id }, to)
    }

    public fun transfer(
        owner: &signer,
        object_id: ObjectId,
        to: address,
    ) acquires Object {
        let owner_address = signer::address_of(owner);
        if (owner_address == to) {
            return
        };

        verify_ungated_and_descendant(owner_address, object_id.inner);

        let object = borrow_global_mut<Object>(object_id.inner);
        event::emit_event(
            &mut object.transfer_events,
            TransferEvent {
                object_id: object_id,
                from: object.owner,
                to,
            },
        );
        object.owner = to;
    }

    public fun transfer_to_object(
        owner: &signer,
        object_id: ObjectId,
        to: ObjectId,
    ) acquires Object {
        transfer(owner, object_id, to.inner)
    }

    /// This checks that the destination address is eventually owned by the owner and that each
    /// object between the two allows for ungated transfers.
    fun verify_ungated_and_descendant(owner: address, destination: address) acquires Object {
        let current_address = destination;
        assert!(
            exists<Object>(current_address),
            error::not_found(EOBJECT_DOES_NOT_EXIST),
        );

        while (owner != current_address) {
            // At this point, the first object exists and so the more likely case is that the
            // object's owner is not an object. So we return a more sensible error.
            assert!(
                exists<Object>(current_address),
                error::permission_denied(ENOT_OBJECT_OWNER),
            );
            let object = borrow_global<Object>(current_address);
            assert!(
                object.allow_ungated_transfer,
                error::permission_denied(ENO_UNGATED_TRANSFERS),
            );

            current_address = object.owner;
        };
    }

    /// Accessors

    public fun owner(object_id: ObjectId): address acquires Object {
        assert!(
            exists<Object>(object_id.inner),
            error::not_found(EOBJECT_DOES_NOT_EXIST),
        );
        borrow_global<Object>(object_id.inner).owner
    }

    public fun is_owner(object_id: ObjectId, owner: ObjectId): bool acquires Object {
        owner(object_id) == owner.inner
    }

    native fun create_signer(addr: address): signer;

    #[test_only]
    use std::option::{Self, Option};

    #[test_only]
    const EHERO_DOES_NOT_EXIST: u64 = 0x100;
    #[test_only]
    const EWEAPON_DOES_NOT_EXIST: u64 = 0x101;

    #[test_only]
    struct HeroEquipEvent has drop, store {
        weapon_id: Option<ObjectId>,
    }

    #[test_only]
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Hero has key {
        equip_events: event::EventHandle<HeroEquipEvent>,
        weapon: Option<ObjectId>,
    }

    #[test_only]
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Weapon has key { }

    #[test_only]
    public fun create_hero(creator: &signer): ObjectId acquires Object {
        let hero_creator_ref = create_named_object(creator, b"hero");
        let hero_signer = generate_signer(&hero_creator_ref);
        let guid_for_equip_events = create_guid(&hero_signer);
        move_to(
            &hero_signer,
            Hero {
                weapon: option::none(),
                equip_events: event::new_event_handle(guid_for_equip_events),
            },
        );

        object_id_from_creator_ref(&hero_creator_ref)
    }

    #[test_only]
    public fun create_weapon(creator: &signer): ObjectId {
        let weapon_creator_ref = create_named_object(creator, b"weapon");
        let weapon_signer = generate_signer(&weapon_creator_ref);
        move_to(&weapon_signer, Weapon { });
        object_id_from_creator_ref(&weapon_creator_ref)
    }

    #[test_only]
    public fun hero_equip(
        owner: &signer,
        hero: ObjectId,
        weapon: ObjectId,
    ) acquires Hero, Object {
        transfer_to_object(owner, weapon, hero);
        let hero_obj = borrow_global_mut<Hero>(object_id_address(&hero));
        option::fill(&mut hero_obj.weapon, weapon);
        event::emit_event(
            &mut hero_obj.equip_events,
            HeroEquipEvent { weapon_id: option::some(weapon) },
        );
    }

    #[test_only]
    public fun hero_unequip(
        owner: &signer,
        hero: ObjectId,
        weapon: ObjectId,
    ) acquires Hero, Object {
        transfer(owner, weapon, signer::address_of(owner));
        let hero = borrow_global_mut<Hero>(object_id_address(&hero));
        option::extract(&mut hero.weapon);
        event::emit_event(
            &mut hero.equip_events,
            HeroEquipEvent { weapon_id: option::none() },
        );
    }


    #[test(creator = @0x123)]
    fun test_object(creator: &signer) acquires Hero, Object {
        let hero = create_hero(creator);
        let weapon = create_weapon(creator);

        hero_equip(creator, hero, weapon);
        hero_unequip(creator, hero, weapon);
    }
}
