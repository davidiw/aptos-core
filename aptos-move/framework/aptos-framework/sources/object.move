/// This defines a proposed Aptos object model with the intent to provide the following properties:
/// * Decouple data from ownership
///   * Objects are stored as resources within an account
///   * OwnerAbility defines ownership of an object
/// * Heterogeneous types stored in a single container
///   * Decoupled data from ownership allows or ownership to be to an ambiguous type
///   * Ambiguous types can be homogeneous thus bypassing restrictions on heterogeneous collections
/// * Make data immobile, while making ownership of data flexible
///   * Resources cannot be easily moved without explicit permission by the module that defines them
///   * OwnerAbility has no restrictions where it flows
///   * This allows for a creator to always managed all objects created by them
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
/// * An object should be highly configurable, the creator the following access privileges:
///   * Ownership
///   * Signer
///   * Deletion
///   * Mutation
///   * Reading
/// * Secure and guaranteed to not collide with existing accounts.
///   * Each address is generated in a collision-resistant fashion guaranteeing legitimate
///     accounts cannot be created within the same address.
///   * Two objects cannot be co-located due to an address being able to only store a single Object
///
/// TODO:
/// * Currently an object will be spread across distinct storage slots, this is not efficient.
///   We are currently exploring a concept of storage groups that will allow structs marked with
///   `[storage_group(GROUP)]` to be co-located in a storage slot.
/// * There is no means to borrow an object or a reference to an object. We are exploring how to
///   make it so that a reference to a global object can be returned from a function.
/// * There's no guarantee of correctness or consistency in object implementation. For example,
///   the API for generating a TypedOwnerAbility can differ from object to object. An object
///   could potentially be left in a partially deleted state. We are exploring interfaces that
///   would allow for calling functions on module, type pairs that implement certain functions.
/// * The ownership model allows for richer defintion of access control, such as specifying when
///   an object can be mutated, read, and moved. This can be extended to entry functions to
///   seamlessly allow a user to know prior to sending a transaction the potential implications
///   for their owned objects.
/// * The current demo is rather limited and needs to be extended to demonstrate more end-to-end.
module aptos_framework::object {
    use std::bcs;
    use std::error;
    use std::hash;
    use std::signer;
    use std::vector;

    use aptos_std::table;

    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::from_bcs;
    use aptos_framework::guid;

    /// An object already exists at this address
    const EOBJECT_EXISTS: u64 = 0;
    /// An object of that type already exists at this address
    const EOBJECT_TYPE_EXISTS: u64 = 1;

    /// Scheme identifier used to generate an object's address. This serves as domain separation to
    /// prevent existing authentication key and resource account derivation to produce an object
    /// address.
    const OBJECT_ADDRESS_SCHEME: u8 = 0xFE;

    struct Object has key {
        guid_creation_num: u64,
    }

    /// This is a one time ability given to the creator to configure the object as necessary
    struct CreatorAbility has drop {
        self: address,
    }

    /// The owner of this ability can delete an object
    struct DeleteAbility has copy, drop, store {
        self: address,
    }

    /// The owner of this ability can generate the object's signer
    struct SignerAbility has copy, drop, store {
        self: address,
    }

    /// This implies that this individual owns this object
    struct OwnerAbility has drop, store {
        self: address,
    }

    /// This implies that the individual owns this object and it contains a specific type / resource
    struct TypedOwnerAbility<phantom T: key> has drop, store {
        self: address,
    }

    // This is heterogeneous store of owned objects
    struct ObjectStore has key {
        inner: table::Table<address, OwnerAbility>,
        deposits: event::EventHandle<DepositEvent>,
        withdraws: event::EventHandle<WithdrawEvent>,
    }

    struct DepositEvent has drop, store {
        object_id: address,
    }

    struct WithdrawEvent has drop, store {
        object_id: address,
    }

    public fun init_store(account: &signer) {
        move_to(
            account,
            ObjectStore {
                inner: table::new(),
                deposits: account::new_event_handle(account),
                withdraws: account::new_event_handle(account),
            },
        )
    }

    public fun withdraw(account: &signer, addr: address): OwnerAbility acquires ObjectStore {
        let object_store = borrow_global_mut<ObjectStore>(signer::address_of(account));
        event::emit_event(&mut object_store.withdraws, WithdrawEvent { object_id: addr });
        table::remove(&mut object_store.inner, addr)
    }

    public fun deposit(account: &signer, object: OwnerAbility) acquires ObjectStore {
        let object_store = borrow_global_mut<ObjectStore>(signer::address_of(account));
        let object_addr = owner_ability_address(&object);
        event::emit_event(&mut object_store.deposits, DepositEvent { object_id: object_addr });
        table::add(&mut object_store.inner, object_addr, object);
    }

    public fun deposit_typed<T: key>(
        account: &signer,
        object: TypedOwnerAbility<T>,
    ) acquires ObjectStore {
        deposit(account, to_owner_ability(object))
    }

    public fun contains(account: &signer, addr: address): bool acquires ObjectStore {
        let object_store = borrow_global<ObjectStore>(signer::address_of(account));
        table::contains(&object_store.inner, addr)
    }

    /// Object addresses are equal to the sha3_256([creator addres | seed | 0xFE]).
    public fun create_object_id(source: &address, seed: vector<u8>): address {
        let bytes = bcs::to_bytes(source);
        vector::append(&mut bytes, seed);
        vector::push_back(&mut bytes, OBJECT_ADDRESS_SCHEME);
        from_bcs::to_address(hash::sha3_256(bytes))
    }

    public fun create_object(creator: &signer, seed: vector<u8>): CreatorAbility {
        // create object address needs to be distinct from create_resource_address
        let address = create_object_id(&signer::address_of(creator), seed);
        assert!(!exists<Object>(address), error::already_exists(EOBJECT_EXISTS));
        let object_signer = create_signer_internal(address);

        move_to(
            &object_signer,
            Object {
                guid_creation_num: 0,
            },
        );
        CreatorAbility { self: address }
    }

    public fun create_guid(object: &signer): guid::GUID acquires Object {
        let addr = signer::address_of(object);
        let object_data = borrow_global_mut<Object>(addr);
        guid::create(addr, &mut object_data.guid_creation_num)
    }

    public fun generate_delete_ability(ability: &CreatorAbility): DeleteAbility {
        DeleteAbility { self: ability.self }
    }

    public fun delete(ability: DeleteAbility) acquires Object {
        let object = move_from<Object>(ability.self);
        let Object {
            guid_creation_num: _,
        } = object;
    }

    public fun new_event_handle<T: drop + store>(
        object: &signer,
    ): event::EventHandle<T> acquires Object {
        event::new_event_handle(create_guid(object))
    }

    native fun create_signer_internal(addr: address): signer;

    public fun generate_signer_ability(ability: &CreatorAbility): SignerAbility {
        SignerAbility { self: ability.self }
    }

    public fun create_signer(ability: &SignerAbility): signer {
        create_signer_internal(ability.self)
    }

    public fun generate_owner_ability(ability: &CreatorAbility): OwnerAbility {
        OwnerAbility { self: ability.self }
    }

    public fun owner_ability_address(ability: &OwnerAbility): address {
        ability.self
    }

    public fun typed_owner_ability_address<T: key>(ability: &TypedOwnerAbility<T>): address {
        ability.self
    }

    public fun to_typed_owner_ability<T: key>(ability: OwnerAbility, _t: &T): TypedOwnerAbility<T> {
        let OwnerAbility { self } = ability;
        TypedOwnerAbility { self }
    }

    public fun to_owner_ability<T: key>(ability: TypedOwnerAbility<T>): OwnerAbility {
        let TypedOwnerAbility { self } = ability;
        OwnerAbility { self }
    }

    #[test_only]
    use std::option;

    #[test_only]
    const EHERO_DOES_NOT_EXIST: u64 = 0x100;
    #[test_only]
    const EWEAPON_DOES_NOT_EXIST: u64 = 0x101;

    #[test_only]
    struct HeroEquipEvent has drop, store {
        weapon_id: option::Option<address>,
    }

    #[test_only]
    struct Hero has key {
        equip_events: event::EventHandle<HeroEquipEvent>,
        weapon: option::Option<TypedOwnerAbility<Weapon>>,
    }

    #[test_only]
    public fun hero_equip(
        hero: &TypedOwnerAbility<Hero>,
        weapon: TypedOwnerAbility<Weapon>,
    ) acquires Hero {
        let hero = borrow_global_mut<Hero>(typed_owner_ability_address(hero));
        let weapon_id = typed_owner_ability_address(&weapon);
        option::fill(&mut hero.weapon, weapon);
        event::emit_event(
            &mut hero.equip_events,
            HeroEquipEvent { weapon_id: option::some(weapon_id) },
        );
    }

    #[test_only]
    public fun create_hero(creator: &signer): TypedOwnerAbility<Hero> acquires Hero, Object {
        let hero_creator_ability = create_object(creator, b"hero");
        let hero_signer_ability = generate_signer_ability(&hero_creator_ability);
        let hero_signer = create_signer(&hero_signer_ability);
        let guid_for_equip_events = create_guid(&hero_signer);
        move_to(
            &hero_signer,
            Hero {
                weapon: option::none(),
                equip_events: event::new_event_handle(guid_for_equip_events),
            },
        );
        let hero_owner_ability = generate_owner_ability(&hero_creator_ability);
        to_hero_owner_ability(hero_owner_ability)
    }

    #[test_only]
    public fun to_hero_owner_ability(
        ability: OwnerAbility,
    ): TypedOwnerAbility<Hero> acquires Hero {
        assert!(exists<Hero>(owner_ability_address(&ability)), EHERO_DOES_NOT_EXIST);
        let hero = borrow_global<Hero>(owner_ability_address(&ability));
        to_typed_owner_ability(ability, hero)
    }

    #[test_only]
    struct Weapon has key { }

    #[test_only]
    public fun create_weapon(creator: &signer): TypedOwnerAbility<Weapon> acquires Weapon {
        let weapon_creator_ability = create_object(creator, b"weapon");
        let weapon_signer_ability = generate_signer_ability(&weapon_creator_ability);
        let weapon_signer = create_signer(&weapon_signer_ability);
        move_to(&weapon_signer, Weapon {});
        let weapon_owner_ability = generate_owner_ability(&weapon_creator_ability);
        to_weapon_owner_ability(weapon_owner_ability)
    }

    #[test_only]
    public fun to_weapon_owner_ability(
        ability: OwnerAbility,
    ): TypedOwnerAbility<Weapon> acquires Weapon {
        assert!(exists<Weapon>(owner_ability_address(&ability)), EWEAPON_DOES_NOT_EXIST);
        let weapon = borrow_global<Weapon>(owner_ability_address(&ability));
        to_typed_owner_ability(ability, weapon)
    }

    #[test(creator = @0x123)]
    fun test_object(creator: &signer) acquires Hero, Object, ObjectStore, Weapon {
        account::create_account_for_test(signer::address_of(creator));
        init_store(creator);

        let hero = create_hero(creator);
        let hero_id = typed_owner_ability_address(&hero);
        deposit_typed(creator, hero);

        let weapon = create_weapon(creator);
        let weapon_id = typed_owner_ability_address(&weapon);
        deposit_typed(creator, weapon);

        let hero = to_hero_owner_ability(withdraw(creator, hero_id));
        let weapon = to_weapon_owner_ability(withdraw(creator, weapon_id));
        hero_equip(&hero, weapon);
        deposit_typed(creator, hero);
    }
}
