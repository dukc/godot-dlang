/**
Variant hashmap/dictionary type.

Copyright:
Copyright (c) 2007 Juan Linietsky, Ariel Manzur.
Copyright (c) 2014 Godot Engine contributors (cf. AUTHORS.md)
Copyright (c) 2017 Godot-D contributors
Copyright (c) 2022 Godot-DLang contributors

License: $(LINK2 https://opensource.org/licenses/MIT, MIT License)


*/
module godot.dictionary;

import godot.abi;
import godot;
import godot.builtins;

import std.meta;

/**
Associative container which contains values referenced by unique keys. Dictionaries are always passed by reference.
*/
struct Dictionary {
    int opApply(int delegate(const(Variant), ref Variant) dg) {

        godot_variant* k;
        gdextension_interface_variant_iter_next(&_godot_dictionary, k, null);
        while (k) {
            Variant* v = cast(Variant*) gdextension_interface_dictionary_operator_index(
                &_godot_dictionary, k);
            int res = dg(*cast(const(Variant*)) k, *v);
            if (res)
                return res;
            gdextension_interface_variant_iter_next(&_godot_dictionary, k, null);
        }
        return 0;
    }

    int opApply(int delegate(const(Variant), ref const(Variant)) dg) const {
        godot_variant* k;
        gdextension_interface_variant_iter_next(&_godot_dictionary, k, null);
        while (k) {
            Variant* v = cast(Variant*) gdextension_interface_dictionary_operator_index(
                cast(godot_dictionary*)&_godot_dictionary, k);
            int res = dg(*cast(const(Variant*)) k, *v);
            if (res)
                return res;
            gdextension_interface_variant_iter_next(&_godot_dictionary, k, null);
        }
        return 0;
    }

    //@nogc nothrow:

    package(godot) union dictionary {
        godot_dictionary _godot_dictionary;
        Dictionary_Bind _bind;
    }

    package(godot) dictionary _dictionary;
    alias _dictionary this;

    @disable this();

    package(godot) this(godot_dictionary opaque) {
        _godot_dictionary = opaque;
    }

    this(this) {
        _godot_dictionary = _bind.new1(_godot_dictionary);
    }

    Dictionary opAssign(in Dictionary other) {
        gdextension_interface_variant_destroy(&_godot_dictionary);
        gdextension_interface_variant_new_copy(&_godot_dictionary, &other._godot_dictionary);
        return this;
    }

    /++
	Create a Dictionary and add the key-value pairs $(PARAM args) to it.

	Example:
	---
	Dictionary emptyDictionary = Dictionary.make();
	Dictionary status = Dictionary.make(gs!"health", 100, gs!"shields", 75);
	---
	+/
    static Dictionary make(Args...)(Args args)
            if (Args.length % 2 == 0 && allSatisfy!(Variant.compatibleToGodot, Args)) {
        Dictionary ret = void;
        gdextension_interface_variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY, 0)(&ret._godot_dictionary, null);
        /+
		BUG: wtf? when using static foreach(i; 0..Args.length/2):
		Error: cannot use operator ~= in @nogc delegate godot.dictionary.Dictionary.make!(GodotStringLiteral!"name", String, GodotStringLiteral!"type", int).make.__lambda6
		+/
        static foreach (i, Arg; Args) {
            static if (i % 2 == 0) {
                ret[args[i]] = args[i + 1];
            }
        }
        return ret;
    }

    /// FIXME: naming convention fail again
    deprecated("Use Dictionary.make() with 0 args instead.")
    static Dictionary empty_dictionary() {
        Dictionary d = void;
        gdextension_interface_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY)(
            cast(GDExtensionTypePtr)&d._godot_dictionary, null);
        return d;
    }

    void clear() {
        //auto m =gdextension_interface_variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_DICTIONARY, "clear", 134152229);
        //m(cast(GDExtensionTypePtr)&_godot_dictionary);
        _bind.clear();
    }

    bool empty() const {
        //return cast(bool)gdextension_interface_dictionary_empty(&_godot_dictionary);
        return _bind.isEmpty();
    }

    void erase(K)(in K key) if (is(K : Variant) || Variant.compatibleToGodot!K) {
        const Variant k = key;
        //gdextension_interface_dictionary_erase(&_godot_dictionary, &k._godot_variant);
        _bind.erase(k);
    }

    bool has(K)(in K key) const if (is(K : Variant) || Variant.compatibleToGodot!K) {
        const Variant k = key;
        return cast(bool) gdextension_interface_dictionary_has(&_godot_dictionary, &k._godot_variant);
    }

    bool hasAll(in Array keys) const {
        //return cast(bool)gdextension_interface_dictionary_has_all(&_godot_dictionary, &keys._godot_array);
        return _bind.hasAll(keys);
    }

    uint hash() const {
        //return gdextension_interface_dictionary_hash(&_godot_dictionary);
        return cast(uint) _bind.hash();
    }

    Array keys() const {
        Array a = void;
        //a._godot_array = gdextension_interface_dictionary_keys(&_godot_dictionary);
        a = _bind.keys();
        return a;
    }

    Variant opIndex(K)(in K key) const 
            if (is(K : Variant) || Variant.compatibleToGodot!K) {
        const Variant k = key;
        //Variant ret = void;
        //ret._godot_variant = gdextension_interface_dictionary_get(&_godot_dictionary, &k._godot_variant);
        //return ret;
        return _bind.get(k, k);
    }

    void opIndexAssign(K, V)(in auto ref V value, in auto ref K key)
            if ((is(K : Variant) || Variant.compatibleToGodot!K) &&
                (is(V : Variant) || Variant.compatibleToGodot!V)) {
        const Variant k = key;
        const Variant v = value;
        Variant* t = cast(Variant*) gdextension_interface_dictionary_operator_index(&_godot_dictionary, &k._godot_variant);
        *t = v;
    }

    int size() const {
        //return gdextension_interface_dictionary_size(&_godot_dictionary);
        return cast(int) _bind.size;
    }

    // compatibility method kept from Godot 3, use JSON.stringify(dict) for more control
    String toJson() const {
        import godot.json;
        import godot.api;

        Variant v = void;
        gdextension_interface_get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_DICTIONARY)(
            &v, cast(GDExtensionTypePtr)&_godot_dictionary);
        return JSON.stringify(v, gs!(""), true, false);
    }

    Array values() const {
        //godot_array a = gdextension_interface_dictionary_values(&_godot_dictionary);
        //return cast(Array)a;
        return _bind.values();
    }

    ~this() {
        //gdextension_interface_variant_destroy(&_godot_dictionary);
        _bind._destructor();
    }
}
