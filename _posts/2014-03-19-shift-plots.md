---
layout: postjournal
title: Comparing Deciles of Two Distributions
excerpt: Computing confidence bands for two distributions
tags: terra R performance extension lua luajit deciles quantiles  rterra
---

{% jrnl width=code %}

* mytoc
{:toc}

## Introduction

(There is a sequel to this in the
[next post](http://people.mozilla.org/~sguha/blog/2014/03/26/shift-plots-parallel.html)
and talks about making things parallel using TBB)

At work, I often need to nonparametrically compare two distributions $X$ and $Y$. A visual
and effective approach is the shift plot which plots the difference of the
percentiles against the percentiles of $X$. However, since decisions are made
based on these figures, confidence bands are required. In practice, the Doksum
and Sievers confidence band for _all_ the deciles is too wide. The book
_"Introduction to Robust Estimation and Hypothesis Testing"_ by Rand Wilcox has
an algorithm to compute the 95% confidence band for the _deciles_. The band is
therefore much sharper. My intuition tells me it will cover the regions between
deciles with the same coverage probability. The routine uses bootstrap samples to compute the terms of

$$
(\hat{\theta}_{qy} - \hat{\theta}_{qx}) \pm c\sqrt{\hat{\sigma}^2_{qy} -\hat{\sigma}^2_{qx}}
$$

where $n=m$ and $c = \frac{80.1}{n^2}+2.73$. The constant $c$ is chosen to
attain the 95% coverage probability. The estimates of the standard error are
compute via Harrell Davis estimators of the quantiles and bootstrap.If you load
the package
[WRS](http://www.r-bloggers.com/r-package-wilcox-robust-statistics-updated-wrs-v0-20/)
, the function `shifthd` contains the code.

Bootstrapping can be slow when $n=m=60K$. Can we speed it up using Terra? This
post will take us through the code.

## Beginnings
I encourage the reader to skim through the source of `shifthd` and `hd`. The
following code mimics it very closely. We compute 4 things

- the estimate  $$\hat{\theta}_{qy}$$ using the Harrel-Davis estimator (the `hd`
function)
- the estimate  $$\hat{\theta}_{qx}$$ using the Harrel-Davis estimator
- the bootstrap estimates  $$\hat{\sigma}^2_{qy}$$
- the bootstrap estimate  $$\hat{\sigma}^2_{qx}$$

We have some data
{% highlight r linenos=table %}
H <- function(x) (x)
x <- H(subset(d2, ch=="nightly")$mactsec)
y <- H(subset(d2, ch=="aurora")$mactsec)
{% endhighlight %}
	
and enter Terra like this

{% highlight r linenos=table %}
tshifthd <- function(x,y,boot=300){
    a <- do.call(rbind,terra("shifthd", x,y,boot))
    colnames(a)=c("ci.lower","ci.upper","Delta.hat")
    a
}
system.time(a2 <- tshifthd(x,y))
{% endhighlight %}


### `shifthd`
So far straight forward! We load the `smisc` Terra module from this post.
{% highlight lua  linenos=table %}
smisc = require 'smisc'
shifthd1 = function (x_,y_, nboot_)
   local x,y, nboot = R.Robj(R.duplicateObject(x_)), R.Robj(R.duplicateObject(y_)), R.Robj(nboot_)
   local crit = 80.1/math.pow(math.min(#x, #y),2) + 2.73
   local rng = ffi.gc(smisc.init_default_rng()(),smisc.free_rng)
   local xarray,yarray =ffi.gc(smisc.doubleArray(#x),Rbase.free), ffi.gc(smisc.doubleArray(#y),Rbase.free)
   local ret = R.Robj{type='vector', length = 9}
   for i = 1,9 do
      local q = i/10
      local sex = bsHDVariance( rng, xarray, x,  nboot[0],q)
      local sey = bsHDVariance( rng, yarray, y,  nboot[0],q)
      local dif = A.hd(y.ptr, #y,q) - hd(x.ptr,#x,q)
      ret[i-1] = R.Robj{type='numeric', with = {dif-crit*math.sqrt(sex+sey), dif + crit*math.sqrt(sex+sey),dif}}
   end
   return ret
end
{% endhighlight  %}


The function `shifthd`

- converts the objects `x_`, `y_`, `nboot_` to Terra R equivalents after having
  made duplicates (we don't want to modify the original)
- computes the value of $c$ (called `crit`).
- Initiates the GSL random number generator and uses LuaJIT's GC mechanism for
  FFI objects to clean on exit.
- Creates temporary arrays `xarray` and `yarray` which will be used for
  bootstrap samples.
- `ret` will contain the values to be returned. It is an R vector
- For the 9 deciles,
  - computes the bootstrap estimate of standard error of $$\theta_{qx},\theta_{qy}$$
  - the estimate of the difference in quantiles
  - creates a numeric vector with the lower, and upper bounds and the diff

### `hd`

Let's take a look at the `hd` function. This is written in Terra. The function
will call `pbeta` which returns  $Prob(X<x)$ where $X \sim Beta(pin,qin)$.

{% highlight lua  linenos=table %}
local pbeta = terra(x: double, pin: double, qin:double,lower_tail :bool)
   if lower_tail then
      return smisc.gsl.gsl_cdf_beta_P(x,pin, qin)
   else
      return smisc.gsl.gsl_cdf_beta_Q(x,pin, qin)
   end
end
{% endhighlight %}

the function `hd` takes the sample `x`, it's length `n` and the p-value for
which to compute the quantile for. If you take a look at WRS's `hd` function,
this mimics that very closely.

{% highlight lua linenos=table %}
local A = {}
doubleAscending = smisc.ascendingComparator(double)
terra  A.hd(x : &double,n : int,q : double)
 var w = smisc.doubleArray(n) 
 var m1,m2 = (n+1)*q,(n+1)*(1-q)
 for i =1, n do
    w[i-1] = pbeta(i*1.0/n, m1,m2,true) - pbeta((i-1.0)/n,m1,m2,true)
 end
 smisc.qsort(x, n, sizeof(double),doubleAscending)
 var s = smisc.dotproduct(w,x,n)
 stdlib.free(w)
 return(s)
end
{% endhighlight %}

### `bsHDVariance`
And finally, a Lua function to compute the boostrap estimates
{% highlight lua  linenos=table  %}
local function bsHDVariance1(rng, dest,  src,  nboot,q)
   local ha=ffi.gc(smisc.doubleArray(nboot),Rbase.free)
   for bootindex = 1,nboot do
      gsl.gsl_ran_sample (rng, dest, #src, src.ptr, #src, sizeof(double)) -- SRSWR n out on
      ha[bootindex-1] = A.hd( dest, #src, q)
   end
   return smisc.stddev(ha,nboot)
end
{% endhighlight %}
	
- loops through `nboot` bootstrap iterations
  - computes a simple random sample with replacement from `src` (original data)
  - computes the Harrel-Davis estimate




## Performance
The following code compares the two approaches
{% highlight R linenos=table %}
load("~/tmp/foo.Rdata")
H <- function(x) (x)
x <- H(subset(d2, ch=="nightly")$mactsec)
y <- H(subset(d2, ch=="aurora")$mactsec)
library(smiscrterra)
tinit()
smisc.init()
terraStr("smisc = terralib.require('smisc')")
library(WRS)
replicate(5,system.time(a2 <- tshifthd(x,y,nboot=10)))[,]
replicate(5,system.time(a1 <- shifthd(x,y,nboot=10,plotit=FALSE)))[,]
{% endhighlight %}

And the timings are


     terra elapsed    22.342 10.331 10.290 10.325 10.286
     r     elapsed    40.431 39.106 39.101 39.051 39.388

The drop in timings after Terra's first run occurs on OS X, not so on Linux. I
cannot explain why.

### Improvement
Both codes compute $$P_{beta}(i/n)-P_{beta}((i-1)/n)$$ repeatedly. One could
precompute this instead. Using this approach, the Lua code would be (note `hd`
has another definition). Terra can interpret overloaded function definitions.

{% highlight lua linenos=table %}
local terra  A.hd(x : &double,n : int,q : double, w:&double)
   stdlib.qsort(x, n, sizeof(double),doubleAscending)
   var s = smisc.dotproduct(w,x,n)
   return(s)
end

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
{% endhighlight %}

The timings drop a lot to

    terra elapsed    5.386 3.198 3.198 3.244 3.280

## Summary
The code in the bootstrap section (lines 10-12 in the above code),
can be done in parallel. In the next post, we'll  parallelize this quite easily
using Intel TBB.  The above code is in package form and can be found at
[https://github.com/saptarshiguha/rterramisc](https://github.com/saptarshiguha/rterramisc)

The
[next post](http://people.mozilla.org/~sguha/blog/2014/03/26/shift-plots-parallel.html)
talks about making things parallel using TBB

{% endjrnl %}
