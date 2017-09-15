---
layout: postjournal
title: Can I use the RTerra package in Hadoop even when LLVM doesn't exist on the cluster nodes?
excerpt: I would like to run rterra extensions in my Hadoop code
tags: terra R performance extension lua luajit hadoop rterra
---

{% jrnl width=code %}


* mytoc
{:toc}

## Introduction
 [rterra](http://people.mozilla.org/~sguha/blog/2013/08/01/rterra_first_post.html)
 is an R package that can be used to write extension in Terra. To briefly recap,
 Terra is a language that is a super set of LuaJit and features extensions which
 are compiled to machine code via LLVM. Best read
 [the website for TerraLang](http://terralang.org/) for a better idea.

Most importantly, the RTerra package

- depends on the presence of LLVM/Clang to compile, but thereafter _does not_
  need LLVM/Clang
- downloads LuaJit, builds both LuaJit and Terra and creates a self contained
package

Both these points imply that it can be easily used in Hadoop - an environment
where it is difficult to assume presence of software on the compute nodes. 

## An Example

### Supporting Files
Let us assume that we have a `LUA_LIBS` folder in which my Lua packages are
contained. For example mine looks like

    ls -l  /home/sguha/software/LUA_LIBS/
    total 44
    -rwxr-x--- 1 sguha sguha 35801 Feb 24 04:29 cjson.so
    drwxr-xr-x 2 sguha sguha  4096 Feb 24 18:45 time
    drwxr-xr-x 2 sguha sguha  4096 Feb 24 04:32 xsys

We'll need to zip that up too. Like this

    tar cvfz ~/lualibs.tar.gz -C /home/sguha/software/  LUA_LIBS

The `lualibs.tar.gz` needs to be rebuilt if new Lua/Terra libraries are
installed

### The Terra Code
Let's first write a small bit of Terra that gets the local time in string form


     time = terralib.includec("time.h")
     terra getCurrentTimeAsString()
        var t: time.time_t = time.time(nil)
        var tm = time.localtime(&t);
        var str_time:int8[100]
        time.strftime(str_time,100, "%H:%M:%S", tm)
        var x = Rbase.Rf_allocVector(R.types.STRSXP,1)
        Rbase.SET_STRING_ELT(x,0, Rbase.Rf_mkChar(str_time));
        return x
    end
	
Save this in a file called `~/myfirst.t`.

### Calling in RHIPE
I will assume the environment is similar to that at Mozilla: R does not exist on the
compute nodes, neither does your Lua libraries (note,we do not have shared
filesystem backing the home folder). So we need to pass the header files and
Lua libraries to the nodes.

Initialize RHIPE

    library(Rhipe)
    rhinit()

Copy the zip files to the HDFS

    rhput("~/lualibrary.tar.gz",'/user/sguha/share/')

Copy my Terra code

    rhput("~/myfirst.t","/user/sguha/tmp/")

And now the RHIPE code, see below for comments

    j <- rhwatch(map=function(a,b){
     		   rhcollect("f",terra("getCurrentTimeAsString"))
     			      }
     		, reduce=0
     		, input=c(10,10)
     		, zips="/user/sguha/share/lualibrary.tar.gz"
     		, share = "/user/sguha/tmp/myfirst.t" ##file is on HDFS
     		, setup=expression(map={
     				      library(rterra)
     				      tinit(rcppflags = c("./R302/R/include/", "./R302/R/include/R_ext"))
     				      terraAddRequirePaths(paste(sprintf("%s/lualibrary/LUA_LIBS",getwd()),c("?.lua","?/init.lua"),sep="/",collapse=";"))
     				      terraAddGeneralPaths(paste(sprintf("%s/lualibrary/LUA_LIBS",getwd()),"?.so",sep="/",collapse=";"),"package.cpath")
     				      terraAddRequirePaths(sprintf("%s/?.lua",getwd()))
     				      terraFile('./myfirst.t')
     				       })
     	    )

The codes runs 10 tasks on 10 nodes, each node will return the current time as a
string `getCurrentTimeAsString`. The code for that is in the Terra file
`myfirst.t`. Let's inspect the `setup` expression

We need the following code since rterra requires the R header files. Note, if
your distribution has nodes that look like the master e.g. RHIPE on EC2, then R
exists on all the nodes at the same place. So this is not needed.  Your setup
would then look like

    library(rterra)
    tinit()

Here we invoke `terraAddRequirePaths` to tell Terra to search for modules inside
the unzipped `lualib.tar.gz` file. Once these functions have been called, we can
do things like `json = require 'cjson'`.

    library(rterra)
    tinit(rcppflags = c("./R302/R/include/", "./R302/R/include/R_ext"))
    terraAddRequirePaths(paste(sprintf("%s/lualibrary/LUA_LIBS",getwd()),c("?.lua","?/init.lua"),sep="/",collapse=";"))
    terraAddGeneralPaths(paste(sprintf("%s/lualibrary/LUA_LIBS",getwd()),"?.so",sep="/",collapse=";"),"package.cpath")
    terraAddRequirePaths(sprintf("%s/?.lua",getwd()))


Once all this is done, the `map` code just calls `getCurrentTimeAsString`

    function(a,b){
     rhcollect("f",terra("getCurrentTimeAsString"))
    }

The output is

    > data.frame( k=unlist(lapply(j,"[[",1)),d= unlist(lapply(j,"[[",2) ))
       k        d
    1  f 21:53:16
    2  f 21:53:15
    3  f 21:53:10
    4  f 21:53:05
    5  f 21:53:22
    6  f 21:53:24
    7  f 21:53:20
    8  f 21:53:20
    9  f 21:53:04
    10 f 21:53:22


{% endjrnl %}

