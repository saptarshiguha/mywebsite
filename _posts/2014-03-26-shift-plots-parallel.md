---
layout: postjournal
title: Computing the Shift Plot Data in Parallel
excerpt: Adapting Intel's TBB for Terra 
tags: terra R performance extension lua luajit deciles quantiles  rterra
---

{% jrnl width=code %}

* mytoc
{:toc}

## Introduction
A few days ago I spoke about implementing shift plots in Terra to get a healthy
speedup. Let's get more of a speedup by implementing the relevant bit in
parallel. If you go back to end of the [last post](http://people.mozilla.org/~sguha/blog/2014/03/19/shift-plots.html)

```lua
local function bsHDVariance1(rng, dest,  src,  nb,q)
   local ha=ffi.gc(smisc.doubleArray(nb),Rbase.free)
   local wprecomp = ffi.gc( preComputeBetaDiff(#src,q),Rbase.free)
   for bootindex = 1,nb do
      smisc.gsl.gsl_ran_sample (rng, dest, #src, src.ptr, #src, sizeof(double)) -- SRSWR n out on
      ha[bootindex-1] = A.hd( dest, #src, q,wprecomp)
   end
   local s =  smisc.stddev(ha,nb)
   return(s)
end
```

We might as well implement the $$nb$$  replications in parallel. In
fact we can do that to the original R code too. Let's tackle the Terra first.

To get this done, I needed to adapt Intel's Thread Building Blocks (TBB). All
the code is checked into github at
[https://github.com/saptarshiguha/rterramisc](https://github.com/saptarshiguha/rterramisc)
. The actually C++ source is tiny and the terra wrappers were pleasure to
complete. The terra
[source](https://github.com/saptarshiguha/rterramisc/blob/master/smiscrterra/inst/terra/tbbwrap.t#L45)
for the actual wrapping is instructive to read if you wish to see how Terra's macro
facility works. The general signature of `tbb.papply` (which is actually a macro
and can be called from terra code)

{% highlight lua linenos=table %}
tbb.papply( input_array :&T1, length_of_input, functor, [data: &T2], [grain: int])
{% endhighlight %}

- Here `grain` is an integer and corresponds to TBB's
[grain](http://www.threadingbuildingblocks.org/docs/help/reference/algorithms/range_concept/blocked_range_cls.htm).
- `data` is optional and should be the address of some cdata object of type `T2`
- `input_array` is typically a C array and `length_of_input` is it's length

Depending on whether `data` is passed or not, `functor` looks like

```R
terra( index : int, input: &T1[, data:&T2]) -> T3
```

The macro `papply` returns an array (which you must free)  of type `T3`
depending on whether `functor` returns anything or not.


Because of this, the above code now becomes (`npar` is really `papply` but with
`nil` as the input array)

```R
local function bsHDVariance2( src,  nb,q,grain) 
   local l,wprecomp = #src,ffi.gc( preComputeBetaDiff(l,q),Rbase.free)
   grain = grain or 50
   local terra fillin(index:int, input:&opaque)
      var dest = smisc.doubleArray([l])
      var rng2 = ....
      smisc.gsl.gsl_ran_sample (rng2, dest, [l], [src.ptr], [l], sizeof(double)) -- SRSWR n out on
      var r = A.hd(dest,l,q,wprecomp)
      Rbase.free(dest)
      return(r)
   end
   local ha = tbb.npar{length=nb, functor=fillin,grain=grain} -- the actual   parallel code
   local s =  smisc.stddev(ha,nb)
   Rbase.free(ha)
   return(s)
end
```

The call to make things parallel is `tbb.npar` (line 12). The call to `tbb.npar` is
effectively:
```python
for i in range(tb):
   ha[i] = filling(index=i)
```

Times now drop to ~ 18 seconds for 200 iterations. The sequential call takes ~50
seconds. But before proceeding to write code in other languages, can we not
improve the original R code? Yes we can! Using the suggestion of pre-computing
the Beta probability differences and using `mclapply`, the speed for R now
becomes ...  ~18 seconds too (i'm using a 16 core computer). The code for that
is at the end of this post.

## Making Everything Parallel

Notice the code for each value of $$q \in \{ 0.1,0.2,0.3,\ldots,0.9\}$$ is run
sequentially. Well, why not 'parallelize' all of it? It wont make much of a
difference because the code for a given $$q$$ has plenty to do and all
iterations have similar work times. But let's do it for the sake of
demonstrating cool Terra features. Moreover, the TBB internal scheduler will
handle allocating tasks to the finite resources. If I'm not mistaken, calling
`mclapply` within `mclapply` doesn't handle that.

To do this we'll have to change a lot of code to Terra. Keep in mind you can't
run LuaJIT code in parallel. LuaJIT is not thread safe. Here is an excerpt, the
full code can be read
[here](https://github.com/saptarshiguha/rterramisc/blob/master/smiscrterra/inst/terra/shifthd.t#L111)

```lua
local struct F2 {
   x: &double;
   y: &double;
   nx:int;
   ny:int;
   nb:int;
   grain:int
		}
function A.shifthd3 (x_,y_, nboot_,grain_)
   local x,y, nboot,grain = R.Robj(R.duplicateObject(x_)), R.Robj(R.duplicateObject(y_)), R.Robj(nboot_),R.Robj(grain_)[0]
   local crit,ret = 80.1/math.pow(math.min(#x, #y),2) + 2.73, R.Robj{type='vector', length = 9}
   local b  = terralib.new(F2, { x.ptr, y.ptr,#x,#y,nboot[0], grain})
   local terra eval_for_q(index:int, input:&double, d:&F2)
      var sex = bsHDVariance3(  d.x, d.nx, d.nb, (index+1.0)/10.0 ,d.grain)
      var sey = bsHDVariance3(  d.y, d.ny, d.nb, (index+1.0)/10.0 ,d.grain)
      var dif = A.hd(d.y, d.ny,(index+1.0)/10.0 ) - A.hd(d.x,d.nx,(index+1.0)/10.0 )
      return  { sex=sex, sey=sey, dif=dif}
   end
   local res = tbb.npar{ length=9,functor= eval_for_q, data=terralib.cast(&F2,b),grain=grain}
   for i = 1, 9 do
      local resa = res[i-1]
      ret[i-1] = R.Robj{type='numeric',
	  with = {resa.dif-crit*math.sqrt(resa.sex+resa.sey), resa.dif + crit*math.sqrt(resa.sex+resa.sey),resa.dif}}
   end
   return  ret
end
```

- Line 20 launches the parallel code to compute the differences for a value of
$$q$$
- the code is in `eval_for_q`, which in turn calls `bsHDVariance3`(see below,
  line  18) which also  launches parallel work
- `hdVarStruct` is a struct to pass data to the threads
- `__apply` allows one to call a struct object `S` as `S()`(see line 9)

```lua
terra hdVarStruct.metamethods.__apply(self: &hdVarStruct)
   var dest = smisc.doubleArray(self.l)
   var rng = smisc.....
   smisc.gsl.gsl_ran_sample (rng, dest, self.l,self.src, self.l, sizeof(double)) -- SRSWR n out on
   var r = A.hd(dest,self.l,self.q,self.w)
   Rbase.free(dest)
   return(r)
end
local terra runme(index:int, input:&opaque, data:&hdVarStruct)
   return data()
end
local terra bsHDVariance3(src:&double, srclength:int, nb:int,q:double,grain:double)   
   var wprecomp = preComputeBetaDiff(srclength,q)
   var qdata = hdVarStruct { w = wprecomp, src=src, l=srclength, q =q}
   var ha = tbb.papply(src, nb, runme, &qdata,grain)
   var s =  smisc.stddev(ha,nb)
   Rbase.free(ha)
   return(s)
end
```

### Performance

For 500 bootstrap replications, and yes, based on 1 run(but the
variation is very small enough to make parallel Terra faster than the others),
the timings(seconds) are

    linear(luajit)              122.085
    parallel bootstrap           19.145
    parallel q and bootstrap     18.234
    parallel R (see code below)  25.472

How pleasant and yay for R!

## Conclusion
So in conclusion, we can

- now write  fast extensions to R in Terra
- write parallel code in Terra
- throw parallel tasks within parallel tasks (handled by TBB's scheduler)
- and observe that good programming design can  really help your R code

### R Code

```R
Rshifthd <- function (x, y, nboot = 200,C=16) 
{
    crit <- 80.1/(min(length(x), length(y)))^2 + 2.73
    wComp <- function(x,q){
        n <- length(x)
        m1 <- (n + 1) * q
        m2 <- (n + 1) * (1 - q)
        vec <- seq(along = x)
        pbeta(vec/n, m1, m2) - pbeta((vec - 1)/n, m1, m2)
    }
    m <- matrix(0, 9, 3)
    for (i in 1:9) {
        q <- i/10
        wcom <- wComp(x,q)
        sex <- var(unlist(mclapply(1:nboot,function(i){
            x1 <- sample(x,size=length(x),replace=TRUE)
            sum(wcom*sort(x1))
        },mc.cores=C)))

        wcom <- wComp(y,q)
        sey <- var(unlist(mclapply(1:nboot,function(i){
            y1 <- sample(y,size=length(y),replace=TRUE)
            sum(wcom*sort(y1))
        },mc.cores=C) ))

        dif <- hd(y, q) - hd(x, q)
        m[i, 3] <- dif
        m[i, 1] <- dif - crit * sqrt(sex + sey)
        m[i, 2] <- dif + crit * sqrt(sex + sey)
    }
    dimnames(m) <- list(NULL, c("ci.lower", "ci.upper", "Delta.hat"))
    m
}
library(parallel)        
```


{% endjrnl %}
