---
layout: postjournal
title: Writing a Hashtable for Terra
excerpt: How to create a hashtable using Terra and Lua 
tags: terra R performance extension hashtable
---

{% jrnl  width=col-lg-6 col-md-6 col-xs-10  col-sm-10 col-centered %}

* mytoc
{:toc}

Though Lua uses hashtables/dictionaries almost exclusively for all it's data
structures, Terra does not. Terra is much lower level than Lua and as yet does
not have a standard library. There are two ways one can create a hashtable that
can be used in Terra functions

- using C code such as [uthash](http://troydhanson.github.io/uthash/userguide.html)
- using a Lua hashtable and wrapping it in Terra+Lua.

I'll demonstrate the latter and then explain why we need the former.

## The Lua Code

If we want a hashtable, we need (much like in C/C++/Java) need to specify the
type of the keys and values. So our call to create a Terra hashtable with
integer keys and `ComplexName` values starts
outside a terra function like:

	hashIntToComplex = makeHash(int, &ComplexName,function(a) return(tonumber(a)) end)

where `ComplexName` is defined as

	struct ComplexName
	{
	   name: &int8;
	   x : double;
	   y : double;
	}

and `ComplexName` is a struct describing the values, `int` are the keys and
the last lua function is the hashing function. What would the `makeHash`
function be?

In essence the function `makeHash` returns a structure called `Hash` which methods
`add`, `get`, `exists`, `delete` and `makeIter`. These methods have as their
upvalue a lua dictionary. To access the dictionary and retrieve keys/values,
they call wrapped lua functions. Note the lua functions need to be wrapped
(indicating the appropriate return type) since when Lua functions are called
from Terra functions, Terra has no idea of what the return type will be. This is
the first part of `makeHash`

	function makeHash(kType,vType,hashfunction)
	  local b = {}
	  local function add(self,key,value)
	     b[hashfunction(key)] = {key,value}
	  end
	  local function exists(self,key)
	     if b[hashfunction(key)]~= nil then
	  	 return true
	     else
	  	 return false
	     end
	  end
	  local function get(self,key)
	     return terralib.cast(vType,b[hashfunction(key)][2])
	  end
	  local function delete(self,key)
	     b[hashfunction(key)] = nil
	  end
	  local struct Hash   {   }
	  Hash.methods.add =  terralib.cast( {&Hash,kType,vType} -> {}, add)
	  Hash.methods.get = terralib.cast( {&Hash,kType} -> {vType}, get)
	  Hash.methods.exists  = terralib.cast( {&Hash,kType} -> {bool}, exists)
	  Hash.methods.del = terralib.cast( {&Hash,kType} -> {}, delete)

The Lua functions `add`, `exists`, `get` and `delete` do the obvious thing. Note
we store keys as numbers, the numbers are obtained by hashing the key using the
supplied `hashfunction` (in the
[github repo](https://github.com/saptarshiguha/terrific) I have supplied a hash
function for strings based on D.J.Bernstein's code). The value stored is the
original key and value (so that when we iterate we can return the original key
and not the stored key).

Notice how `get` casts the return value to the specified type. This is a case
where Terra types are just plain lua values. Crucial for meta programming.
The methods to the `Hash` structure are terra methods wrapping the lua functions
and indicating the appropriate types of the parameters and return values.

The code to iterate follows.

	local struct Iterator
	   {
	      key:kType;
	      value:vType;
	   }
	   local ck,cuk,vk
	   local function setcknil() ck = nil end
	   local function move() ck = next(b,ck)   end
	   local hasNext = terralib.cast({}->bool,function() return ck~=nil end)
	   local tk = terralib.cast({}->kType,function()
				       local cuk
				       cuk, vk = unpack(b[ck])
	   			       return cuk
	   				      end)
	   local tv = terralib.cast({}->vType,function() return  vk end)
	
	   terra Iterator:next()
	      move()
	      if hasNext() then do
		    self.key,self.value = tk(),tv()
		    return true
				end
	      else
		 return false
	      end
	   end
	   terra Hash:makeIter()
	      var f:Iterator
	      setcknil()
	      return f
	   end
	      
	   return Hash
	end

The variables `ck`, `cuk` and `vk` are upvalues for `Iterator:next()`, thus
state is kept across calls. Once again the casting is done appropriately.

## Example
And example of it's use is then
	
	C = terralib.includec("stdio.h")
	C1 = terralib.includec("stdlib.h")
	ffi = require("ffi")

	function cncat(a,b)
	   return terralib.cast(rawstring,"foo" .. tonumber(b))
	end
	tcncat = terralib.cast({&int8, int}->{&int8},cncat)

	hashIntToComplex = makeHash(int, &ComplexName,function(a) return(tonumber(a)) end)
	
	terra testme()
	   var b : hashIntToComplex
	   for i=1,10 do
	      var c : &ComplexName = [&ComplexName](C1.malloc(sizeof(ComplexName)))
	      c.name ,c.x,c.y=tcncat("foo",i),1.0,2.0
	      b:add(i,c)
	   end
	   -- Get Something
	   var d  = b:get(1)
	   C.printf("Name = %s, x=%f, y=%f\n", d.name, d.x,d.y)
	   -- Iterate Over
	   var p =b:makeIter()
	   while p:next() do
	      var v,k = p.value,p.key
	      C.printf("key = %d Name=%s\n",k,v.name)
	   end
	end
	testme()

Note the manual memory management! `c` is created via `malloc`. However we can
assign finalizers to run when this has no references pointing at it, using
`ffi.gc` e.g. `ffi.gc(c, C1.free)`. Haven't tried this though. Using this will
then automatically free `c` when it is not being used anymore.

The full code and my work for using Terra in R can be viewed at
[https://github.com/saptarshiguha/terrific](https://github.com/saptarshiguha/terrific).

## Cons
Well, we hit a 1GB limit here. As per this
[thread](http://lua-users.org/lists/lua-l/2010-11/msg00251.html), because of
implementation constraints in LuaJit (which is used by Terra) we cannot use more
than 1GB via Lua data structures (note the `b` hashtable in the definition of
`makeHash`). This is rather limiting and the solution to this is write a similar
wrapper around `uthash`, a C macro based hashtable.

And that is future work.

{% endjrnl %}
