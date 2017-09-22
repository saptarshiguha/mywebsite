---
layout: postjournal
title: Using Terra to Speed Up R
excerpt: Exploring the new TerraLang project as an extension language for R.
tags: terra R performance extension
---

{% jrnl  width=col-lg-6 col-md-6 col-xs-10  col-sm-10 col-centered %}
 
* mytoc
{:toc}
 
Recently, Stanford student Zach DeVito created a language called
[TerraLang](http://terralang.org/) based of Lua. My impression is that is a
statically typed version of Lua (though not everything has to be typed, regular
Lua functions execute just fine) with tight LLVM integration. Code written in
the TerraLang syntax (using the `terra` keyword) can be JIT compiled to machine
code (using LLVM). TerraLang is called a __multi stage__ system, superficially
to me, this means it has a similar macro system to LISP's ( i am most likley
very wrong).

My reasons for investigating TerraLang is to find an extension language for R
that has good performance characteristics. The current choice is C++ (using
[Rcpp](http://cran.r-project.org/web/packages/Rcpp/)) or Java (using
[rJava](http://cran.r-project.org/web/packages/rJava/)). Both languages are
performant and in many cases, provide orders of speed improvement over the R
language. However, I don't recommend either for the general R programmer. I have
seen too many __segfaults__, R programmers fighting with pointers, and the
verbosity of Java

Lua on the other hand is a very simple language to learn. [LuaJIT](luajit.org)
is a blazing fast implementation of Lua (though one has to program
idiomatically). And TerraLang can compile terra functions to machine code (via
LLVM). Moreover, one can write macros in TerraLang to produce code-driven-code!

I will describe some micro benchmarks and help a fellow explorer create their
own __terrRific__ code!

## Installation

You need: Ubuntu 12.10 (what i tested on), LLVM 3.2, Clang, and R (with
development libraries).  The files `a.cc`,`code2.t` and `run.R` can be
found[here]({{site.url}}/resources/terraexample).

You should install LuaJIT. To do that go
[here](http://luajit.org/download.html), download the archive, unzip and run

	make && sudo make install

You might need to use sudo to `make install`.

Now, clone the Terra repository

	git clone https://github.com/zdevito/terra
	cd terra
	make
	sudo cp build/libterra.so /usr/local/lib/

Download the `a.cc` file from [here]({{site.url}}/resources/terraexample) and run

	g++ -fPIC -c -o a.o a.cc `R CMD config --cppflags` -I/usr/local/include/luajit-2.0/ -I/home/sguha/dev/terra/src

Note the last `-I/home/sguha/dev/terra/src`, this should point to the location where you downloaded Terra and then

	g++ -shared a.o -o a.so `R CMD config --ldflags` -L/usr/local/lib -lluajit-5.1 -lterra

If all works, you should have `a.so` in the terra directory.

## Using TerraLang as an Extension Language for R

We will compare performance with bubblesort found
[here](http://www.numbertheory.nl/2013/05/14/much-more-efficient-bubble-sort-in-r-using-the-rcpp-and-inline-packages/)
. Download the above files (`code2.t` and friends, change the

	.Call("terraDoFile","/home/sguha/dev/earth/code2.t")

to point to where you downloaded `code2.t`), which contains the bubble sort code along with other demo Lua/Terra
code. Some examples:

Terra Code to load the libraries

	terralib.linklibrary("/usr/lib/R/lib/libR.so")
	Rmath = terralib.includec("Rmath.h")
	Rinternals = terralib.includec("Rinternals.h")

Code to allocate an R vector, the type of the vector is based on `what`. Here it
is 14 and taken from `Rinternals.h`. In a complete R-Terra library, this would
be from a table.

	terra x( what :int, l :int)
		var a =  Rinternals.Rf_allocVector(what, l)
	end

### Benchmarking the BubbleSort

 This can be written so that the sort is in place.  For comparison
purposes I've made a copy. Note, a lot of this is boilerplate and in a
library it would be removed.

	terra bubbleSort( a :&Rinternals.SEXPREC ): &Rinternals.SEXPREC
	   var itemCount:int = Rinternals.LENGTH(a)
	   var hasChanged : bool
	   var ac : &Rinternals.SEXPREC = Rinternals.Rf_allocVector(14,itemCount)
	   Rinternals.Rf_protect(ac)
	   -- do a memcpy
	   ffi.copy(Rinternals.REAL(ac), Rinternals.REAL(a), itemCount*8)
	   var A : &double = Rinternals.REAL(ac)
	   repeat
	      hasChanged = false
	      itemCount = itemCount - 1
	      for i = 0, itemCount do
	   	  if A[i] > A[i + 1] then
	   	    @(A+i), @(A+i + 1) = A[i + 1], A[i]
	   	    hasChanged = true
	   	 end
	      end
	   until hasChanged == false
	   Rinternals.Rf_unprotect(1)
	   return(ac)
	end


The R code to initialize this is (run R in the terra directory)

	Sys.setenv(INCLUDE_PATH= strsplit(system("R CMD config --cppflags",intern=TRUE),"-I")[[1]][[2]])
	dyn.load("a.so")
	.Call("initTerrific",NULL)
	.Call("terraDoFile","/home/sguha/dev/earth/code2.t") ## change to path of code2.t

And now run the comparison benchmark

	require(inline)  ## for cxxfunction()                                                       
	src = 'Rcpp::NumericVector vec = Rcpp::NumericVector(vec_in);                               
	       double tmp = 0;                                                                      
	       int no_swaps;                                                                        
	       while(true) {                                                                        
	           no_swaps = 0;                                                                    
	           for (int i = 0; i < vec.size()-1; ++i) {                                         
	               if(vec[i] > vec[i+1]) {                                                      
	                   no_swaps++;                                                              
	                   tmp = vec[i];                                                            
	                   vec[i] = vec[i+1];                                                       
	                   vec[i+1] = tmp;                                                          
	               };                                                                           
	           };                                                                               
	           if(no_swaps == 0) break;                                                         
	       };                                                                                   
	       return(vec);'                                                                        
	bubble_sort_cpp = cxxfunction(signature(vec_in = "numeric"), body=src, plugin="Rcpp")  	

	library(microbenchmark) 
	vector_size <- 10000
	x1 <- as.numeric(sample(1:vector_size))
	print(microbenchmark(
	        .Call("doTerraFunc1","bubbleSort",x1),
	        bubble_sort_cpp(x1),
	        sort(x1),control=list(warmup=5)))


### Results of Benchmark
(In microseconds), The first line corresponds to TerraLang, Rcpp and lastly, R builtin. Note, R
builtin does much more work(NA resolution etc).

	                                    expr     min       lq   median       uq         max neval
	 .Call("doTerraFunc1", "bubbleSort", x1)  40.019  43.1315  46.6980  50.8220     913.433   100
	                     bubble_sort_cpp(x1)  81.326  83.3380  83.7335  84.9925 1755508.443   100
	                                sort(x1) 167.754 171.3210 175.5285 182.6385    1176.576   100

For a vector of length 100,000

	                                   expr      min       lq   median       uq
	 .Call("doTerraFunc1", "bubbleSort", x1)  470.705  759.308 1084.037 2147.427
	                     bubble_sort_cpp(x1)  928.686 2026.870 2056.922 2134.380
	                                sort(x1) 1940.067 3232.532 3991.745 5185.881
	
## Summary

None of the above code uses the true power of Terra - it's macro facility,though
the (if i'm not mistaken) the Terra function is compiled to machine code via
LLVM. It looks like FFI calls to the R library and yet it is performant. I
should also just try writing the FFI version in a standard a Lua function (and
then it will be pure LuaJIT). That said, the example is silly ... and the Rcpp
examples (e.g. clamp) are not so interesting. A good test would be to rewrite an
R package using a Terra+R library.


{% endjrnl %}
