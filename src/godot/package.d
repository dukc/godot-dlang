/++
This module contains the important functions and attributes for interfacing
between Godot and D libraries.

This module is VERY unfinished!
+/
module godot;

import godot.c;
import godot.core.variant;

import std.format;
import std.range;
import std.traits, std.meta, std.typecons;
import std.experimental.allocator, std.experimental.allocator.mallocator;
import core.stdc.stdlib : malloc, free;
debug import std.stdio;

/++
A UDA to mark a method that should be registered into Godot
+/
enum GodotMethod;

/++
Register a class and all its $(D @GodotMethod) member functions into Godot.
+/
void register(T)() if(is(T == class))
{
	enum immutable(char*) name = T.stringof; // TODO: add rename UDA
	enum immutable(char*) baseName = "Node"; // placeholder until Godot classes are implemented
	
	debug writefln("Registering D class %s", T.stringof);
	
	auto icf = godot_instance_create_func(&createFunc!T, null, null);
	auto idf = godot_instance_destroy_func(&destroyFunc!T, null, null);
	godot_script_register_class(name, baseName, icf, idf);
	
	foreach(mName; __traits(allMembers, T))
	{
		// member functions; TODO: how to handle overloads if there are more than 1?
		alias mfs = MemberFunctionsTuple!(T, mName);
		
		// `mf` is equivalent to writing `T.<mName>`; it's not a value or pointer
		foreach(mf; mfs) static if(hasUDA!(mf, GodotMethod))
		{
			enum immutable(char*) funcName = mName; // TODO: add rename UDA
			
			auto wrapped = &mf; // a *function* pointer (not delegate) to mf
			
			alias Ret = ReturnType!wrapped;
			alias Args = Parameters!wrapped;
			alias Wrapper = MethodWrapper!(T, Ret, Args);
			
			auto ma = godot_method_attributes(godot_method_rpc_mode.GODOT_METHOD_RPC_MODE_DISABLED);
			
			godot_instance_method md;
			md.method_data = Wrapper.make(wrapped);
			md.method = &Wrapper.callMethod;
			md.free_func = &free;
			
			debug writefln("	Registering method %s.%s",T.stringof,mName);
			godot_script_register_method(name, funcName, ma, md);
		}
	}
}

/++
Variadic template for method wrappers.

Params:
	T = the class that owns the method
	R = the return type (can be void)
	A = the argument types (can be empty)
+/
private struct MethodWrapper(T, R, A...)
{
	/++
	Type of the wrapped delegate's *function pointer*.
	This, together with the `this` pointer, forms the delegate that will be
	called from $(D callMethod).
	+/
	alias WrappedDelegateFunc = R function(A);
	
	
	WrappedDelegateFunc method = null;
	
	/++
	C function passed to Godot that calls the wrapped method
	+/
	extern(C) // for calling convention
	static godot_variant callMethod(godot_object o, void* methodData,
                              void* userData, int numArgs, godot_variant** args)
	{
		// TODO: check types for Variant compatibility, give a better error here
		// TODO: check numArgs, accounting for D arg defaults
		
		Variant v = Variant.nil;
		
		WrappedDelegateFunc func = (cast(MethodWrapper*)methodData).method;
		T obj = cast(T)userData;
		
		/++
		FIXME
		
		Base class inheritance is NOT accounted for here. Note one major
		difference between D delegates and C++ Member pointers: delegates
		resolve virtual overrides when they're created, NOT when they're
		called. Thus, depending on how Godot methods are bound, a different
		method may be necessary...
		
		See article: $(LINK https://digitalmars.com/articles/b68.html)
		+/
		R delegate(A) actualDelegate;
		actualDelegate.funcptr = func;
		actualDelegate.ptr = cast(void*)obj;
		
		A[ai] variantToArg(size_t ai)()
	    {
		    return (cast(Variant*)args[ai]).as!(A[ai]);
	    }
		template ArgCall(size_t ai)
		{
			alias ArgCall = variantToArg!ai; //A[i] function()
		}
		
		alias argIota = aliasSeqOf!(iota(A.length));
		alias argCall = staticMap!(ArgCall, argIota);
		
		static if(is(R == void))
		{
			actualDelegate(argCall);
		}
		else
		{
			v = actualDelegate(argCall);
		}
		
		return cast(godot_variant)v;
	}
	
	
	
	static void* make(WrappedDelegateFunc m)
	{
		MethodWrapper* ret = cast(MethodWrapper*)malloc(MethodWrapper.sizeof);
		ret.method = m;
		return ret;
	}
}



extern(C) private void* createFunc(T)(godot_object self, void* methodData)
{
	T t = Mallocator.instance.make!T(); // TODO: set the self pointer
	// TODO: init
	return cast(void*)t;
}

extern(C) private void destroyFunc(T)(godot_object self, void* methodData, void* userData)
{
	T t = cast(T)userData;
	Mallocator.instance.dispose(t);
}


