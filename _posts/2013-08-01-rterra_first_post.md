---
layout: postjournal
title: The rterra Package
excerpt: Writing Extensions for R using rterra
tags: terra R performance extension
---
{% jrnl  width=code %}


* mytoc
{:toc}

## Introduction

This is my first release of _rterra_, an R package that uses
[TerraLang](http://terralang.org/) for writing extensions in R.

- Download:  [here]({{site.url}}/resources/rterra_1.3.tar.gz)
- Github Repository:
[https://github.com/saptarshiguha/terrific](https://github.com/saptarshiguha/terrific)

You need Clang 3.3 and above for this to compile. The package should
successfully download Terralang from github (via git, so you need git too) which
will compile itself and then rterra will be installed.

Tested on Redhat and Ubuntu 12.10.

I spoke about this at the Bay Area R Users Group. Presentation can be found [here](https://docs.google.com/presentation/d/1BBAnK2nQXG6VXIWMAXSPdiBcpzst9Y5iXULEYnZ3gcU/edit?usp=sharing
)

## Installation

### On Linux
If you have Clang in a custom location, specify the location of `llvm-config`
via the environment variable `LLVM_CONFIG`. If you have CUDA libraries present,
set the environment variable `ENABLE_CUDA` to 1 and set the location of
`CUDA_HOME`. And then


	R CMD INSTALL rterra_1.3.tar.gz


### On OS X

A bit trickier because any exectuable file that links against LuaJIT
needs special linker options.  Since R is the exectuable file in
question (and will load LuaJIT via the rterra package), R needs to be
... recompiled with special linker options

The easiest way to do this is

1. Install homebrew
2. Install the homebrew science tap

		brew tap homebrew/science

3. And then edit the `r.rb` formula located in `/usr/local/Library/Taps/homebrew/homebrew-science/r.rb` (assuming you installed homebrew in its default location)
   Modify the definition `install` to look like (add the two lines #a and #b)

		def install
            ENV.append_to_cflags "-D__ACCELERATE__" if ENV.compiler != :clang and build.without? "openblas"
         
            # If LDFLAGS contains any -L options, configure sets LD_LIBRARY_PATH to
            # search those directories. Remove -LHOMEBREW_PREFIX/lib from LDFLAGS.
            ENV.remove "LDFLAGS", "-L#{HOMEBREW_PREFIX}/lib" if OS.linux?
         
            ENV['MAIN_LDFLAGS']='-pagezero_size 10000 -image_base 100000000' #a
            ENV.append_to_cflags ENV['MAIN_LDFLAGS']                         #b
         
            args = [
              "--prefix=#{prefix}",
              "--with-libintl-prefix=#{Formula['gettext'].opt_prefix}",
            ]

4. Save and run `HOMEBREW_BUILD_FROM_SOURCE=1 brew install --verbose --force -d r` and you should be good to go.
    That said, it might be better to run `brew install --verbose  -d r`, then
    remove R (`brew remove --force r`) and then use the first version (using
    build from source). Doing this way wont compile gcc.
	
{% endjrnl %}


